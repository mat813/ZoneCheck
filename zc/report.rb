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

require 'config'

module Report
    ##
    ## Exception raised to abort zonecheck
    ##
    class FatalError < StandardError
    end


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
		then
		    @master.ok << result
		else
		    @list << result
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
	    def add_result(result)
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
    end
end
