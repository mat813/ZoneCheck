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

require 'report'
require 'config'

module Report
    ##
    ## Sorting by 'host'
    ##
    class ByHost < Template
	def display_std
	    if (!(@info.empty? && @warning.empty? && @fatal.empty?) || 
		@rflag.reportok)
		@publish.diag_start() unless @rflag.quiet

		# Sorting by 'host'
		byhost = {}
		full_list.each { |elt| res, severity = elt
		    next if severity.nil? && !@rflag.reportok
		    tag = res.tag
		    byhost[tag] = [] unless byhost.has_key?(tag)
		    byhost[tag] << elt
		}

		# Print 'generic' first
		gentag = $mc.get('w_generic')	# XXX: not nice
		display(byhost[gentag], gentag)
		byhost.delete(gentag)
		
		# Print remaining 'host'
		byhost.keys.sort.each { |tag|
		    display(byhost[tag], tag) }
	    end
	    
	    @publish.status(@domain.name, 
			    @info.count, @warning.count, @fatal.count)
	end

	private
	def display(list, title)
	    return if list.nil? || list.empty?

	    if !@rflag.tagonly && !@rflag.quiet
		@publish.diag_section(title)
	    end
 
	    list.each { |res, severity|
		@publish.diagnostic(severity, 
				    res.testname, res.desc, [ res.tag ]) }
	end
    end
end
