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
    class RootServer < Test
	#-- Tests ---------------------------------------------------
	# DESC: root server list should be available
	def chk_root_servers(ns, ip)
	    ! ns(ip, NResolv::DNS::Name::Root).nil?
	end

	# DESC: root server list should be coherent with IANA
	def chk_root_servers_ns_vs_iana(ns, ip)
	    root = NResolv::DNS::Name::Root
	    ns(ip, root).unsorted_eql?(ns(nil, root))
	end

	# DESC: root server addresses should be coherent with IANA
	def chk_root_servers_ip_vs_iana(ns, ip)
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