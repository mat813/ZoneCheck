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


class DBG
    TEST_LOADING = 0x0001	# Display test loading status
    CACHE_INFO   = 0x1000	# Display cache information
    NOCACHE      = 0x2000	# Disable caching
    CRAZYDEBUG   = 0x8000	# Crazy Debug, the name says it all
    DONT_RESCUE  = 0x4000	# Don't try to rescue some exceptions

    C = { 
	TEST_LOADING => "test",
	CACHE_INFO   => "cache",
    }


    CrazyDebug_Proc =  proc { |event, file, line, id, binding, classname|
	printf "%8s %s:%-2d %10s %8s\n", event, file, line, id, classname
    }



    def initialize(lvl=0, output=$stderr)
	@output = output
	@lvl    = lvl
    end

    def enable?(type) 
	@lvl & type != 0
    end

    def level=(lvl)
	case lvl
	when String
	    @lvl = lvl =~ /^0x/ ? lvl.hex : lvl.to_i
	when Fixnum
	    @lvl = lvl
	else
	    raise ArgumentError, "unable to interprete: #{lvl}"
	end
	
	# enable/disable CrazyDebug
	set_trace_func (enable?(CRAZYDEBUG) ? CrazyDebug_Proc : nil)
    end

    def msg(type, str)
	@output.puts "DBG[#{C[type]}]: #{str}" if (@lvl & type) != 0
    end
end
