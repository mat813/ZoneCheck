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
    ## Check domain MX record
    ##
    class MX < Test
	with_msgcat "test/mx.%s"

	#-- Checks --------------------------------------------------
	# DESC: MX entries should exists
	def chk_mx(ns, ip)
	    ! mx(ip).empty?
	end
	
	# DESC: MX answers should be authoritative
	def chk_mx_auth(ns, ip)
	    mx(ip, @domain.name)		# request should be done twice
	    mx(ip, @domain.name, true)[0].aa	# so we need to force the cache
	end

	# DESC: Ensure coherence between MX and ANY
	def chk_mx_vs_any(ns, ip)
	    mx(ip).unsorted_eql?(any(ip, NResolv::DNS::Resource::IN::MX))
	end

	# DESC: MX exchanger should have a valid hostname syntax
	def chk_mx_sntx(ns, ip)
	    mx(ip).each { |m|
		if ! NResolv::DNS::Name::is_valid_hostname?(m.exchange)
		    return false
		end
	    }
	    true
	end

	# DESC: MX record should not point to CNAME alias
	def chk_mx_cname(ns, ip) 
	    mx(ip).each { |m| return false if is_cname?(m.exchange, ip) }
	    true
	end

	# DESC: MX exchange should be resolvable
	def chk_mx_ip(ns, ip)
	    mx(ip).each { |m| mx_name = m.exchange
		return { 'mx' => mx_name } unless is_resolvable?(mx_name, ip,
								 @domain.name)
	    }
	    true
	end

	# DESC: check for absence of wildcard MX
	def chk_mx_no_wildcard(ns, ip)
	    host    = const("inexistant_hostname")
	    host_fq = @domain.name.prepend(host)
	    mx(ip, host_fq).empty?
	end


	#-- Tests ---------------------------------------------------
	def tst_mail_by_mx_or_a(ns, ip)
	    mx(ip).empty? ? "A" : "MX"
	end
    end
end
