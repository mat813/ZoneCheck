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

	    def initialize(data)
		@data = data
		@count = 0
	    end

	    def add_answer(answer)
		@data[[answer.testname, answer.ns, answer.ip]] = [self, answer]
	    end
	end
	
	class FatalAnswer < Processor
	    def add_answer(answer)
		super(answer, answer.explanation)
		raise FatalError unless answer.ok?
	    end
	end
	
	class WarningAnswer < Processor
	    def add_answer(answer)
		super(answer, answer.explanation)
	    end
	end
	
	class InfoAnswer < Processor
	    def add_answer(answer)
		super(answer)
	    end
	end


	def initialize
	    @data = { }

	    @fatal   = FatalAnswer::new(@data)
	    @warning = WarningAnswer::new(@data)
	    @info    = InfoAnswer::new(@data)
	end

	attr_reader :fatal, :warning, :info
    end


    ##
    ## Straight interpretation of messages.
    ##
    class Straight
	class Processor # ABSTRACT
	    attr_reader :count

	    def initialize(formatter)
		@formatter = formatter
		@count     = 0
	    end

	    def add_answer(answer, formatter_method=nil)
		if !answer.ok?
		    @count += 1
		    formatter_method.call(answer) if formatter_method
		end
	    end
	end
	
	class Fatal < Processor
	    def add_answer(answer) 
		super(answer, @formatter.method(:fatal))
		raise FatalError unless answer.ok?
		true
	    end
	end
	
	class Warning < Processor
	    def add_answer(answer)
		super(answer, @formatter.method(:warning))
	    end
	end
	
	class Info < Processor
	    def add_answer(answer)
		super(answer, @formatter.method(:info))
	    end
	end


	def initialize(formatter)
	    @fatal   = Fatal::new(formatter)
	    @warning = Warning::new(formatter)
	    @info    = Info::new(formatter)
	end

	attr_reader :fatal, :warning, :info
    end
end
