# $Id$

# 
# CONTACT     : zonecheck@nic.fr
# AUTHOR      : Stephane D'Alu <sdalu@nic.fr>
#
# CREATED     : 02/08/02 13:58:17
# REVISION    : $Revision$ 
# DATE        : $Date$
#
# CONTRIBUTORS: (see also CREDITS file)
#
#
# LICENSE     : GPL v2 (or MIT/X11-like after agreement)
# COPYRIGHT   : AFNIC (c) 2003
#
# This file is part of ZoneCheck.
#
# ZoneCheck is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# ZoneCheck is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ZoneCheck; if not, write to the Free Software Foundation,
# Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#

require 'thread'
require 'timeout'
require 'time'
require 'framework'
require 'report'
require 'cache'


##
## TODO: decide how to replace the Errno::EADDRNOTAVAIL which is not
##       available on windows
## TODO: improved detection of dependencies issues
##
## attributs: param, classes, cm, config, tests
class TestManager
    TestSuperclass = Test	# Superclass
    TestPrefix     = 'tst_'	# Prefix for test methods
    CheckPrefix    = 'chk_'	# Prefix for check methods

    ##
    ## Exception: error in the test definition
    ##
    class DefinitionError < StandardError
    end


    #
    # List of loaded test files
    #  (avoid loading the same file twice)
    #
    @@test_files = {}

    #
    # Load ruby files implementing tests
    #  WARN: we are required to untaint for loading
    #  WARN: file are only loaded once to avoid redefinition of constants
    #
    # To minimize risk of choosing a random directory, only files
    #  that have the ruby extension (.rb) and the 'ZCTEST 1.0'
    #  magic header are loaded.
    #
    def self.load(*filenames)
	count = 0
	filenames.each { |filename|
	    # Recursively load file in the directory
	    if File.directory?(filename)
		$dbg.msg(DBG::LOADING) { "test directory: #{filename}" }
		Dir::open(filename) { |dir|
		    dir.each { |entry|
			testfile = "#{filename}/#{entry}".untaint
			count += self.load(testfile) if File.file?(testfile)
		    }
		}
		
	    # Load test file
	    elsif File.file?(filename)
		# Only load file if it meet some criteria (see above)
		if ((filename =~ /\.rb$/) &&
		    begin
			File.open(filename) { |io|
			    io.gets =~ /^\#\s*ZCTEST\s+1\.0:?\W/ }
		    rescue # XXX: Careful with rescue all
			false
		    end)

		    # Really load the file if it wasn't already done
		    if  ! @@test_files.has_key?(filename)
			$dbg.msg(DBG::LOADING) { "test file: #{filename}" }
			::Kernel.load filename
			@@test_files[filename] = true
			count += 1
		    else
			$dbg.msg(DBG::LOADING) {
			    "test file: #{filename} (already loaded)" }
		    end
		end
	    end
	}

	# Return the number of loaded file
	return count
    end


    #
    # Initialize a new object.
    #
    def initialize
	@tests		= {}	# Hash of test  method name (tst_*)
	@checks		= {}	# Hash of check method name (chk_*)
	@classes	= []	# List of classes used by the methods above
	@cache = Cache::new
	@cache.create(:test)
   end


    #
    # Add all the available classes that containts test/check methods
    #
    def add_allclasses
	# Add the test classes (they should have Test as superclass)
	[ CheckGeneric, CheckNameServer, 
	    CheckNetworkAddress, CheckExtra].each { |mod|
	    mod.constants.each { |t|
		testclass = eval "#{mod}::#{t}"
		if testclass.superclass == TestSuperclass
		    $dbg.msg(DBG::TESTS) { "adding class: #{testclass}"   }
		    self << testclass
		else
		    $dbg.msg(DBG::TESTS) { "skipping class: #{testclass}" }
		end
	    }
	}
    end


    #
    # Register all the tests/checks that are provided by the class 'klass'.
    #
    def <<(klass)
	# Sanity check (all test class should derive from Test)
	if ! (klass.superclass == TestSuperclass)
	    raise ArgumentError, 
		$mc.get('xcp_testmanager_badclass') % [ klass, TestSuperclass ]
	end
	
	# Inspect instance methods for finding methods (ie: chk_*, tst_*)
	klass.public_instance_methods(true).each { |method| 	    
	    case method
	    # methods that represent a test
	    when /^#{TestPrefix}(.*)/
		testname = $1
		if has_test?(testname)
		    l10n_tag = $mc.get('xcp_testmanager_test_exists')
		    raise DefinitionError, 
			l10n_tag % [ testname, klass, @tests[testname] ]
		end
		@tests[testname] = klass

	    # methods that represent a check
	    when /^#{CheckPrefix}(.*)/
		checkname = $1
		if has_check?(checkname)
		    l10n_tag = $mc.get('xcp_testmanager_check_exists')
		    raise DefinitionError, 
			l10n_tag % [ checkname, klass, @tests[checkname] ]
		end
		@checks[checkname] = klass
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
    #
    #
    def wanted_check?(checkname, category)
	return true unless @param.test.categories

	@param.test.categories.each { |rule|
	    if    (rule[0] == ?! || rule[0] == ?-)
		negation, name = true,  rule[1..-1]
	    elsif (rule[0] == ?+)
		negation, name = false, rule[1..-1]
	    else
		negation, name = false, rule
	    end

	    return !negation if name.empty?

	    if ((name == category) || 
		!(category =~ /^#{Regexp.escape(name)}:/).nil?)
		return !negation
	    end
	}
	return false
    end
    
    #
    # Return check family (ie: generic, nameserver, address, extra)
    #
    def family(checkname) 
	klass = @checks[checkname]
	klass.name =~ /^([^:]+)/
	eval("#{$1}.family")
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
	@do_preeval	= do_preeval

	@cache.clear(:test)

	@iterer = { 
	    CheckExtra.family          => proc { |bl| bl.call },
	    CheckGeneric.family        => proc { |bl| bl.call },
	    CheckNameServer.family     => proc { |bl| 
		@param.domain.ns.each { |ns_name, | bl.call(ns_name) } },
	    CheckNetworkAddress.family => proc { |bl| 
		@param.domain.ns.each { |ns_name, ns_addr_list|
		    @param.network.address_wanted?(ns_addr_list).each { |addr|
			bl.call(ns_name, addr) } } }
	}

	# Create new instance of the class
	@classes.each { |klass|
	    @objects[klass] = klass.method('new').call(@param.network, @config,
						       @cm, @param.domain)
	}
    end


    #
    # Perform unitary check
    #
    def check1(checkname, severity, ns=nil, ip=nil) 
	# Build argument list
	args = []
	args << ns if !ns.nil?
	args << ip if !ip.nil?

	# Debugging
	$dbg.msg(DBG::TESTS) {
	    where  = args.empty? ? "generic" : args.join('/')
	    "checking: #{checkname} [#{where}]" }

	# Stat
	@param.info.testcount += 1

	# Retrieve the method representing the check
	klass   = @checks[checkname]
	object  = @objects[klass]
	method  = object.method(CheckPrefix + checkname)
	
	# Retrieve information relative to the test output
	sev_report = case severity
		     when ZC_Config::Fatal   then @param.report.fatal
		     when ZC_Config::Warning then @param.report.warning
		     when ZC_Config::Info    then @param.report.info
		     end

	# Publish information about the test being executed
	@publisher.progress.process(checkname, ns, ip)

	# Perform the test
	desc         = Test::Result::Desc::new
	result_class = Test::Error
	begin
	    starttime    = Time::now
	    exectime     = nil
	    begin
		data     = method.call(*args)
	    ensure
		exectime = Time::now - starttime
	    end
	    desc.details = data if data
	    result_class = case data 
			   when NilClass, FalseClass, Hash then Test::Failed
			   else Test::Succeed
			   end
	rescue NResolv::DNS::ReplyError => e
	    info = "(#{e.resource.rdesc}: #{e.name})"
	    name = case e.code
		   when NResolv::DNS::RCode::SERVFAIL
		       $mc.get('nresolv:rcode:servfail')
		   when NResolv::DNS::RCode::REFUSED
		       $mc.get('nresolv:rcode:refused')
		   when NResolv::DNS::RCode::NXDOMAIN
		       $mc.get('nresolv:rcode:nxdomain')
		   when NResolv::DNS::RCode::NOTIMP
		       $mc.get('nresolv:rcode:notimp')
		   else e.code.to_s
		   end
	    desc.error = "#{name} #{info}"
#	rescue Errno::EADDRNOTAVAIL
#	    desc.err = "Network transport unavailable try option -4 or -6"
	rescue NResolv::TimeoutError => e
	    desc.error = "DNS Timeout"
	rescue Timeout::Error => e
	    desc.error = "Timeout"
	rescue NResolv::NResolvError => e
	    desc.error = "Resolver error (#{e})"
	rescue ZCMail::ZCMailError => e
	    desc.error = "Mail error (#{e})"
	rescue Exception => e
	    # XXX: this is a hack
	    unless @param.rflag.stop_on_fatal
		desc.error = 'Dependency issue? (allwarning/dontstop flag?)'
	    else
		desc.error = e.message
	    end
	    raise if $dbg.enabled?(DBG::DONT_RESCUE)
	ensure
	    $dbg.msg(DBG::TESTS) { 
		resstr  = result_class.to_s.gsub(/^.*::/, '')
		where   = args.empty? ? 'generic' : args.join('/')
		timestr = "%.2f" % exectime
		"result: #{resstr} for #{checkname} [#{where}] (in #{timestr} sec)"
	    }
	end

	# Build result
	begin
	    result = result_class::new(checkname, desc, ns, ip)
	    sev_report << result
	rescue Report::FatalError
	    raise if @param.rflag.stop_on_fatal
	end
    end


    #
    # Perform unitary test
    #
    def test1(testname, report=true, ns=nil, ip=nil)
	$dbg.msg(DBG::TESTS) { "test: #{testname}" }
	@cache.use(:test, [ testname, ns, ip ]) {
	    # Retrieve the method representing the test
	    klass   = @tests[testname]
	    object  = @objects[klass]
	    method  = object.method(TestPrefix + testname)
	    
	    # Call the method
	    args = []
	    args << ns unless ns.nil?
	    args << ip unless ip.nil?
	    begin
		method.call(*args)
	    rescue NResolv::NResolvError => e
		return e unless report
		desc = Test::Result::Desc::new(false)
		desc.error = "Resolver error (#{e})"
		@param.report.fatal << Test::Error::new(testname, desc, ns, ip)
	    end
	}
    end

    #
    # Perform all the tests as asked in the configuration file and
    # according to the program parameters
    #
    def check
	threadlist	= []
	testcount	= 0
	domainname_s	= @param.domain.name.to_s
	starttime	= Time::now

	# Stats
	@param.info.nscount = @param.domain.ns.size

	# Do a pre-evaluation of the code
	if @do_preeval
	    # Sanity check for debugging
	    if $dbg.enabled?(DBG::NOCACHE)
		raise 'Debugging with preeval and NOCACHE is not adviced'
	    end

	    # Do the pre-evaluation
	    #  => compute the number of checking to perform
	    begin
		ZC_Config::TestSeqOrder.each { |family|
		    next unless rules = @config.rules[family]
		    
		    @iterer[family].call(proc { |*args|
				testcount += rules.preeval(self, args)
			   })
		}
	    rescue Instruction::InstructionError => e
		$dbg.msg(DBG::TESTS) { "disabling preeval: #{e}" }
		@do_preeval = false
		testcount   = 0
	    end
	end

	# Perform the tests
	begin
	    # Counter start
	    @publisher.progress.start(testcount)

	    # Perform the checking
	    ZC_Config::TestSeqOrder.each { |family|
		next unless rules = @config.rules[family]

		threadlist	= []
		@iterer[family].call(proc { |*args|
			threadlist << Thread::new {
			    begin
				rules.eval(self, args)
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

	    # Counter final status
	    if @param.report.fatal.empty?
	    then @publisher.progress.done(domainname_s)
	    else @publisher.progress.failed(domainname_s)
	    end

	rescue Report::FatalError
	    if @param.report.fatal.empty?
		raise "BUG: FatalError with no fatal error stored in report"
	    end
	    @publisher.progress.failed(domainname_s)

	ensure
	    # Counter cleanup
	    @publisher.progress.finish
	    # Total testing time
	    @param.info.testingtime = Time::now - starttime
	end

	# Status
	@param.report.fatal.empty?
    end
end
