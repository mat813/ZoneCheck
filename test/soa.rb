# $Id$

# 
# AUTHOR : Stephane D'Alu <sdalu@nic.fr>
# CREATED: 2002/08/02 13:58:17
#
# $Revivion$ 
# $Date$
#
# CONTRIBUTORS:
#
#

require 'test/framework'

module CheckNetworkAddress
    ##
    ##
    ##
    class SOA < Test
	#-- Initialization ------------------------------------------
	def initialize(domainname, cm)
	    super(domainname, cm)
	end
	
	def self.create(param, cm)
	    SOA::new(param.domainname, cm)
	end

	#-- Shortcuts -----------------------------------------------
	def soa(ip=nil, force=false)
	    @cm[ip].soa(domainname, force)
	end

	def any(ip=nil, resource=nil)
	    @cm[ip].any(domainname, resource)
	end

	#-- Tests ---------------------------------------------------
	def chk_soa(ns, ip)
	    ! soa(ip).nil?
	end
	
	def chk_soa_auth(ns, ip)
	    soa(ip)
	    soa(ip, true).aa
	end

	def chk_soa_sntx_contact_at(ns, ip)
	    soa(ip).rname.to_s !~ /@/
	end

	def chk_soa_sntx_master(ns, ip)
	    soa(ip).mname.to_s =~ /^[A-Za-z0-9\-\.]+$/
	end

	def chk_soa_ns_cname(ns, ip)
	    ! is_cname?(ip, soa(ip).mname)
	end
	
	def chk_soa_serial_fmt(ns, ip)
	    serial = soa(ip).serial
	    (serial > 1999000000) && (serial < 2010000000)
	end

	def chk_soa_refresh_6h(ns, ip)
	    soa(ip).refresh >= 6*3600
	end

	def chk_soa_retry_refresh(ns, ip)
	    soa(ip).retry < soa(ip).refresh
	end
	
	def chk_soa_retry_1h(ns, ip)
	    soa(ip).retry < 3600
	end

	def chk_soa_expire_7d(ns, ip)
	    soa(ip).expire >= 7 * 86400
	end

	def chk_soa_expire_refresh(ns, ip)
	    soa(ip).expire >= 7 * soa(ip).refresh
	end

	def chk_soa_minimum_24h(ns, ip)
	    soa(ip).minimum >= 86400
	end

	def chk_soa_ttl(ns, ip)
	    soa(ip).ttl == soa(ip).minimum
	end

	def chk_soa_vs_any(ns, ip)
	    any(ip, NResolv::DNS::Resource::IN::SOA)[0] == soa(ip)
	end
    end
end
