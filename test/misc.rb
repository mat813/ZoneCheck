# $Id$

# 
# AUTHOR : Stephane D'Alu <sdalu@nic.fr>
# CREATED: 2002/08/02 13:58:17
#
# $Revivion$ 
# $Date$
#
# CONTRIBUTORS:
#
#

require 'framework'

module CheckNetworkAddress
    class Misc < Test
	#-- Tests ---------------------------------------------------

	def chk_ns_reverse(ns, ip)
	    ! (( @cm[ip].rec(@domain_name) && ptr(ip.to_name, ip).empty?) ||
	       (!@cm[ip].rec(@domain_name) && ptr(ip.to_name,nil).empty?))
	end
    end
end
