# ZCTEST 1.0
# $Id$

# 
# CONTACT     : zonecheck@nic.fr
# AUTHOR      : Stephane D'Alu <sdalu@nic.fr>
#
# CREATED     : 2002/08/02 13:58:17
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
    ## Check domain NS records
    ##
    class NS < Test
	with_msgcat "test/ns.%s"

	#-- Checks --------------------------------------------------
	# DESC: NS entries should exists
	def chk_ns(ns, ip)
	    ! ns(ip).empty?
	end
	
	# DESC: NS answers should be authoritative
	def chk_ns_auth(ns, ip)
	    ns(ip, @domain.name)		# request should be done twice
	    ns(ip, @domain.name, true)[0].aa	# so we need to force the cache
	end

	# DESC: Ensure coherence between NS and ANY
	def chk_ns_vs_any(ns, ip)
	    ns(ip).unsorted_eql?(any(ip, NResolv::DNS::Resource::IN::NS))
	end

	# DESC: NS record should have a valid hostname syntax
	def chk_ns_sntx(ns, ip)
	    ns(ip).each { |n|
		if ! NResolv::DNS::Name::is_valid_hostname?(n.name)
		    return false
		end
	    }
	    true
	end

	# DESC: NS record should not point to CNAME alias
	def chk_ns_cname(ns, ip) 
	    ns(ip).each { |n| return false if is_cname?(n.name, ip) }
	    true
	end

	# DESC: NS host should be resolvable
	def chk_ns_ip(ns, ip)
	    ns(ip).each { |n|
		return false unless is_resolvable?(n.name, ip, @domain.name)
	    }
	    true
	end
    end
end
