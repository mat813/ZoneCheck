# $Id$

# 
# AUTHOR : Stephane D'Alu <sdalu@nic.fr>
# CREATED: 2002/08/02 13:58:17
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS:
#
#

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
	    def initialize(rflag, publish)
		@rflag		= rflag
		@publish	= publish
		@list		= []
	    end

	    def empty? ; @list.empty? ; end

	    def count  ; @list.length ; end

	    def add_result(result)
		@list << result unless result.ok?
	    end
	    
	    def severity
		self.class.to_s =~ /([^:]+)$/
		$1
	    end

	    def one 
		@list.nil? ? nil : @list.first
	    end

	    def has_error?
		@list.each { |res| return true if res.desc.is_error? }
		false
	    end

	    def display(title)
		nlist = @list.dup

		if !@rflag.tagonly
		    @publish.diag_section(title)
		end

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
	## Fatal results 
	##
	class Fatal   < Processor
	    def add_result(result)
		super(result)
		raise FatalError unless result.ok?
	    end
	end



	##
	## Warning results
	##
	class Warning < Processor
	end
	


	##
	## Informational results
	##
	class Info    < Processor
	end




	def initialize(domain, rflag, publish)
	    @domain	= domain
	    @rflag	= rflag
	    @publish	= publish
	    @fatal	= Fatal::new(rflag, publish)
	    @warning	= Warning::new(rflag, publish)
	    @info	= Info::new(rflag, publish)
	end

	def finish
	    if @rflag.one
		rtest = nil
		rtest, severity = @fatal.one,   @fatal.severity   unless rtest
		rtest, severity = @warning.one, @warning.severity unless rtest
		rtest, severity = @info.one,    @info.severity    unless rtest

		@publish.diagnostic1(@domain.name, 
				     @info.count,    @info.has_error?,
				     @warning.count, @warning.has_error?,
				     @fatal.count,   @fatal.has_error?,
				     rtest, severity)
		return
	    end



	    if ! @rflag.quiet
		@publish.h1($mc.get("title_testres"))
	    end
	    
	    @info.display($mc.get("w_info"))       if ! @info.empty?
	    @warning.display($mc.get("w_warning")) if ! @warning.empty?
	    @fatal.display($mc.get("w_fatal"))     if ! @fatal.empty?

	    @publish.status(@domain.name, 
			      @info.count, @warning.count, @fatal.count)
	end

	attr_reader :fatal, :warning, :info
	attr_reader :param
    end
end
