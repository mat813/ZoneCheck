# ZCTEST 1.0
# $Id$

# 
# AUTHOR : Stephane D'Alu <sdalu@nic.fr>
# CREATED: 2002/08/02 13:58:17
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
	#-- Tests ---------------------------------------------------
	# DESC:
	def chk_ns_reverse(ns, ip)
	    ip_name = NResolv::DNS::Name::create(ip)
	    ! (( rec(ip) && ptr(ip, ip_name).empty?) ||
	       (!rec(ip) && ptr(nil,ip_name).empty?))
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


	def tst_recursive_servers(ns, ip)
	    "true"
	end
    end
end
