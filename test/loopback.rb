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

require 'framework'

module CheckNetworkAddress
    class Loopback < Test
	IPv4LoopbackName = NResolv::DNS::Name::create(Address::IPv4::Loopback)
	IPv6LoopbackName = NResolv::DNS::Name::create(Address::IPv6::Loopback)


	#-- Tests ---------------------------------------------------
	def chk_loopback_delegation(ns, ip)
	    soa(ip, IPv4LoopbackName.domain)
	end

	def chk_loopback_host(ns, ip)
	    !ptr(ip, IPv4LoopbackName).empty?
	end
    end
end
