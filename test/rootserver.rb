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
require 'yaml'

module CheckNetworkAddress
    class RootServer < Test
	with_msgcat 'test/rootserver.%s'

	#-- Initialization ------------------------------------------
	def initialize(*args)
	    super(*args)
	    @cache.create(:rootserver)
	end

	#-- Shortcuts -----------------------------------------------
	def rootserver
	    @cache.use(:rootserver) {
		rootserver = {}

		fname = begin
			    const('rootservers')
			rescue IndexError
			    nil
			end

		if fname
		    fname = const('rootservers').strip
		    fname = "#{ZC_CONFIG_DIR}/#{fname}" unless fname[0] == ?/
		    File::open(fname) { |io|
			data = YAML::load(io) 
			data.each { |k, v|
			    rootserver[NResolv::DNS::Name::create(k)] =
				v.collect { |addr| Address::create(addr) }
			}
		    }
		else
		    ns(nil, NResolv::DNS::Name::Root).each { |rsr| 
			rootserver[rsr.name] = addresses(rsr.name) }
		end
		rootserver
	    }
	end

	#-- Checks --------------------------------------------------
	# DESC: root server list should be available
	def chk_root_servers(ns, ip)
	    ! ns(ip, NResolv::DNS::Name::Root).nil?
	end

	# DESC: root server list should be coherent with ICANN
	def chk_root_servers_ns_vs_icann(ns, ip)
	    (ns(ip, NResolv::DNS::Name::Root).collect { 
		|n| n.name}).unsorted_eql?(rootserver.keys)
	end

	# DESC: root server addresses should be coherent with ICANN
	def chk_root_servers_ip_vs_icann(ns, ip)
	    rootserver.each { |rs, ips|
		return false unless addresses(rs, ip).unsorted_eql?(ips) }
	    true
	end
    end
end
