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

##
##
##
##
## attributs: param, classes, cm, config, tests
class TestManager
    ##
    ## Exception: error in the test definition
    ##
    class DefinitionError < StandardError
    end


    TestSuperclass = Test
    TestPrefix     = "chk_"
    

    #
    # Initialize a new object.
    #
    def initialize
	@tests     = {}
    end


    #
    # Register all the tests that are provided by the class 'klass'.
    #
    def <<(klass)
	# Sanity check (all test class should derive from Test)
	if ! (klass.superclass == TestSuperclass)
	    raise ArgumentError, 
		"class '#{klass}' doesn't derive from #{TestSuperclass}"
	end
	
	# Inspect instance methods for finding check methods (ie: chk_*)
	klass.public_instance_methods.each { |method| 
	    # Only deal with methods that represent a test
	    next unless method =~ /^#{TestPrefix}/

	    # Check for name collision
	    if has_test?(method) then
		raise DefinitionError, "test '#{method}' defined in classes '#{klass}' and '#{@tests[method]}"
	    end

	    # Register test method
	    @tests[method] = klass
	}
    end



    #
    # Check if 'test' has already been registered.
    #
    def has_test?(testname)
	@tests.has_key?(testname)
    end

    def family(testname) 
	klass = @tests[testname]
	klass.name =~ /^([^:]+)/
	eval("#{$1}")
    end

    def list
	@tests.keys
    end

    #
    # Use the configuration object ('config') to instanciate each
    # classes (but only once) that will be used to perform the tests.
    #
    def init(config, cm, param)
	@config     = config
	@param      = param
	@publisher  = @param.publisher
	@classes    = {}
	@cm         = cm

	# Instanciate only once each classes that has a requested test
	domain = @param.domain
	@config.test_list.each { |testname|
	    if ! @classes.has_key?(klass = @tests[testname])
		@classes[klass] = [klass.method("new").call(@config,
							    @cm, 
							    domain.name, 
							    domain.ns)]
	    end
	}
    end


    def test1(severity, method, testname, ns=nil, ip=nil) 
	# Publish information about the test being executed
	desc = if @param.rflag.tagonly
	       then testname
	       else $mc.get("#{testname}_testname")
	       end
	@publisher.progress.process(desc, ns, ip)

	# Perform the test
	desc         = Test::Result::Desc::new(testname)
	result_class = Test::Error
	args = []
	args << ns if !ns.nil?
	args << ip if !ip.nil?
	begin
	    result_class = method.call(*args) ? Test::Succeed : Test::Failed
	rescue NResolv::RefusedError
	    desc.err = "Answer refused"
	rescue Errno::EADDRNOTAVAIL
	    desc.err = "Network transport unavailable try option -4 or -6"
	rescue NResolv::NResolvError => e
	    desc.err = "Resolver error (#{e})"
	rescue Exception => e
	    desc.err = "Dependency issue (allwarning flag?)"
	    raise if $dbg.enabled?(DBG::DONT_RESCUE)
	end

	# Build result
	begin
	    result = result_class::new(testname, desc, ns, ip)
	    severity.add_result(result)
	rescue Report::FatalError
	    raise if @param.rflag.stop_on_fatal
	end
    end


    #
    # Perform all the tests as asked in the configuration file and
    # according to the program parameters
    #
    def test
	# Sanity check
	if @config.nil?
	    raise RuntimeError, "the TestManager#init should be called before"
	end
	
	check_generic         = []
	check_nameserver      = {}
	check_network_address = {}
	check_extra           = []

	threadlist            = []
	testcount             = 0

	domainname_s          = @param.domain.name.to_s

	# Build test sequences
	@config.test_list.each { |testname| 
	    # Retrieve the method representing the test 'testname'
	    klass   = @tests[testname]
	    object, = @classes[klass]
	    method  = object.method(testname)

	    # Retrieve information relative to the test output
	    severity = case @config.action(testname)
		       when Config::Warning then @param.report.warning
		       when Config::Info    then @param.report.info
		       when Config::Fatal   then @param.report.fatal
		       end


	    # Perform the test according to their "types"
	    case klass.name

		# Test generic: 
		#  => ARG: *none*
	    when /^CheckGeneric::/
		check_generic << [severity, method, testname]
		testcount += 1
		
		# Test specific to the nameserver:
		#  => ARG: nameserver name
	    when /^CheckNameServer::/
		@param.domain.ns.each { |name, |
		    testcount += 1
		    check_nameserver[name] ||= []
		    check_nameserver[name] <<
			[severity, method, testname, name]
		}

		# Test specific to the nameserver instance
		#  => ARG: nameserver name; nameserver IP
	    when /^CheckNetworkAddress::/ then 
		@param.domain.ns.each { |ns_name, ns_addr_list|
		    @param.address_wanted?(ns_addr_list).each { |addr|
			testcount += 1
			check_network_address[addr] ||= []
			check_network_address[addr] <<
			    [ severity, method, testname, ns_name, addr ]
		    }
		}

	    when /^CheckExtra::/ then
		testcount += 1
		check_extra << [severity, method, testname]
	    end
	}

	# Perform tests
	begin
	    # Counter start
	    @publisher.progress.start(testcount)
	    
	    # Do CheckGeneric
	    check_generic.each { |args| test1(*args) }
	    
	    # Do CheckNameServer
	    check_nameserver.each_value { |args_list|
		args_list.each { |args| test1(*args) }
	    }
	    
	    # Do CheckNetworkAddress (and parallelize)
	    check_network_address.each_value { |args_list|
		threadlist << Thread::new {
		    begin
			args_list.each { |args| test1(*args) }
		    rescue Report::FatalError
			raise
		    rescue Exception => e
			# XXX: debuging
			puts "Exception #{e.message}"
			puts e.backtrace
			raise
		    end
		}
	    }
	    threadlist.each { |thr| thr.join }

	    # Do CheckExtra
	    check_extra.each { |args| test1(*args) }

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
