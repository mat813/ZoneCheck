# $Id$

module Diagnostic
    class Output
    end

    class Fatal < Output
	def addmsg(msg)
	    printf $mc.get("fatal"), msg
	    return true
	end
    end
    
    class Warning < Output
	def initialize
	    @@count = 0
	    @@fatal = false
	end
	def addmsg(msg)
	    printf $mc.get("warning"), msg
	    return @@fatal
	end
	def fatal=(fatal)
	    @@fatal = fatal
	end
	def count
	    @@count
	end
    end

    class Info < Output
	def initialize
	    @@count = 0
	end
	def addmsg(msg)
	    @@count += 1
	    printf $mc.get("info"), msg
	    return false
	end
	def count
	    @@count
	end
    end
end
