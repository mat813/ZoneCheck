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
    class MX < Test
	#-- Initialization ------------------------------------------
	def initialize(domainname, domain_ns, cm)
	    super(domainname, cm)
	    @domain_ns = domain_ns
	end
	
	def self.create(param, cm)
	    MX::new(param.domainname, param.ns, cm)
	end

	#-- Shortcuts -----------------------------------------------
	def mx(ip=nil, dom=nil, force=false)
	    dom = domainname if dom.nil?
	    @cm[ip].mx(dom, force)
	end

	def any(ip=nil, resource=nil)
	    @cm[ip].any(domainname, resource)
	end

	def addresses(name, ip=nil)
	    @cm[ip].addresses(name)
	end

	#-- Tests ---------------------------------------------------
	def chk_mx(ns, ip)
	    ! mx(ip).empty?
	end
	
	def chk_mx_auth(ns, ip)
	    mx(ip)
	    mx(ip, nil, true)[0].aa
	end

	def chk_mx_vs_any(ns, ip)
	    any(ip, NResolv::DNS::Resource::IN::MX).unsorted_eq?(mx(ip))
	end

	def chk_mx_sntx(ns, ip)
	    mx(ip).each { |m|
		NResolv::DNS::Name::is_valid_hostname?(m.exchange)
	    }
	end

	def chk_mx_cname(ns, ip) 
	    mx(ip).each { |m|
		return false if is_cname?(ip, m.exchange)
	    }
	    true
	end

	def chk_mx_ip(ns, ip)
	    domain = ns.domain
	    mx(ip).each { |n| ns_name, = n
		if ns_name.in_domain?(domain) && addresses(ns_name, ip).empty?
		    return false
		end

	    }
	    true
	end
    end
end
