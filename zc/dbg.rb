# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/09/16 13:31:29
#
# COPYRIGHT: AFNIC (c) 2003
# LICENSE  : GPL v2.0 (or MIT/X11-like after agreement)
# CONTACT  : zonecheck@nic.fr
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS: (see also CREDITS file)
#
#


##
## Debugging
##
class DBG
    #
    # Debugging types
    #
    LOADING	 = 0x0001	# Test loading status
    LOCALE       = 0x0002	# Localization / Internationalisation
    CONFIG       = 0x0004	# Configuration
    PARSER       = 0x0008	# Parser
    TESTS        = 0x0010	# Tests
    AUTOCONF     = 0x0100       # Autoconf
    DBG          = 0x0800	# The debugger itself
    CACHE_INFO   = 0x1000	# Information about cached object

    NOCACHE      = 0x2000	# Disable caching
    DONT_RESCUE  = 0x4000	# Don't try to rescue some exceptions
    CRAZYDEBUG   = 0x8000	# Crazy Debug, don't try it...

    #
    # Tag associated with some types
    #
    Tag = { 
	LOADING		=> "loading",
	LOCALE		=> "locale",
	CONFIG		=> "config",
	PARSER		=> "parser",
	TESTS		=> "tests",
	AUTOCONF	=> "autoconf",
	DBG		=> "dbg",
	CACHE_INFO	=> "cache"
    }


    #
    # Initializer
    #
    def initialize(lvl=0, output=$stderr)
	@output = output
	@lvl    = lvl
	msg(DBG, "Debugger initialized at level %0x" % [ @lvl ])
    end


    #
    # Test if debug is enabled for that type
    #
    def enabled?(type) 
	@lvl & type != 0
    end
    alias [] enabled?


    #
    # Enable debugging for the specified type
    #
    def []=(type, enable)
	self.level = enable ? @lvl | type : @lvl & ~type
    end


    #
    # Change debugging level
    #
    def level=(lvl)
	oldcrazy = enabled?(CRAZYDEBUG)

	# parsing
	case lvl
	when String then @lvl = lvl =~ /^0x/ ? lvl.hex : lvl.to_i
	when Fixnum then @lvl = lvl
	else raise ArgumentError, "unable to interprete: #{lvl}"
	end
	
	# message
	msg(DBG, "Setting level to 0x%0x" % [ lvl ])

	# enable/disable CrazyDebug
	if    enabled?(CRAZYDEBUG)
	    set_trace_func(proc { |event, file, line, id, binding, classname|
			       @output.printf "%8s %s:%-2d %10s %8s\n", 
				   event, file, line, id, classname
			   })
	elsif oldcrazy
	    set_trace_func(nil)
	end
    end


    #
    # Print debugging message
    #
    def msg(type, str)
	@output.puts "DBG[#{Tag[type]}]: #{str}" if enabled?(type)
    end
end
