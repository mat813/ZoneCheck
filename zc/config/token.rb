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

require 'config/pos'

##
##
##
class Config
    class Token
	SYMBOL		= 1
	STRING		= 2
	KEYWORD		= 3
	CHAR		= 4
	EOF		= 9

	KW_case		= "case"
	KW_when		= "when"
	KW_else		= "else"
	KW_end		= "end"


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

	def to_s ; 
	    @data
	end
	
	attr_reader :type, :data, :pos
    end
end    
