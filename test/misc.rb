# ZCTEST 1.0
# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/08/02 13:58:17
#
# COPYRIGHT: AFNIC (c) 2003
# CONTACT  : zonecheck@nic.fr
# LICENSE  : GPL v2.0
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS:
#
#

#####
#
# TODO:
#   - move these functions into another file
#

require 'framework'

module CheckNetworkAddress
    ##
    ##
    ##
    class Misc < Test
	with_msgcat "test/misc.%s"

	#-- Checks --------------------------------------------------
	# DESC:
	def chk_ns_reverse(ns, ip)
	    ip_name	= NResolv::DNS::Name::create(ip)
	    srv		= rec(ip) ? ip : nil
	    ! ptr(srv, ip_name).empty?
	end


	# DESC: Ensure coherence between given (param) primary and SOA
	def chk_given_nsprim_vs_soa(ns, ip)
	    soa(ip).mname == @domain.ns[0][0]
	end
	   
	# DESC: Ensure coherence between given (param) nameservers and NS
	def chk_given_ns_vs_ns(ns, ip)
	    nslist_from_ns    = ns(ip).collect{ |n| n.name}
	    nslist_from_param = @domain.ns.collect { |n, ips| n }

	    nslist_from_ns.unsorted_eql?(nslist_from_param)
	end


	# DESC: Ensure that a server claiming to be recursive really is it
	def chk_correct_recursive_flag(ns, ip)
	    return true unless rec(ip)

	    revdom = case ip
		     when Address::IPv4 then "in-addr.arpa."
		     when Address::IPv6 then "ip6.arpa."
		     else raise "Not an IP address"
		     end

	    soa(ip, @domain.name.domain)			&&
		soa(ip, NResolv::DNS::Name::create(revdom))
	end

	#-- Tests ---------------------------------------------------
	# 
	def tst_recursive_server(ns, ip)
	    rec(ip) ? "true" : "false"
	end
    end
end
