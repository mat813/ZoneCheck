# $Id$

class TestManager
    class DefinitionError < StandardError
    end


    def initialize
	@classes = {}
	@tests   = {}
	@config  = nil
    end


    def <<(klass)
	klass.public_instance_methods.each { |method| 
	    # Only deal with methods that represent a test
	    next unless method =~ /^chk_/

	    # Check for name collision
	    if @tests.has_key?(method) then
		raise DefinitionError, "test '#{method}' defined in classes '#{klass}' and '#{@tests[method]}"
	    end

	    # Register test method
	    @tests[method] = klass
	}
    end


    def has_test?(test)
	@tests.has_key?(test)
    end


    def init(config)
	@config = config

	# Instanciate only once each classes that has a requested test
	@config.test_list.each { |testname|
	    if ! @classes.has_key?(klass = @tests[testname])
		@classes[klass] = [ klass.method("create").call($param) ]
	    end
	}
    end


    def test
	@config.test_list.each { |testname| 
	    # Retrieve information assiociated to the test
	    object, = @classes[@tests[testname]]

	    # Perform the test
	    if ! object.method(testname).call
		if @config.action(testname).addmsg($mc.get(testname))
		    return false
		end
	    end
	}

	# All test have been succesful (only warnings)
	return true
    end
end



