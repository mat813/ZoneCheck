# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/07/19 07:28:13
#
# COPYRIGHT: AFNIC (c) 2003
# CONTACT  : zonecheck@nic.fr
# LICENSE  : GPL v2.0 (or MIT/X11-like after agreement)
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS:
#
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
