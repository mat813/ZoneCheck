# ZCTEST 1.0
# $Id$

# 
# CONTACT     : zonecheck@nic.fr
# AUTHOR      : Stephane D'Alu <sdalu@nic.fr>
#
# CREATED     : 2002/08/02 13:58:17
# REVISION    : $Revision$ 
# DATE        : $Date$
#
# CONTRIBUTORS: (see also CREDITS file)
#
#
# LICENSE     : GPL v2 (or MIT/X11-like after agreement)
# COPYRIGHT   : AFNIC (c) 2003
#
# This file is part of ZoneCheck.
#
# ZoneCheck is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# ZoneCheck is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ZoneCheck; if not, write to the Free Software Foundation,
# Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#

require 'framework'

module CheckNetworkAddress
    ##
    ## Check domain NS records
    ##
    class AXFR < Test
	with_msgcat "test/axfr.%s"

	#-- Checks --------------------------------------------------
	# DESC: Zone transfer is possible
	def chk_axfr(ns, ip)
	    true
	end

	# DESC: Zone transfer is not empty
	def chk_axfr_empty(ns, ip)
	    true
	end

	# DESC: Zone transfer containts only valid labels
	def chk_axfr_valid_labels(ns, ip)
	    true
	end
    end
end
