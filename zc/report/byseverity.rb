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
    ## Sorting by severity
    ##
    class BySeverity < Template
	def display_std
	    if !(@info.empty? && @warning.empty? && @fatal.empty?)
		@publish.diag_start() unless @rflag.quiet
		    
		catlist = []
		catlist << @ok   if @rflag.reportok
		catlist << @info << @warning << @fatal
		catlist.each { |cat|
		    display(cat.list, cat.severity) }
	    end

	    @publish.status(@domain.name, 
			    @info.count, @warning.count, @fatal.count)
	end

	private
	def display(list, severity)
	    return if list.nil? || list.empty?

	    if !@rflag.tagonly && !@rflag.quiet
		severity_tag	= Config.severity2tag(severity)
		l10n_severity	= $mc.get("w_#{severity_tag}")
		@publish.diag_section(l10n_severity)
	    end
		
	    nlist = list.dup
	    while ! nlist.empty?
		# Get test result
		res		= nlist.shift
		
		# Initialize 
		whos		= [ res.tag ]
		desc		= res.desc.clone
		testname	= res.testname
		
		# Look for similare test results
		nlist.delete_if { |a|
		    whos << a.tag if ((a.testname == res.testname) && 
				      (a.desc == res.desc))
		}
		
		# Publish diagnostic
		@publish.diagnostic(severity, testname, desc, whos)
	    end
	end
    end
end
