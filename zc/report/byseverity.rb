# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/08/02 13:58:17
#
# COPYRIGHT: AFNIC (c) 2003
# LICENSE  : GPL v2.0 (or MIT/X11-like after agreement)
# CONTACT  : zonecheck@nic.fr
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS: (see also CREDITS file)
#
#

require 'report'
require 'config'

module Report
    ##
    ## Straight interpretation of messages.
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
