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

module CheckNameServer
    ##
    ## Check accessibility of nameserver
    ## 
    ## - these tests are performed without contacting the nameserver
    ##   (see modules CheckNetworkAddress for that)
    ##
    class ServerAccess < Test
	with_msgcat "test/nameserver.%s"

	#-- Initialization ------------------------------------------
	def initialize(*args)
	    super(*args)

	    @cache.create(:ip)
	end

	#-- Shortcuts -----------------------------------------------
	def ip(ns)
	    @cache.use(:ip, ns) {
		@domain.ns.assoc(ns)[1] }
	end

	#-- Checks --------------------------------------------------
	# DESC: Nameserver IP addresses should be public!
	def chk_ip_private(ns)
	    ip(ns).each { |addr| return false if addr.private? }
	    true
	end

	# DESC:
	def chk_ip_bogon(ns)
	    bogon = []
	    ip(ns).each { |addr|
		bname = NResolv::DNS::Name::create(addr.to_dnsform +
						   ".bogons.cymru.com.")
		case addr
		when Address::IPv4
		    bogon << addr unless @cm[nil].addresses(bname).empty?
		end
	    }
	    return true if bogon.empty?
	    { "addresses" => bogon.join(", ") }
	end
    end
end
