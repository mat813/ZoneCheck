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

require 'config'

module Report
    ##
    ## Exception raised to abort zonecheck
    ##
    class FatalError < StandardError
    end


    ##
    ## Template for creating report
    ##
    class Template
	attr_reader :full_list, :ok
	attr_reader :fatal, :warning, :info

	def tagonly_supported? ; true ; end
	def one_supported?     ; true ; end
	

	##
	##
	##
	class Processor # --> ABSTRACT <--
	    def initialize(master)
		@master	= master
		@list	= []
	    end

	    def empty? ; @list.empty? ; end
	    def count  ; @list.length ; end
	    def one    ; @list.first  ; end
	    def list   ; @list        ; end

	    def <<(result)
		if result.ok?
		then @master.ok << result
		else @list << result
		     @master.full_list << [ result, severity ]
		end
	    end
	    
	    def has_error?
		@list.each { |res| return true if res.desc.is_error? }
		false
	    end
	end


	##
	## Fatal/Warning/Info results 
	##
	class Fatal	< Processor
	    def <<(result)
		super(result)
		raise FatalError unless result.ok?
	    end
	    def severity   ; Config::Fatal        ; end
	end

	class Warning	< Processor
	    def severity   ; Config::Warning      ; end
	end

	class Info	< Processor
	    def severity   ; Config::Info         ; end
	end

	class Ok	< Processor
	    def <<(result) 
		@list << result
		@master.full_list << [ result, severity ]
	    end
	    def severity   ; nil                  ; end
	    def has_error? ; false                ; end
	end



	def initialize(domain, rflag, publish)
	    @domain	= domain
	    @rflag	= rflag
	    @publish	= publish
	    @full_list  = []
	    @ok		= Ok::new(self)
	    @fatal	= Fatal::new(self)
	    @warning	= Warning::new(self)
	    @info	= Info::new(self)
	end

	def finish
	    if @rflag.one
	    then display_one
	    else display_std
	    end
	end

	protected
	def display_one
	    rtest, severity = nil,          nil
	    rtest, severity = @fatal.one,   @fatal.severity   unless rtest
	    rtest, severity = @warning.one, @warning.severity unless rtest

	    @publish.diagnostic1(@domain.name, 
				 @info.count,    @info.has_error?,
				 @warning.count, @warning.has_error?,
				 @fatal.count,   @fatal.has_error?,
				 rtest, severity)
	end

	def display_std
	    raise 'abstract method'
	end
    end
end
