# $Id$

require 'test/framework'

module CheckGeneric
    ##
    ##
    ##
    class DomainNameSyntax < Test
	#-- Initialization ------------------------------------------
	def initialize(domainname, cm)
	    super(domainname, cm)
	end

	def self.create(param, cm)
	    return DomainNameSyntax::new(param.domainname, cm)
	end

	#-- Tests ---------------------------------------------------
	# DESC: A domainname should only contains A-Z a-Z 0-9 '-' '.'
	def chk_dn_alpha
	    domainname.to_s =~ /^[A-Za-z0-9\-\.]+$/
	end

	# DESC: A domainname shoul not countain a double hyphen
	def chk_dn_dbl_hyph
	    ! (domainname.to_s =~ /--/)
	end

	# DESC: A domainname should not start or end with an hyphen
	def chk_dn_orp_hyph
	    ! (domainname.to_s =~ /(^|\.)-|-(\.|$)/)
	end
    end



    ##
    ##
    ##
    class ServerAddress < Test
	#-- Initialization ------------------------------------------
	def initialize(domainname, ns, cm)
	    super(domainname, cm)
	    @domain_ns = ns
	    @ip        = nil
	end

	def self.create(param, cm)
	    return ServerAddress::new(param.domainname, param.ns, cm)
	end

	#-- Shortcuts -----------------------------------------------
	def ip
	    cache_attribute("@ip") {
		ip = @domain_ns.collect { |ns| ns[1] }
		ip.flatten!
		ip
	    }
	end

	#-- Tests ---------------------------------------------------
	# DESC: Addresses should be distincts
	def chk_distinct_ip
	    ip == ip.uniq
	end

	# DESC: Addresses should avoid to belong to the same network
	def chk_same_net
	    prefix_list = ip.collect { |i| 
		case i                               # decide of subnet size:
		when Address::IPv4 then i.prefix(28) # /28 for IPv4
		when Address::IPv6 then i.prefix(64) # /64 for IPv6
		end
	    }
	    prefix_list == prefix_list.uniq
	end
    end



    ##
    ##
    ##
    class NameServers < Test
	#-- Initialization ------------------------------------------
	def initialize(domainname, ns, cm)
	    super(domainname, cm)
	    @domain_ns = ns
	end

	def self.create(param, cm)
	    return NameServers::new(param.domainname, param.ns, cm)
	end

	#-- Tests ---------------------------------------------------
	# DESC: A domain should have a nameserver!
	def chk_one_ns
	    @domain_ns.length >= 1
	end

	# DESC: A domain should have at least 2 nameservers
	def chk_several_ns
	    @domain_ns.length >= 2
	end
    end
end
