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



    ##
    ## Straight interpretation of messages.
    ##
    class Straight
	def tagonly_supported? ; true ; end
	def one_supported?     ; true ; end
	

	##
	##
	##
	class Processor # --> ABSTRACT <--
	    def initialize(master, rflag, publish)
		@master		= master
		@rflag		= rflag
		@publish	= publish
		@list_failed	= []
		@list_ok	= master.list_ok
	    end

	    def empty? ; @list_failed.empty? ; end
	    def count  ; @list_failed.length ; end
	    def one    ; @list_failed.first  ; end
	    def list   ; @list_failed        ; end

	    def add_result(result)
		if result.ok?
		then @list_ok     << result
		else @list_failed << result
		end
	    end
	    
	    def has_error?
		@list_failed.each { |res| return true if res.desc.is_error? }
		false
	    end

	    def display
		return if @list_failed.empty?

		if !@rflag.tagonly && !@rflag.quiet
		    @publish.diag_section(title)
		end
		
		nlist = @list_failed.dup
		while ! nlist.empty?
		    # Get test result
		    res		= nlist.shift
		    
		    # Initialize 
		    whos	= [ res.tag ]
		    desc	= res.desc.clone
		    testname	= res.testname
		    
		    # Look for similare test results
		    nlist.delete_if { |a|
			if (a.testname == res.testname) && (a.desc == res.desc)
			    whos << a.tag
			end
		    }
		    
		    # Publish diagnostic
		    @publish.diagnostic(severity, testname, desc, whos)
		end
	    end
	end



	##
	## Fatal/Warning/Info results 
	##
	class Fatal   < Processor
	    def add_result(result)
		super(result)
		raise FatalError unless result.ok?
	    end
	    def severity ; Config::Fatal        ; end
	    def title    ; $mc.get("w_fatal")   ; end
	end

	class Warning < Processor
	    def severity ; Config::Warning      ; end
	    def title    ; $mc.get("w_warning") ; end
	end

	class Info    < Processor
	    def severity ; Config::Info         ; end
	    def title    ; $mc.get("w_info")    ; end
	end



	attr_reader :list_ok

	def initialize(domain, rflag, publish)
	    @domain	= domain
	    @rflag	= rflag
	    @publish	= publish
	    @list_ok	= []
	    @fatal	= Fatal::new(self, rflag, publish)
	    @warning	= Warning::new(self, rflag, publish)
	    @info	= Info::new(self, rflag, publish)
	end


	    def display(list)
		return if list.empty?
		title = "ok"

		if !@rflag.tagonly && !@rflag.quiet
		    @publish.diag_section(title)
		end
		
		nlist = list.dup
		while ! nlist.empty?
		    # Get test result
		    res		= nlist.shift
		    
		    # Initialize 
		    whos	= [ res.tag ]
		    desc	= res.desc.clone
		    testname	= res.testname
		    
		    # Look for similare test results
		    nlist.delete_if { |a|
			if (a.testname == res.testname) && (a.desc == res.desc)
			    whos << a.tag
			end
		    }
		    
		    # Publish diagnostic
		    @publish.diagnostic(nil, testname, desc, whos)
		end
	    end

	def finish
	    if @rflag.one
		rtest = nil
		rtest, severity = @fatal.one,   @fatal.severity   unless rtest
		rtest, severity = @warning.one, @warning.severity unless rtest
#		rtest, severity = @info.one,    @info.severity    unless rtest

		@publish.diagnostic1(@domain.name, 
				     @info.count,    @info.has_error?,
				     @warning.count, @warning.has_error?,
				     @fatal.count,   @fatal.has_error?,
				     rtest, severity)
		return
	    end


	    if !(@info.empty? && @warning.empty? && @fatal.empty?)
		@publish.diag_start() unless @rflag.quiet

		display(@list_ok) if @rflag.reportok
		@info.display
		@warning.display
		@fatal.display
	    end

	    @publish.status(@domain.name, 
			    @info.count, @warning.count, @fatal.count)
	end

	attr_reader :fatal, :warning, :info
    end
end
