# $Id$

# 
# AUTHOR : Stephane D'Alu <sdalu@nic.fr>
# CREATED: 2002/08/02 13:58:17
#
# $Revivion$ 
# $Date$
#
# CONTRIBUTORS:
#
#

require 'thread'
require 'framework'
require 'diagnostic'

##
##
##
class TestManager
    ##
    ## Error in the test definition
    ##
    class DefinitionError < StandardError
    end



    #
    # Initialize a new object.
    #
    def initialize(param)
	@param     = param
	@formatter = param.formatter	# shortcut
	@config    = nil
	@tests     = {}
	@classes   = {}
	@cm	   = CacheManager::create(Test::DefaultDNS, param.client)
    end



    #
    # Register all the tests that are provided by the class 'klass'.
    #
    def <<(klass)
	# Sanity check (all test class should derive from Test)
	if ! (klass.superclass == Test)
	    raise ArgumentError, "class '#{klass}' doesn't derive from #{Test}"
	end
	
	# Inspect instance methods for finding check methods (ie: chk_*)
	klass.public_instance_methods.each { |method| 
	    # Only deal with methods that represent a test
	    next unless method =~ /^chk_/

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


    #
    # Use the configuration object ('config') to instanciate each
    # classes (but only once) that will be used to perform the tests.
    #
    def init(config)
	@config = config

	# Instanciate only once each classes that has a requested test
	@config.test_list.each { |testname|
	    if ! @classes.has_key?(klass = @tests[testname])
		@classes[klass] = [klass.method("new").call(@cm, 
							    @param.domainname, 
							    @param.ns)]
	    end
	}
    end


    def test1(diag, method, testname, ns=nil, ip=nil) 
	# Print test description
	@formatter.synchronize {
	    if @param.testdesc
		desc = if @param.tagonly
		       then testname
		       else $mc.get("#{testname}_testname")
		       end
		@formatter.testing(desc, ns, ip)
	    end
	    @formatter.counter.processed(1) if @param.counter
	}

	errmsg = nil
	xpl    = nil
	type   = Test::Error
	args   = []
	args   << ns if !ns.nil?
	args   << ip if !ip.nil?
	begin
	    type = method.call(*args) ? Test::Succeed : Test::Failed
	rescue NResolv::RefusedError
	    errmsg = "Connection refused"
	rescue Exception => e
	    errmsg = e.to_s
	    raise if $dbg.enable?(DBG::DONT_RESCUE)
	end
	begin
	    diag.add_answer(type.new(testname, errmsg, xpl, ns, ip))
	rescue Diagnostic::FatalError
	    raise if @param.stop_on_fatal
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

	threadlist            = []
	testcount             = 0

	# Build test sequences
	@config.test_list.each { |testname| 
	    # Retrieve the method representing the test 'testname'
	    klass   = @tests[testname]
	    object, = @classes[klass]
	    method  = object.method(testname)

	    # Retrieve information relative to the test output
	    diag    = @config.action(testname)

	    # Perform the test according to their "types"
	    case klass.name

		# Test generic: 
		#  => ARG: *none*
	    when /^CheckGeneric::/
		check_generic << [diag, method, testname]
		testcount += 1
		
		# Test specific to the nameserver:
		#  => ARG: nameserver name
	    when /^CheckNameServer::/
		@param.ns.each { |name, |
		    testcount += 1
		    check_nameserver[name] ||= []
		    check_nameserver[name] <<
			[diag, method, testname, name]
		}

		# Test specific to the nameserver instance
		#  => ARG: nameserver name; nameserver IP
	    when /^CheckNetworkAddress::/ then 
		@param.ns.each { |ns_name, ns_addr_list|
		    @param.address_wanted?(ns_addr_list).each { |addr|
			testcount += 1
			check_network_address[addr] ||= []
			check_network_address[addr] <<
			    [ diag, method, testname, ns_name, addr ]
		    }
		}
	    end
	}

	# Perform tests
	begin
	    # Counter start
	    @formatter.counter.start(testcount) if @param.counter
	    
	    # Do CheckGeneric
	    check_generic.each { |args| test1(*args) }
	    
	    # Do CheckNameServer
	    check_nameserver.each_value { |args_list|
		args_list.each { |args| test1(*args) }
	    }
	    
	    # Do CheckNetworkAddress (and parallelize)
	    check_network_address.each_value { |args_list|
		threadlist << Thread::new {
		    args_list.each { |args| test1(*args) }
		}
	    }
	    threadlist.each { |thr| thr.join }
	    
	    # Counter end
	    @formatter.counter.done(@param.domainname.to_s) if @param.counter
	ensure
	    # Counter cleanup
	    @formatter.counter.finish if @param.counter
	end

	# Testdesc spacer
	@formatter.vskip if @param.testdesc
    end
end
