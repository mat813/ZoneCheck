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
    class ByHost < Template
	def finish
	    if @rflag.one
		rtest, severity = nil,          nil
		rtest, severity = @fatal.one,   @fatal.severity   unless rtest
		rtest, severity = @warning.one, @warning.severity unless rtest

		@publish.diagnostic1(@domain.name, 
				     @info.count,    @info.has_error?,
				     @warning.count, @warning.has_error?,
				     @fatal.count,   @fatal.has_error?,
				     rtest, severity)
	    else
		if !(@info.empty? && @warning.empty? && @fatal.empty?)
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
		    gentag = $mc.get("w_generic")
		    display(byhost[gentag], gentag)
		    byhost.delete(gentag)

		    # Print remaining 'host'
		    byhost.keys.sort.each { |tag|
			display(byhost[tag], tag) }
		end

		@publish.status(@domain.name, 
				@info.count, @warning.count, @fatal.count)
	    end
	end

	attr_reader :full_list
	attr_reader :ok, :fatal, :warning, :info

	private
	def display(list, title)
	    return if list.nil? || list.empty?

	    if !@rflag.tagonly && !@rflag.quiet
		@publish.diag_section(title)
	    end
 
	    list.each { |res, severity|
		@publish.diagnostic(severity, res.testname, res.desc, []) }
	end
    end
end
