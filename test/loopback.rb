# ZCTEST 1.0
# $Id$

# 
# AUTHOR : Stephane D'Alu <sdalu@nic.fr>
# CREATED: 2002/09/11 11:20:17
#
# $Revivion$ 
# $Date$
#
# CONTRIBUTORS:
#
#

#####
#
# TODO:
#   - add support for IPv6
#

require 'framework'

module CheckNetworkAddress
    ##
    ## Check for loopback network delegation/resolution
    ## 
    class Loopback < Test
	ZC_Category = "dns"

	#-- Constants -----------------------------------------------
	IPv4LoopbackName = NResolv::DNS::Name::create(Address::IPv4::Loopback)
	IPv6LoopbackName = NResolv::DNS::Name::create(Address::IPv6::Loopback)

	#-- Tests ---------------------------------------------------
	# DESC: loopback network should be delegated
	def chk_loopback_delegation(ns, ip)
	    soa(ip, IPv4LoopbackName.domain)
	end

	# DESC: loopback host reverse should exists
	def chk_loopback_host(ns, ip)
	    !ptr(ip, IPv4LoopbackName).empty?
	end
    end
end
