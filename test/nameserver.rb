# $Id$

require 'framework'

module CheckNameServer
    class ServerAccess < Test
	#-- Initialization ------------------------------------------
	def initialize(*args)
	    super(*args)
	    @ip = { }
	end

	#-- Shortcuts -----------------------------------------------
	def ip(ns)
	    cache_attribute("@ip", ns) {
		@domain_ns.assoc(ns)[1]
	    }
	end

	#-- Tests ---------------------------------------------------
	def chk_private_ip(ns)
	    ip(ns).each { |addr| return false if addr.private? }
	    true
	end
    end
end
