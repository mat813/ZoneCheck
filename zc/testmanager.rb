# $Id$

# 
# AUTHOR : Stephane D'Alu <sdalu@nic.fr>
# CREATED: 2002/08/02 13:58:17
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS:
#
#

require 'thread'
require 'framework'
require 'report'
require 'cache'

##
##
##
##
## attributs: param, classes, cm, config, tests
class TestManager
    include CacheAttribute

    ##
    ## Exception: error in the test definition
    ##
    class DefinitionError < StandardError
    end


    TestSuperclass = Test
    TestPrefix     = "tst_"
    CheckPrefix    = "chk_"


    #
    # Load ruby files implementing tests
    #  WARN: we are required to untaint for loading
    #
    # To minimize risk of choosing a random directory, only files
    #  that have the ruby extension (.rb) and have the "ZCTEST 1.0"
    #  magic header are loaded.
    #
    def self.load(*filenames)
	count = 0
	filenames.each { |filename|
	    if File.directory?(filename)
		$dbg.msg(DBG::LOADING, "test directory: #{filename}")
		Dir::open(filename) { |dir|
		    dir.each { |entry|
			testfile = "#{filename}/#{entry}".untaint
			count += self.load(testfile) if File.file?(testfile)
		    }
		}
	    elsif File.file?(filename)
		if ((filename =~ /\.rb$/) &&
		    begin
			File.open(filename) { |io|
			    io.gets =~ /^\#\s*ZCTEST\s+1\.0:?\W/
			}
		    rescue # XXX: Careful with rescue all
			false
		    end)
		    $dbg.msg(DBG::LOADING, "test file: #{filename}")
		    ::Kernel.load filename
		    count += 1
		end
	    end
	}
	return count
    end


    #
    # Initialize a new object.
    #
    def initialize
	@tests		= {}	# Hash of test  method name (tst_*)
	@checks		= {}	# Hash of check method name (chk_*)
	@classes	= []	# List of classes used by the methods above
 	@attrcache_mutex= Sync::new
   end


    #
    # Add all the available classes that containts check methods
    #
    def add_allclasses
	# Add the test classes (they should have Test as superclass)
	[ CheckGeneric, CheckNameServer, 
	    CheckNetworkAddress, CheckExtra].each { |mod|
	    mod.constants.each { |t|
		testclass = eval "#{mod}::#{t}"
		if testclass.superclass == TestSuperclass
		    $dbg.msg(DBG::TESTS, "adding class: #{testclass}")
		    self << testclass
		else
		    $dbg.msg(DBG::TESTS, "skipping class: #{testclass}")
		end
	    }
	}
    end


    #
    # Register all the checks/tests that are provided by the class 'klass'.
    #
    def <<(klass)
	# Sanity check (all test class should derive from Test)
	if ! (klass.superclass == TestSuperclass)
	    raise ArgumentError, 
		$mc.get("xcp_testmanager_badclass") % [ klass, TestSuperclass ]
	end
	
	# Inspect instance methods for finding check methods (ie: chk_*, tst_*)
	klass.public_instance_methods.each { |method| 
	    # Only deal with methods that represent a check or a test
	    case method
	    when /^#{TestPrefix}/
		if has_test?(method)
		    l10n_tag = $mc.get("xcp_testmanager_test_exists")
		    raise DefinitionError, 
			l10n_tag % [ method, klass, @tests[method] ]
		end
		@tests[method] = klass

	    when /^#{CheckPrefix}/
		if has_check?(method)
		    l10n_tag = $mc.get("xcp_testmanager_check_exists")
		    raise DefinitionError, 
			l10n_tag % [ method, klass, @tests[method] ]
		end
		@checks[method] = klass
	    end
	}

	# Add it to the list of classes
	#  The class will be unique in the list otherwise the checking
	#  above will fail with method defined twice.
	@classes << klass
    end


    #
    # Check if 'test' has already been registered.
    #
    def has_test?(testname)
	@tests.has_key?(testname)
    end


    #
    # Check if 'check' has already been registered.
    #
    def has_check?(checkname)
	@checks.has_key?(checkname)
    end
    
    
    #
    # Return check family (ie: generic, nameserver, address, extra)
    #
    def family(checkname) 
	klass = @checks[checkname]
	klass.name =~ /^([^:]+)/
	eval("#{$1}")
    end


    #
    # Return list of available checks
    #
    def list
	@checks.keys
    end


    #
    # Use the configuration object ('config') to instanciate each
    # class (but only once) that will be used to perform the tests.
    #
    def init(config, cm, param, do_preeval=true)
	@config		= config
	@param		= param
	@publisher	= @param.publisher.engine
	@objects	= {}
	@cm		= cm
	@cached_tst	= {}
	@do_preeval	= do_preeval

	@iterer = { 
	    CheckExtra          => proc { |bl| bl.call },
	    CheckGeneric        => proc { |bl| bl.call },
	    CheckNameServer     => proc { |bl| 
		@param.domain.ns.each { |ns_name, | bl.call(ns_name) } },
	    CheckNetworkAddress => proc { |bl| 
		@param.domain.ns.each { |ns_name, ns_addr_list|
		    @param.network.address_wanted?(ns_addr_list).each { |addr|
			bl.call(ns_name, addr) } } }
	}

	@classes.each { |klass|
	    @objects[klass] = klass.method("new").call(@config,
						       @cm, @param.domain)
	}
    end


    #
    # Perform unitary check
    #
    def check1(checkname, severity, ns=nil, ip=nil) 
	$dbg.msg(DBG::TESTS, "checking: #{checkname}")
	# Retrieve the method representing the check
	klass   = @checks[checkname]
	object  = @objects[klass]
	method  = object.method(checkname)
	
	# Retrieve information relative to the test output
	sev_report = case severity
		     when Config::Fatal   then @param.report.fatal
		     when Config::Warning then @param.report.warning
		     when Config::Info    then @param.report.info
		     end

	# Publish information about the test being executed
	desc = if @param.rflag.tagonly
	       then checkname
	       else $mc.get("#{checkname}_testname")
	       end
	@publisher.progress.process(desc, ns, ip)

	# Perform the test
	desc         = Test::Result::Desc::new(checkname)
	result_class = Test::Error
	args = []
	args << ns if !ns.nil?
	args << ip if !ip.nil?
	begin
	    data         = method.call(*args)
	    desc.data    = data if data
	    result_class = case data 
			   when NilClass, FalseClass, Hash then Test::Failed
			   else Test::Succeed
			   end
	rescue NResolv::RefusedError
	    desc.err = "Answer refused"
	rescue Errno::EADDRNOTAVAIL
	    desc.err = "Network transport unavailable try option -4 or -6"
	rescue NResolv::NResolvError => e
	    desc.err = "Resolver error (#{e})"
	rescue Exception => e
#	    desc.err = "Dependency issue (allwarning flag?)"
	    desc.err = e.message
	    raise if $dbg.enabled?(DBG::DONT_RESCUE)
	end

	# Build result
	begin
	    result = result_class::new(checkname, desc, ns, ip)
	    sev_report.add_result(result)
	rescue Report::FatalError
	    raise if @param.rflag.stop_on_fatal
	end
    end


    #
    # Perform unitary test
    #
    def test1(testname, ns=nil, ip=nil)
	$dbg.msg(DBG::TESTS, "test: #{testname}")
	cache_attribute("@cached_tst", [ testname, ns, ip ]) {
	    # Retrieve the method representing the check
	    klass   = @tests[testname]
	    object  = @objects[klass]
	    method  = object.method(testname)
	    
	    # Call the method
	    args = []
	    args << ns if !ns.nil?
	    args << ip if !ip.nil?
	    method.call(*args)
	}
    end

    #
    # Perform all the tests as asked in the configuration file and
    # according to the program parameters
    #
    def check
	threadlist            = []
	testcount             = 0
	domainname_s          = @param.domain.name.to_s

	begin
	    # Do a pre-evaluation of the code
	    if @do_preeval
		if $dbg.enabled?(DBG::NOCACHE)
		    raise RuntimeError, 
			"Debugging with preeval and NOCACHE is not adviced"
		end

		begin
		    Config::TestSeqOrder.each { |family|
			testseq		= @config[family]
			next if testseq.nil?
			
			@iterer[family].call(proc { |*args|
				testcount += testseq.preeval(self, args)
			   })
		    }
		rescue Instruction::InstructionError,
			NResolv::NResolvError => e
		    $dbg.msg(DBG::TESTS, "disabling preeval: #{e}")
		    @do_preeval = false
		    testcount   = 0
		end
	    end

	    # Counter start
	    @publisher.progress.start(testcount)
	    
	    # Perform the checking
	    Config::TestSeqOrder.each { |family|
		threadlist	= []
		testseq		= @config[family]
		next if testseq.nil?

		@iterer[family].call(proc { |*args|
			threadlist << Thread::new {
			    begin
				testseq.eval(self, args)
			    rescue Report::FatalError
				raise
			    rescue Exception => e
				# XXX: debuging
				puts "Exception #{e.message}"
				puts e.backtrace
				raise
			    end
			}
		    })

		threadlist.each { |thr| thr.join }
	    }

	    # Counter end on success
	    @publisher.progress.done(domainname_s)
	rescue Report::FatalError
	    # Counter end on failure
	    @publisher.progress.failed(domainname_s)
	    # Reraise exception
	    raise
	ensure
	    # Counter cleanup
	    @publisher.progress.finish
	end
    end
end
