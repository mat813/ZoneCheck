# $Id$

class Config
    class SyntaxError < StandardError
    end

    class ConfigError < StandardError
    end

    attr_reader :test_list

    def initialize 
	@test_list	= []
	@test_action	= {}
    end

    def action(testname)
	@test_action[testname]
    end

    def read(test_manager, configfile="/usr/local/etc/zc.conf")
	lineno = 0
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
		
		# Register test
		@test_list << testname
		@test_action[testname] = case action
					 when "i" then $param.info
					 when "w" then $param.warning
					 when "f" then $param.fatal
					 end
	    end
	}
    end
end

