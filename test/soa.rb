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
	with_msgcat 'test/soa.%s'


	#-- Initialisation ------------------------------------------
	def initialize(*args)
	    super(*args)
	    @soa_expire_min  = const('soa:expire:min').to_i
	    @soa_expire_max  = const('soa:expire:max').to_i
	    @soa_minimum_min = const('soa:minimum:min').to_i
	    @soa_minimum_max = const('soa:minimum:max').to_i
	    @soa_refresh_min = const('soa:refresh:min').to_i
	    @soa_refresh_max = const('soa:refresh:max').to_i
	    @soa_retry_min   = const('soa:retry:min').to_i
	    @soa_retry_max   = const('soa:retry:max').to_i
	end

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
	    { 'mname' => soa(ip).mname }
	end

	# DESC: SOA master should not point to CNAME alias
	def chk_soa_ns_cname(ns, ip)
	    return true unless name = is_cname?(soa(ip).mname, ip)
	    { 'master' => soa(ip).mname, 'alias' => name }
	end
	
	# DESC: recommanded format for serial is YYYYMMDDnn
	def chk_soa_serial_fmt_YYYYMMDDnn(ns, ip)
	    serial = soa(ip).serial
	    return true if (serial > 1999000000) && (serial < 2010000000)
	    { 'serial' => serial }
	end

	# DESC: recommanded expire
	def chk_soa_expire(ns, ip)
	    soa_expire = soa(ip).expire
	    if (soa_expire >= @soa_expire_min) && 
		    (soa_expire <= @soa_expire_max)
	    then true
	    else { 'expire' => soa_expire }
	    end
	end

	# DESC: recommanded minimum
	def chk_soa_minimum(ns, ip)
	    soa_minimum = soa(ip).minimum
	    if (soa_minimum >= @soa_minimum_min) &&
		    (soa_minimum <= @soa_minimum_max)
	    then true
	    else { 'minimum' => soa_minimum }
	    end
	end

	# DESC: recommanded refresh
	def chk_soa_refresh(ns, ip)
	    soa_refresh = soa(ip).refresh
	    if (soa_refresh >= @soa_refresh_min) && 
		    (soa_refresh <= @soa_refresh_max)
	    then true
	    else { 'refresh' => soa_refresh }
	    end
	end

	# DESC: recommanded retry
	def chk_soa_retry(ns, ip)
	    soa_retry = soa(ip).retry
	    if (soa_retry >= @soa_retry_min) && (soa_retry <= @soa_retry_max)
	    then true
	    else { 'retry' => soa_retry }
	    end
	end

	# DESC: coherence between 'retry' and 'refresh'
	def chk_soa_retry_refresh(ns, ip)
	    return true if soa(ip).retry <= soa(ip).refresh
	    { 'retry' => soa(ip).retry, 'refresh' => soa(ip).refresh }
	end
	
	# DESC: coherence between 'expire' and 'refresh'
	def chk_soa_expire_7refresh(ns, ip)
	    return true if soa(ip).expire >= 7 * soa(ip).refresh
	    { 'expire'  => soa(ip).expire, 'refresh' => soa(ip).refresh }
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
	    { 'serial_ref'  => serial_ref,
	      'host_ref'    => "#{@domain.ns[0][0]}/#{@domain.ns[0][1][0]}",
	      'serial_this' => serial_other }
	end


	# DESC: coherence of contact with primary
	def chk_soa_coherence_contact(ns,ip)
	    rname_ref   = soa(@domain.ns[0][1][0]).rname
	    rname_other = soa(ip).rname
	    return true if rname_ref == rname_other
	    { 'rname_ref'   => rname_ref,
	      'host_ref'    => "#{@domain.ns[0][0]}/#{@domain.ns[0][1][0]}",
	      'rname_this'  => rname_other }
	end

	# DESC: coherence of master with primary
	def chk_soa_coherence_master(ns,ip)
	    mname_ref   = soa(@domain.ns[0][1][0]).mname
	    mname_other = soa(ip).mname
	    return true if mname_ref == mname_other
	    { 'mname_ref'  => mname_ref,
	      'host_ref'   => "#{@domain.ns[0][0]}/#{@domain.ns[0][1][0]}",
	      'mname_this' => mname_other }
	end

	# DESC: coherence of soa with primary
	def chk_soa_coherence(ns,ip)
	    serial_ref   = soa(@domain.ns[0][1][0]).serial
	    serial_other = soa(ip).serial
	    return true if serial_ref != serial_other
	    soa(@domain.ns[0][1][0]) == soa(ip)
	end
    end
end
