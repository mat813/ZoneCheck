# $Id$

# 
# AUTHOR : Stephane D'Alu <sdalu@nic.fr>
# CREATED: 2002/09/16 13:31:29
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS:
#
#


##
## Debugging
##
class DBG
    #
    # Debugging types
    #
    TEST_LOADING = 0x0001	# Test loading status
    LOCALE       = 0x0002	# Localization / Internationalisation
    AUTOCONF     = 0x0100       # Autoconf
    CACHE_INFO   = 0x1000	# Information about cached object

    NOCACHE      = 0x2000	# Disable caching
    DONT_RESCUE  = 0x4000	# Don't try to rescue some exceptions
    CRAZYDEBUG   = 0x8000	# Crazy Debug, don't try it...

    #
    # Tag associated with some types
    #
    Tag = { 
	TEST_LOADING	=> "test",
	LOCALE		=> "locale",
	AUTOCONF	=> "autoconf",
	CACHE_INFO	=> "cache",
    }

    #
    # CrazyDebug procedure
    #  (executed for every method call)
    #
    CrazyDebug_Proc =  proc { |event, file, line, id, binding, classname|
	printf "%8s %s:%-2d %10s %8s\n", event, file, line, id, classname
    }


    #
    # Initializer
    #
    def initialize(lvl=0, output=$stderr)
	@output = output
	@lvl    = lvl
    end


    #
    # Test if debug is enabled for that type
    #
    def enabled?(type) 
	@lvl & type != 0
    end


    #
    # Change debugging level
    #
    def level=(lvl)
	oldcrazy = enabled?(CRAZYDEBUG)

	case lvl
	when String
	    @lvl = lvl =~ /^0x/ ? lvl.hex : lvl.to_i
	when Fixnum
	    @lvl = lvl
	else
	    raise ArgumentError, "unable to interprete: #{lvl}"
	end
	
	# enable/disable CrazyDebug
	if    enabled?(CRAZYDEBUG) then set_trace_func(CrazyDebug_Proc)
	elsif oldcrazy             then set_trace_func(nil)
	end
    end


    #
    # Print debugging message
    #
    def msg(type, str)
	@output.puts "DBG[#{Tag[type]}]: #{str}" if enabled?(type)
    end
end
