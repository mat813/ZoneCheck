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

require 'framework'

module CheckNetworkAddress
    ##
    ## Check domain NS records
    ##
    class NS < Test
	#-- Tests ---------------------------------------------------
	# DESC: NS entries should exists
	def chk_ns(ns, ip)
	    ! ns(ip).empty?
	end
	
	# DESC: NS answers should be authoritative
	def chk_ns_auth(ns, ip)
	    ns(ip, @domain_name)		# request should be done twice
	    ns(ip, @domain_name, true)[0].aa	# so we need to force the cache
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
	    domain = ns.domain
	    ns(ip).each { |n|
		return false unless is_resolvable?(ip, n.name, domain)
	    }
	    true
	end
    end
end
