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

#####
#
# TODO:
#   - move these functions into another file
#

require 'framework'

module CheckNetworkAddress
    ##
    ##
    ##
    class Misc < Test
	with_msgcat 'test/misc.%s'

	#-- Checks --------------------------------------------------
	# DESC:
	def chk_ns_reverse(ns, ip)
	    ip_name	= NResolv::DNS::Name::create(ip)
	    srv		= rec(ip) ? ip : nil
	    ! ptr(srv, ip_name).empty?
	end

	def chk_ns_matching_reverse(ns, ip)
	    ip_name	= NResolv::DNS::Name::create(ip)
	    srv		= rec(ip) ? ip : nil
	    res		= false
	    ptrlist     = ptr(srv, ip_name)
	    return true if ptrlist.empty?
	    ptrlist.each { |rev|
		res ||= (rev.ptrdname == ns) }
	    res
	end

	# DESC: Ensure coherence between given (param) primary and SOA
	def chk_given_nsprim_vs_soa(ns, ip)
	    mname = soa(ip).mname
	    if @domain.ns[0][0] != mname
		@domain.ns[1..-1].each { |nsname, |
		    return { 'given_primary' => @domain.ns[0][0],
			     'primary'       => mname } if nsname == mname }
	    end
	    true
	end
	   
	# DESC: Ensure coherence between given (param) nameservers and NS
	def chk_given_ns_vs_ns(ns, ip)
	    nslist_from_ns    = ns(ip).collect{ |n| n.name}
	    nslist_from_param = @domain.ns.collect { |n, ips| n }

	    return true if nslist_from_ns.unsorted_eql?(nslist_from_param)
	    { 'list_from_ns'    => nslist_from_ns   .collect{|e| e.to_s } \
		                                    .sort.join(', '),
	      'list_from_param' => nslist_from_param.collect{|e| e.to_s } \
		                                    .sort.join(', ') }
	end

	# DESC: Ensure that a server claiming to be recursive really is it
	def chk_correct_recursive_flag(ns, ip)
	    return true unless rec(ip)

	    dbgmsg(ns, ip) { 
		'asking SOA for: ' + 
		[ @domain.name.tld || NResolv::DNS::Name::Root,
		    NResolv::DNS::Name::create(ip.namespace) ].join(', ')
	    }

	    soa(ip, @domain.name.tld || NResolv::DNS::Name::Root) &&
		soa(ip, NResolv::DNS::Name::create(ip.namespace))
	end

#	# DESC:
#	def chk_rir_inetnum(ns, ip)
#	    true
#	end

#	# DESC:
#	def chk_rir_route(ns, ip)
#	    true
#	end
	#-- Tests ---------------------------------------------------
	# 
	def tst_recursive_server(ns, ip)
	    rec(ip) ? 'true' : 'false'
	end
    end
end
