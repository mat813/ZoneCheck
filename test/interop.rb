# ZCTEST 1.0
# $Id$

# 
# CONTACT     : zonecheck@nic.fr
# AUTHOR      : Stephane D'Alu <sdalu@nic.fr>
#
# CREATED     : 2003/09/23 15:33:12
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
    ## Check nameserver interoperability
    ## 
    class Interop < Test
	with_msgcat 'test/interop.%s'

	#-- Shortcuts -----------------------------------------------
	def dflt_exception(ip, name=@domain.name)
	    a_exception = nil
	    begin
		a(ip, name)
	    rescue NResolv::NResolvError => a_exception
	    end
	    a_exception
	end

	def validate_record(ns, ip) 
	    begin
		yield [ns, ip]
	    rescue NResolv::DNS::ReplyError => e
		case e.code
		when NResolv::DNS::RCode::NOTIMP
		else
		    return false if e.class != dflt_exception(ip).class
		end
	    rescue NResolv::NResolvError => e
		return false if e.class != dflt_exception(ip).class
	    end
	    true
	end



	#-- Checks --------------------------------------------------
	# DESC: 
	def chk_cname(ns, ip)
	    true
	end

	# DESC: 
	def chk_aaaa(ns, ip)
	    validate_record(ns, ip) { aaaa(ip, @domain.name) }
	end
    end
end
