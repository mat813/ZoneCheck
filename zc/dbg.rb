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


# 0x0001: Loading of tests

class DBG
    TEST_LOADING = 0x0001
    CACHE_INFO   = 0x1000
    NOCACHE      = 0x2000

    C = { TEST_LOADING, "test" }

    def initialize(lvl=0, output=$stderr)
	@output = output
	@lvl    = lvl
    end

    def level=(lvl)
	@lvl = lvl
    end

    def puts(type, str)
	@output.puts "DBG[#{C[type]}]: #{str}" if (@lvl & type) != 0
    end
end

