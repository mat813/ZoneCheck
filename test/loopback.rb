# ZCTEST 1.0
# $Id$

# 
# CONTACT     : zonecheck@nic.fr
# AUTHOR      : Stephane D'Alu <sdalu@nic.fr>
#
# CREATED     : 2002/09/11 11:20:17
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

	#-- Helper --------------------------------------------------
	def ipv4_delegated?(ip)
	    (!soa(ip, IPv4LoopbackName.domain).nil?             ||
	     !soa(ip, IPv4LoopbackName.domain.domain).nil?      ||
	     !soa(ip, IPv4LoopbackName.domain.domain.domain).nil? )
	end

	def ipv6_delegated?(ip)
	    !soa(ip, IPv6LoopbackName.domain).nil?	    
	end

	#-- Checks --------------------------------------------------
	# DESC: loopback network should be delegated
	def chk_loopback_delegation(ns, ip)
	    case ip
	    when Address::IPv4
		ipv4_delegated?(ip)
	    when Address::IPv6
		ipv4_delegated?(ip) && ipv6_delegated?(ip)
	    end
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
