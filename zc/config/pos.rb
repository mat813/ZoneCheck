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

##
##
##
class Config
    class Pos
	attr_reader :x, :y

	def initialize(x, y)
	    @x = x
	    @y = y
	end
    end
end