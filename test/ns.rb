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
    class NS < Test
	#-- Initialization ------------------------------------------
	def initialize(domainname, ns_list, cm)
	    super(domainname, cm)
	    @ns_list = ns_list
	end
	
	def self.create(param, cm)
	    NS::new(param.domainname, param.ns, cm)
	end

	#-- Tests ---------------------------------------------------
	# DESC: NS entries should exists
	def chk_ns(ns, ip)
	    ! ns(ip).empty?
	end
	
	# DESC: NS answers should be authoritative
	def chk_ns_auth(ns, ip)
	    ns(ip, @domainname)			# request should be done twice
	    ns(ip, @domainname, true)[0].aa	# so we need to force the cache
	end

	# DESC: Ensure coherence between NS and ANY
	def chk_ns_vs_any(ns, ip)
	    any(ip, NResolv::DNS::Resource::IN::NS).unsorted_eql?(ns(ip))
	end

	# DESC: NS record should have a valid hostname syntaxe
	def chk_ns_sntx(ns, ip)
	    ns(ip).each { |n|
		NResolv::DNS::Name::is_valid_hostname?(n.name)
	    }
	end

	# DESC: NS record should not point to CNAME alias
	def chk_ns_cname(ns, ip) 
	    ns(ip).each { |n|
		return false if is_cname?(ip, n.name)
	    }
	    true
	end
    end
end
