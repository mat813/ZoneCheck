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

module Diagnostic
    class FatalError < StandardError
    end


    ##
    ## Straight interpretation of messages.
    ##
    class Straight
	class Processor # ABSTRACT
	    def initialize(diag)
		@param     = diag.param
		@formatter = diag.param.formatter
		@explain   = diag.param.explanation
		@list      = []
	    end

	    def empty?
		@list.empty?
	    end

	    def count
		@list.length
	    end

	    def add_answer(answer)
		@list << answer unless answer.ok?
	    end
	    
	    def display
		nlist = @list.dup

		while ! nlist.empty?
		    tags = [ ]
		    
		    ans = nlist.shift
		    @formatter.msg1(ans.msg) 
		    if @param.explanation && !@param.tagonly
			@formatter.explanation(ans.explanation) 
		    end
		    tags << ans.tag

		    nlist.delete_if { |a|
			if (a.msg == ans.msg && 
			    a.explanation == ans.explanation)
			    tags << a.tag
			end
		    }
		    
		    @formatter.list(tags)
		    @formatter.vskip
		end
	    end
	end
	
	class Fatal   < Processor
	    def add_answer(answer)
		super(answer)
		raise FatalError unless answer.ok?
	    end
	end
	
	class Warning < Processor
	end
	
	class Info    < Processor
	end


	def initialize(param)
	    @param     = param
	    @formatter = param.formatter
	    @fatal     = Fatal::new(self)
	    @warning   = Warning::new(self)
	    @info      = Info::new(self)
	end

	def finish
	    @formatter.h1("Test results")
	    if ! @info.empty?
		@formatter.h2($mc.get("info"))
		@info.display
	    end
	    if ! @warning.empty?
		@formatter.h2($mc.get("warning"))
		@warning.display
	    end
	    if ! @fatal.empty?
		@formatter.h2($mc.get("fatal"))
		@fatal.display
	    end


	    warnings = @warning.count
	    fatals   = @fatal.count
	    
	    if fatals == 0
		tag = (warnings > 0) ? "res_succeed_but" : "res_succeed"
	    else
		if ! @param.stop_on_fatal # XXX: bad $
		    tag = "res_failed_on"
		else
		    tag = (warnings > 0) ? "res_failed_and" : "res_failed"
		end
	    end
	    printf $mc.get(tag), warnings
	end

	attr_reader :fatal, :warning, :info
	attr_reader :param
    end
end
