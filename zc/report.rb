# $Id$

module Diagnostic
    class FatalError < StandardError
    end

    ##
    ## Consolidation of reported messages
    ##
    class Consolidation
	class Processor # ABSTRACT
	    attr_reader :count

	    def initialize(consolidator)
		@consolidator = consolidator
		@count        = 0
	    end

	    def add_answer(answer)
		@consolidator.add(answer, self)
	    end
	end
	
	class Fatal < Processor
	    def add_answer(answer)
		super(answer)
		raise FatalError unless answer.ok?
	    end
	end
	
	class Warning < Processor
	end
	
	class Info < Processor
	end


	def initialize
	    @root    = {}
	    @answers = []

	    @fatal   = Fatal::new(@data)
	    @warning = Warning::new(@data)
	    @info    = Info::new(@data)
	end

	def add(answer, type)
	    @answers << answer 
	    @root[answer.testname] = {} unless @data.key?(answer.testname)
	    test = (@data[answer.testname] ||= {})
	    kind = (test[answer.class]     ||= {})
	    ns   = (kind[answer.ns]        ||= {})
	    ns[answer.ip] = true
	end

	def finish
		
	end

	attr_reader :fatal, :warning, :info
    end


    ##
    ## Straight interpretation of messages.
    ##
    class Straight
	class Processor # ABSTRACT
	    def initialize(formatter)
		@formatter = formatter
		@list      = []
	    end

	    def empty?
		@list.empty?
	    end

	    def count
		@list.length
	    end

	    def add_answer(answer)
		if !answer.ok?
		    @list << answer
		end
	    end
	    
	    def display
		nlist = @list.dup

		while ! nlist.empty?
		    tags = [ ]
		    
		    ans = nlist.shift
		    @formatter.msg1(ans.msg) 
		    @formatter.explanation(ans.explanation)
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
	
	class Fatal < Processor
	    def add_answer(answer)
		super(answer)
		raise FatalError unless answer.ok?
	    end
	end
	
	class Warning < Processor
	end
	
	class Info < Processor
	end


	def initialize(formatter)
	    @formatter = formatter
	    @fatal     = Fatal::new(formatter)
	    @warning   = Warning::new(formatter)
	    @info      = Info::new(formatter)
	end

	def finish
	    if ! @info.empty?
		@formatter.heading($mc.get("info"))
		@info.display
	    end
	    if ! @warning.empty?
		@formatter.heading($mc.get("warning"))
		@warning.display
	    end
	    if ! @fatal.empty?
		@formatter.heading($mc.get("empty"))
		@fatal.display
	    end


	    warnings = @warning.count
	    fatals   = @fatal.count
	    
	    if fatals == 0
		tag = (warnings > 0) ? "res_succeed_but" : "res_succeed"
	    else
		if @param.stop_on_fatal
		    tag = "res_failed_on"
		else
		    tag = (warnings > 0) ? "res_failed_and" : "res_failed"
		end
	    end
	    printf $mc.get(tag), warnings
	end

	attr_reader :fatal, :warning, :info
    end
end
