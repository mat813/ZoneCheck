# ZCTEST 1.0
# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/09/11 11:20:17
#
# COPYRIGHT: AFNIC (c) 2003
# LICENSE  : GPL v2.0 (or MIT/X11-like after agreement)
# CONTACT  : zonecheck@nic.fr
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS: (see also CREDITS file)
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
	with_msgcat "test/loopback.%s"

	#-- Constants -----------------------------------------------
	IPv4LoopbackName = NResolv::DNS::Name::create(Address::IPv4::Loopback)
	IPv6LoopbackName = NResolv::DNS::Name::create(Address::IPv6::Loopback)

	#-- Checks --------------------------------------------------
	# DESC: loopback network should be delegated
	def chk_loopback_delegation(ns, ip)
	    soa(ip, IPv4LoopbackName.domain)
	end

	# DESC: loopback host reverse should exists
	def chk_loopback_host(ns, ip)
	    case ip
	    when Address::IPv4
		!ptr(ip, IPv4LoopbackName).empty?
	    when Address::IPv6
		!ptr(ip, IPv4LoopbackName).empty? &&
		!ptr(ip, IPv6LoopbackName).empty?
	    end
	end
    end
end
