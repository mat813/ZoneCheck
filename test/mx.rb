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
    ## Check domain MX record
    ##
    class MX < Test
	#-- Tests ---------------------------------------------------
	# DESC: MX entries should exists
	def chk_mx(ns, ip)
	    ! mx(ip).empty?
	end
	
	# DESC: MX answers should be authoritative
	def chk_mx_auth(ns, ip)
	    mx(ip, @domain_name)		# request should be done twice
	    mx(ip, @domain_name, true)[0].aa	# so we need to force the cache
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
	    domain = ns.domain
	    mx(ip).each { |m|
		return false unless is_resolvable?(ip, m.exchange, domain)
	    }
	    true
	end
    end
end
