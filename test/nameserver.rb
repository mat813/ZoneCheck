# ZCTEST 1.0
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

require 'framework'

module CheckNameServer
    ##
    ## Check accessibility of nameserver
    ## 
    ## - these tests are performed without contacting the nameserver
    ##   (see modules CheckNetworkAddress for that)
    ##
    class ServerAccess < Test
	with_msgcat "test/nameserver.%s"

	#-- Initialization ------------------------------------------
	def initialize(*args)
	    super(*args)

	    cache_attr :ip
	end

	#-- Shortcuts -----------------------------------------------
	def ip(ns)
	    cache_use(:ip, ns) {
		@domain.ns.assoc(ns)[1]
	    }
	end

	#-- Checks --------------------------------------------------
	# DESC: Nameserver IP addresses should be public!
	def chk_private_ip(ns)
	    ip(ns).each { |addr| return false if addr.private? }
	    true
	end
    end
end
