# $Id$


##
##
##
class TestManager
    # ATTRIBUTES:
    #  param   : program configuration parameters
    #  config  : configuration file informations
    #  tests   : associate each test with its class
    #  classes : associate each test class with an array where the first
    #             element is one of class instance
    #  ic      : root node of the information cache (InfoCache),
    #             initialized with the default DNS resolver (Test::DefaultDNS)



    ##
    ## Error in the test definition
    ##
    class DefinitionError < StandardError
    end



    #
    # Initialize a new object.
    #
    def initialize(param)
	@param   = param
	@config  = nil
	@tests   = {}
	@classes = {}
	@ic	 = InfoCache::create(Test::DefaultDNS)
    end



    #
    # Register all the test than are provided by the class 'klass'.
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
    def has_test?(test)
	@tests.has_key?(test)
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
		@classes[klass] = [ klass.method("create").call(@param, @ic) ]
	    end
	}
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

	# For each test requested in the configuration file
	@config.test_list.each { |testname| 
	    # Retrieve the method representing the test 'testname'
	    klass   = @tests[testname]
	    object, = @classes[klass]
	    method  = object.method(testname)

	    # Retrieve information relative to the test output
	    diag   = @config.action(testname)
	    errmsg = $mc.get("#{testname}_err")

	    # Perform the test according to their "types"
	    case klass.name

		# Test generic: 
		#  => ARG: *none*
	    when /^CheckGeneric::/
		diag.addmsg(errmsg) if ! method.call
		
		# Test specific to the nameserver:
		#  => ARG: nameserver name
	    when /^CheckNameServer::/
		@param.ns.each { |n|	    ns_name, = n
		    diag.addmsg(errmsg, ns_name) if !method.call(ns_name)
		}

		# Test specific to the nameserver instance
		#  => ARG: nameserver name; nameserver IP
	    when /^CheckNetworkAddress::/ then 
		@param.ns.each { |n|	    ns_name, ns_addr_list = n
		    @param.address_wanted?(ns_addr_list).each { |addr|
			if !method.call(ns_name, addr)
			    diag.addmsg(errmsg, "#{ns_name}/#{addr}")
			end
		    }
		}
	    end
	}

	# All test have been succesful (only warnings)
	return true
    end
end
