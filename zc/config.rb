# $Id$

# 
# AUTHOR : Stephane D'Alu <sdalu@nic.fr>
# CREATED: 2002/07/19 07:28:13
#
# $Revivion$ 
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
    def initialize(fatal, warning, info)
	@fatal		= fatal
	@warning	= warning
	@info		= info

	@test_list	= []
	@test_action	= {}
    end


    #
    #
    #
    def action(testname)
	@test_action[testname]
    end



    #
    #
    #
    def read(test_manager, configfile)
	lineno    = 0
	order_cur = 0 
	order     = { CheckGeneric => 0, CheckNameServer => 1,  
                      CheckNetworkAddress => 2 }
	File.open(configfile) { |io|
	    while line = io.gets
		# Read line
		lineno += 1
		line.chomp!			# remove return carriage
		line.sub!(/\s*\#.*/, "")	# remove comment
		next if line.empty?		# skip empty lines

		# Syntax checker
		if line !~ /^([wif-])\s+(\w+)$/
		    raise SyntaxError, "line #{lineno}: malformed command"
		end
		action, testname = $1, $2
		
		# Skip test not used
		next if action == "-"

		# Check if test is currently registered
		if ! test_manager.has_test?(testname)
		    raise ConfigError, 
			"line #{lineno}: unknown test '#{testname}'"
		end
		
		# Check for test ordering problems
		#  (according to their families)
		order_new = order[test_manager.family(testname)]
		if order_new < order_cur
		    raise ConfigError,
			"line #{lineno}: ordering problem with '#{testname}'"
		else
		    order_cur = order_new
		end

		# Register test
		@test_list << testname
		@test_action[testname] = case action
					 when "w" then @warning
					 when "i" then @info
					 when "f" then @fatal
					 end
	    end
	}
    end
end
