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
    Warning		= "w"		# Warning severity
    Fatal		= "f"		# Fatal severity
    Info		= "i"		# Informational
    Skip		= "-"		# Don't run the test

    S_Constants		= "constants"
    S_Tests		= "tests"

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
    def initialize(test_manager, category=nil)
	@test_manager	= test_manager
	@category	= category

	@test_list	= []
	@test_action	= {}
	@test_category	= {}

	@constants	= {}

	@order		= 0
	@order_switch	= { CheckGeneric        => 0, CheckNameServer => 1,  
	                    CheckNetworkAddress => 2, CheckExtra      => 3 }
    end


    #
    # Add a new test with its corresponding action
    #
    def newtest(testname, action, category)
	return if action == Skip

	# Check if test was already listed
	if @test_action.has_key?(testname)
	    raise ArgumentError, $mc.get("xcp_config_testexists") % [ name ]
	end

	# Check if test is currently registered
	if ! @test_manager.has_test?(testname)
	    raise ArgumentError, $mc.get("xcp_config_unknowntest") % [testname]
	end
	
	# Check for test ordering problems
	#  (according to their families)
	order_new = @order_switch[@test_manager.family(testname)]
	if order_new < @order
	    raise ArgumentError, $mc.get("xcp_config_ordering") % [ testname ]
	else
	    @order = order_new
	end
	
	# Check if we really want the test
	if @category && ! @category.include?(category)
	    return
	end

	# Register test
	@test_list << testname
	@test_action  [testname] = action
	@test_category[testname] = category
	
	# Debug
	$dbg.msg(DBG::CONFIG, "adding test: #{testname}")
    end


    #
    # Add a new constant
    #
    def newconst(name, value)
	if @constants.has_key?(name)
	    raise ArgumentError, $mc.get("xcp_config_constexists") % [ name ]
	end
	@constants[name] = value

	# Debug
	$dbg.msg(DBG::CONFIG, "adding constant: #{name}")
    end


    #
    # Retrieve the action associated to the test
    #
    def action(testname)
	@test_action[testname]
    end


    #
    # Retrieve the constant value
    #
    def const(name)
	begin
	    @constants.fetch(name)
	rescue IndexError
	    # WARN: not localized (programming error)
	    raise RuntimeError, "Trying to fetch undefined constant '#{name}'"
	end
    end


    #
    # Read the configuration file
    #
    def read(configfile, sections=[ S_Constants, S_Tests ])
	$dbg.msg(DBG::CONFIG, "reading file: #{configfile}")
	$dbg.msg(DBG::CONFIG, "requested sections: " + sections.join(", "))

	lineno    = 0
	File.open(configfile) { |io|
	    while line = io.gets
		# Read line
		lineno += 1
		line.chomp!			# remove return carriage
		line.sub!(/\s*\#.*/, "")	# remove comment
		next if line.empty?		# skip empty lines

		if line =~ /^\s*\[\s*(.*?)\s*]\s*$/
		    section = $1
		    case section
		    when S_Tests     then reader = method(:read_tests)
		    when S_Constants then reader = method(:read_constants)
		    else raise SyntaxError, fmt_line(lineno, 
			$mc.get("xcp_config_unknownsection") % [ section ])
							 
		    end
		    $dbg.msg(DBG::CONFIG, "parsing section: #{section}")

		else
		    if reader.nil?
			raise SyntaxError, fmt_line(lineno,
			$mc.get("xcp_config_nosection"))
		    end
		    if sections.include?(section)
			reader.call(line, lineno)
		    end
		end
	    end
	}
    end


    ## [private] #########################################################

    private
    #
    # Shortcut for formating text with line number prefixed
    #
    def fmt_line(lineno, txt)
	"%s %d: %s" % [ $mc.get("w_line"), lineno, txt ]
    end

    #
    # Test parser
    #
    def read_tests(line, lineno)
	# Syntax checker
	if line !~ /^([#{Warning}#{Info}#{Fatal}#{Skip}])\s+(\w+)\s+(\w+)\s*$/
	    raise SyntaxError, fmt_line(lineno,$mc.get("xcp_config_malformed"))
	end
	action, testname, category = $1, $2, $3
	
	# Add test
	begin
	    newtest(testname, action, category)
	rescue ArgumentError => e
	    raise ConfigError, fmt_line(lineno, e.to_s)
	end
    end

    #
    # Constant parser
    #
    def read_constants(line, lineno)
	# Syntax checker
	if line !~ /^(\w+)\s*=\s*\"((?:[^\"]|\\\")*)\"$/
	    raise SyntaxError, fmt_line(lineno,$mc.get("xcp_config_malformed"))
	end
	name, value = $1, $2

	# WARN: It's configuration writer fault
	value.untaint
	
	# Add constant
	begin
	    newconst(name, value)
	rescue ArgumentError => e
	    raise ConfigError, fmt_line(lineno, e.to_s)
	end
    end
end
