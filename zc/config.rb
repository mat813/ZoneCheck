# $Id$

# 
# AUTHOR : Stephane D'Alu <sdalu@nic.fr>
# CREATED: 2002/07/19 07:28:13
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS:
#
#

require 'framework'

##
## Hold the information about the zc.conf configuration file
##
class Config
    Warning	= "w"
    Info	= "i"
    Fatal	= "f"
    Skip	= "-"


    ##
    ## Syntax error, while parsing the file
    ##
    class SyntaxError < StandardError
    end



    ##
    ## Configuration error
    ##  (unknown test, ordering problem)
    ## 
    class ConfigError < StandardError
    end



    attr_reader :test_list



    #
    # Initializer
    #
    def initialize(test_manager)
	@test_manager	= test_manager

	@test_list	= []
	@test_action	= {}

	@order		= 0
	@order_switch	= { CheckGeneric => 0, CheckNameServer => 1,  
	                    CheckNetworkAddress => 2 }
    end


    #
    # Retrieve the action associated to the test
    #
    def action(testname)
	@test_action[testname]
    end


    #
    # Add a new test with its corresponding action
    #
    def add(testname, action)
	return if action == Skip

	# Check if test is currently registered
	if ! @test_manager.has_test?(testname)
	    raise ArgumentError, "unknown test '#{testname}'"
	end
		
	# Check for test ordering problems
	#  (according to their families)
	order_new = @order_switch[@test_manager.family(testname)]
	if order_new < @order
	    raise ArgumentError, "ordering problem with '#{testname}'"
	else
	    @order = order_new
	end
	
	# Register test
	@test_list << testname
	@test_action[testname] = action
    end


    #
    # Read the configuration file
    #
    def read(configfile)
	lineno    = 0
	File.open(configfile) { |io|
	    while line = io.gets
		# Read line
		lineno += 1
		line.chomp!			# remove return carriage
		line.sub!(/\s*\#.*/, "")	# remove comment
		next if line.empty?		# skip empty lines

		# Syntax checker
		if line !~ /^([#{Warning}#{Info}#{Fatal}#{Skip}])\s+(\w+)$/
		    raise SyntaxError, "line #{lineno}: malformed command"
		end
		action, testname = $1, $2
		
		# Add test
		begin
		    add(testname, action)
		rescue ArgumentError => e
		    raise ConfigError, "line #{lineno}: #{e}"
		end
	    end
	}
    end
end
