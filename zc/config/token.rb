# $Id$

# 
# CONTACT     : zonecheck@nic.fr
# AUTHOR      : Stephane D'Alu <sdalu@nic.fr>
#
# CREATED     : 2002/07/19 07:28:13
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

require 'config/pos'

##
##
##
class Config
    ##
    ## Token
    ##
    class Token
	SYMBOL		= 1		# Symbol  : \w+
	STRING		= 2		# String  : "([^\\\"]|\\[\\\"])*"
	KEYWORD		= 3		# Keyword
	CHAR		= 4		# Character
	EOF		= 9		# End Of File

	KW_case		= "case"	# 
	KW_when		= "when"	# 
	KW_else		= "else"	# 
	KW_end		= "end"		# 


	def initialize(type, data, x, y)
	    @type	= type
	    @data	= data
	    @pos	= Pos::new(x, y)
	end
	
	def eql(other)
	    case other
	    when Array  then (self.type == other[0]) && (self.data == other[1])
	    when Fixnum then self.type == other
	    else (self.type == other.type) && (self.data == other.data)
	    end
	end
	alias == eql

	def to_s 
	    @data
	end
	
	attr_reader :type, :data, :pos
    end
end    
