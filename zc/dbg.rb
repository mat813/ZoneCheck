# $Id$

# 
# CONTACT     : zonecheck@nic.fr
# AUTHOR      : Stephane D'Alu <sdalu@nic.fr>
#
# CREATED     : 2002/09/16 13:31:29
# REVISION    : $Revision$ 
# DATE        : $Date$
#
# CONTRIBUTORS: (see also CREDITS file)
#
#
# LICENSE     : GPL v2 (or MIT/X11-like after agreement)
# COPYRIGHT   : AFNIC (c) 2003
#
# This file is part of ZoneCheck.
#
# ZoneCheck is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# ZoneCheck is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ZoneCheck; if not, write to the Free Software Foundation,
# Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#


##
## Debugging
##
class DBG
    #
    # Debugging types
    #
    LOADING	 = 0x0001	# Loading tests
    LOCALE       = 0x0002	# Localization / Internationalisation
    CONFIG       = 0x0004	# Configuration
    PARSER       = 0x0008	# Parser
    TESTS        = 0x0010	# Tests performed
    AUTOCONF     = 0x0100       # Autoconf
    TESTDBG      = 0x0200	#
    DBG          = 0x0800	# Debugger itself
    CACHE_INFO   = 0x1000	# Information about cached object

    NOCACHE      = 0x2000	# Disable caching
    DONT_RESCUE  = 0x4000	# Don't try to rescue exceptions
    CRAZYDEBUG   = 0x8000	# Crazy Debug, don't try it...

    #
    # Tag associated with some types
    #
    Tag = { 
	LOADING		=> 'loading',
	LOCALE		=> 'locale',
	CONFIG		=> 'config',
	PARSER		=> 'parser',
	TESTS		=> 'tests',
	AUTOCONF	=> 'autoconf',
	TESTDBG		=> 'testdbg',
	DBG		=> 'dbg',
	CACHE_INFO	=> 'cache'
    }


    #
    # Initializer
    #
    def initialize(lvl=0, output=$stderr)
	@output = output
	@lvl    = lvl
	msg(DBG) { "Debugger initialized at level %0x" % @lvl }
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
	msg(DBG) { "Setting level to 0x%0x" % lvl }

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
    # WARN: It is adviced to use a block instead of the string 
    #       second argument, as this will provide a lazy evaluation
    #
    def msg(type, str=nil)
	return unless enabled?(type)

	unless block_given? ^ !str.nil?
	    raise ArgumentError, 'either string or block should be given'
	end
	str = yield if block_given?
	@output.puts "DBG[#{Tag[type]}]: #{str}"
    end
end
