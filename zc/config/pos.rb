# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/07/19 07:28:13
#
# COPYRIGHT: AFNIC (c) 2003
# CONTACT  : zonecheck@nic.fr
# LICENSE  : GPL v2.0
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
    ##
    ## Store the token position
    ## 
    class Pos
	attr_reader :x, :y

	def initialize(x, y)
	    @x, @y = x, y
	end
    end
end
