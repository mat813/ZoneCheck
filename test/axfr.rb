# ZCTEST 1.0
# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/08/02 13:58:17
#
# COPYRIGHT: AFNIC (c) 2003
# CONTACT  : zonecheck@nic.fr
# LICENSE  : GPL v2.0 (or MIT/X11-like after agreement)
#
# $Revision$ 
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
    class AXFR < Test
	with_msgcat "test/axfr.%s"

	#-- Checks --------------------------------------------------
	# DESC: Zone transfert is possible
	def chk_axfr(ns, ip)
	    true
	end

	# DESC: Zone transfert is not empty
	def chk_axfr_empty(ns, ip)
	    true
	end

	# DESC: Zone transfert containts only valid labels
	def chk_axfr_valid_labels(ns, ip)
	    true
	end
    end
end
