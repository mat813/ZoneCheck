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
    ## Check domain SOA record
    ##
    class SOA < Test
	with_msgcat "test/soa.%s"

	#-- Tests ---------------------------------------------------
	# DESC: SOA entries should exists
	def chk_soa(ns, ip)
	    ! soa(ip).nil?
	end
	
	# DESC: SOA answers should be authoritative
	def chk_soa_auth(ns, ip)
	    soa(ip, @domain.name)		# request should be done twice
	    soa(ip, @domain.name, true).aa	# so we need to force the cache
	end

	# DESC: SOA email address shouldn't have an '@'
	def chk_soa_contact_sntx_at(ns, ip)
	    soa(ip).rname[0].to_s !~ /@/
	end

	# DESC: SOA email address should have a valid syntax
	def chk_soa_contact_sntx(ns, ip)
	    NResolv::DNS::Name::is_valid_mbox_address?(soa(ip).rname)
	end

	# DESC: SOA master should have a valid hostname syntax
	def chk_soa_master_sntx(ns, ip)
	    NResolv::DNS::Name::is_valid_hostname?(soa(ip).mname)
	end
	
	# DESC: SOA master should be fully qualified
	def chk_soa_master_fq(ns, ip)
	    return true if soa(ip).mname.absolute?
	    { "mname" => soa(ip).mname }
	end

	# DESC: SOA master should not point to CNAME alias
	def chk_soa_ns_cname(ns, ip)
	    return true unless name = is_cname?(soa(ip).mname, ip)
	    { "master" => soa(ip).mname, "alias" => name }
	end
	
	# DESC: recommanded format for serial is YYYYMMDDnn
	def chk_soa_serial_fmt_YYYYMMDDnn(ns, ip)
	    serial = soa(ip).serial
	    return true if (serial > 1999000000) && (serial < 2010000000)
	    { "serial" => serial }
	end

	# DESC: recommanded refresh is > 6h
	def chk_soa_refresh_6h(ns, ip)
	    return true if soa(ip).refresh >= 6*3600
	    { "refresh" => soa(ip).refresh }
	end

	# DESC: coherence between 'retry' and 'refresh'
	def chk_soa_retry_refresh(ns, ip)
	    return true if soa(ip).retry <= soa(ip).refresh
	    { "retry" => soa(ip).retry, "refresh" => soa(ip).refresh }
	end
	
	# DESC: recommanded retry is > 1h
	def chk_soa_retry_1h(ns, ip)
	    return true if soa(ip).retry >= 3600
	    { "retry" => soa(ip).retry }
	end

	# DESC: recommanded expire is > 7d
	def chk_soa_expire_7d(ns, ip)
	    return true if soa(ip).expire >= 7 * 86400
	    { "expire" => soa(ip).expire }
	end

	# DESC: coherence between 'expire' and 'refresh'
	def chk_soa_expire_7refresh(ns, ip)
	    return true if soa(ip).expire >= 7 * soa(ip).refresh
	    { "expire"  => soa(ip).expire, "refresh" => soa(ip).refresh }
	end

	# DESC: recommanded minimum is <= 3h, not working > 1d
	def chk_soa_minimum_1d(ns, ip)
	    return true if soa(ip).minimum <= 86400
	    { "minimum" => soa(ip).minimum }
	end

	# DESC: Ensure coherence between SOA and ANY
	def chk_soa_vs_any(ns, ip)
	    soa(ip) == any(ip, NResolv::DNS::Resource::IN::SOA)[0]
	end

	# DESC: coherence of serial number with primary
	def chk_soa_coherence_serial(ns,ip)
	    serial_ref   = soa(@domain.ns[0][1][0]).serial
	    serial_other = soa(ip).serial
	    return true if serial_ref >= serial_other
	    { "serial_ref"  => serial_ref,
	      "host_ref"    => "#{@domain.ns[0][0]}/#{@domain.ns[0][1][0]}",
	      "serial_this" => serial_other }
	end

	# DESC: coherence of master with primary
	def chk_soa_coherence_master(ns,ip)
	    mname_ref   = soa(@domain.ns[0][1][0]).mname
	    mname_other = soa(ip).mname
	    return true if mname_ref == mname_other
	    { "mname_ref"  => mname_ref,
	      "host_ref"   => "#{@domain.ns[0][0]}/#{@domain.ns[0][1][0]}",
	      "mname_this" => mname_other }
	end
    end
end
