# ZCTEST 1.0
# $Id$

# 
# AUTHOR : Stephane D'Alu <sdalu@nic.fr>
# CREATED: 2002/08/02 13:58:17
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS:
#
#

require 'framework'

module CheckNetworkAddress
    ##
    ## Check domain SOA record
    ##
    class SOA < Test
	#-- Tests ---------------------------------------------------
	# DESC: SOA entries should exists
	def chk_soa(ns, ip)
	    ! soa(ip).nil?
	end
	
	# DESC: SOA answers should be authoritative
	def chk_soa_auth(ns, ip)
	    soa(ip, @domain_name)		# request should be done twice
	    soa(ip, @domain_name, true).aa	# so we need to force the cache
	end

	# DESC: SOA email adddress shouldn't have an '@'
	def chk_soa_sntx_contact_at(ns, ip)
	    soa(ip).rname.to_s !~ /@/
	end

	# DESC: SOA master should have a valid hostname syntax
	def chk_soa_sntx_master(ns, ip)
	    NResolv::DNS::Name::is_valid_hostname?(soa(ip).mname)
	end

	# DESC: SOA master should not point to CNAME alias
	def chk_soa_ns_cname(ns, ip)
	    ! is_cname?(soa(ip).mname, ip)
	end
	
	# DESC: recommanded format for serial is YYYYMMDDnn
	def chk_soa_serial_fmt(ns, ip)
	    serial = soa(ip).serial
	    (serial > 1999000000) && (serial < 2010000000)
	end

	# DESC: recommanded refresh is > 6h
	def chk_soa_refresh_6h(ns, ip)
	    soa(ip).refresh >= 6*3600
	end

	# DESC: coherence between 'retry' and 'refresh'
	def chk_soa_retry_refresh(ns, ip)
	    soa(ip).retry < soa(ip).refresh
	end
	
	# DESC: recommanded retry is > 1h
	def chk_soa_retry_1h(ns, ip)
	    soa(ip).retry >= 3600
	end

	# DESC: recommanded expire is > 7d
	def chk_soa_expire_7d(ns, ip)
	    soa(ip).expire >= 7 * 86400
	end

	# DESC: coherence between 'expire' and 'refresh'
	def chk_soa_expire_refresh(ns, ip)
	    soa(ip).expire >= 7 * soa(ip).refresh
	end

	# DESC: recommanded minimum is > 24h
	def chk_soa_minimum_24h(ns, ip)
	    soa(ip).minimum >= 86400
	end

	# DESC: coherence between 'ttl' and 'minimum'
	def chk_soa_ttl(ns, ip)
	    soa(ip).ttl == soa(ip).minimum
	end

	# DESC: Ensure coherence between SOA and ANY
	def chk_soa_vs_any(ns, ip)
	    soa(ip) == any(ip, NResolv::DNS::Resource::IN::SOA)[0]
	end
    end
end
