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

module CheckGeneric
    ##
    ## Check syntax validity of the domain name
    ##
    class DomainNameSyntax < Test
	ZC_Category = "dns"

	#-- Tests ---------------------------------------------------
	# DESC: A domainname should only contains A-Z a-Z 0-9 '-' '.'
	def chk_dn_alpha
	    @domain_name.to_s =~ /^[A-Za-z0-9\-\.]+$/
	end

	# DESC: A domainname should not countain a double hyphen
	def chk_dn_dbl_hyph
	    ! (@domain_name.to_s =~ /--/)
	end

	# DESC: A domainname should not start or end with an hyphen
	def chk_dn_orp_hyph
	    ! (@domain_name.to_s =~ /(^|\.)-|-(\.|$)/)
	end
    end



    ##
    ## Check basic absurdity with the nameserver IP addresses
    ##
    class ServerAddress < Test
	ZC_Category = "dns"

	#-- Initialization ------------------------------------------
	def initialize(*args)
	    super(*args)
	    @ip        = nil
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
    ## Check for nameserver!
    ##
    class NameServers < Test
	ZC_Category = "dns"

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
