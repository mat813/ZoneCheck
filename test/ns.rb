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
    class NS < Test
	#-- Initialization ------------------------------------------
	def initialize(domainname, ns_list, cm)
	    super(domainname, cm)
	    @ns_list = ns_list
	end
	
	def self.create(param, cm)
	    NS::new(param.domainname, param.ns, cm)
	end

	#-- Shortcuts -----------------------------------------------
	def ns(ip=nil, dom=nil, force=false)
	    dom = domainname if dom.nil?
	    @cm[ip].ns(dom, force)
	end

	def any(ip=nil, resource=nil)
	    @cm[ip].any(domainname, resource)
	end

	def addresses(name, ip=nil)
	    @cm[ip].addresses(name)
	end

	#-- Tests ---------------------------------------------------
	def chk_ns(ns, ip)
	    ! ns(ip).empty?
	end
	
	def chk_ns_auth(ns, ip)
	    ns(ip)
	    ns(ip, nil, true)[0].aa
	end

	def chk_ns_vs_any(ns, ip)
	    any(ip, NResolv::DNS::Resource::IN::NS).unsorted_eq?(ns(ip))
	end

	def chk_ns_sntx(ns, ip)
	    ns(ip).each { |n|
		NResolv::DNS::Name::is_valid_hostname?(n.name)
	    }
	end

	def chk_ns_cname(ns, ip) 
	    ns(ip).each { |n|
		return false if is_cname?(ip, n.name)
	    }
	    true
	end

	def chk_ns_ip(ns, ip)
	    domain = ns.domain
	    @ns_list.each { |name, ips|
		return false unless is_resolvable?(ip, name, domain)
	    }
	    true
	end

	def chk_ns_root_servers(ns, ip)
	    ! ns(ip, NResolv::DNS::Name::Root).nil?
	end

	def chk_ns_root_servers_vs_iana(ns, ip)
	    root = NResolv::DNS::Name::Root
	    ns(ip, root).unsorted_eq?(ns(nil, root))
	end

	def chk_ns_ip_root_servers_vs_iana(ns, ip)
	    [ 'a', 'b', 'c', 'd', 'e', 'f', 'g', 
		'h', 'i', 'j', 'k', 'l', 'm' ].each { |r|
		rootserver = "#{r}.root-servers.net."
		unless addresses(rootserver) == addresses(rootserver, ip)
		    return false
		end
	    }
	    true
	end
    end
end
