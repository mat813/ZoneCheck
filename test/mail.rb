# $Id$

# 
# AUTHOR : Stephane D'Alu <sdalu@nic.fr>
# CREATED: 2002/09/25 19:14:21
#
# $Revivion$ 
# $Date$
#
# CONTRIBUTORS:
#
#

require 'framework'
require 'mail'

module CheckExtra
    ##
    ## Check domain NS records
    ##
    class Mail < Test
	def initialize(*args)
	    super(*args)
	end

	#-- Shortcuts -----------------------------------------------
	def bestmx(name)
	    pref, exch = 65536, nil
	    mx(bestresolver(name), name).each { |m|
		if m.preference < pref
		    pref, exch = m.preference, m.exchange
		end
	    }
	    exch
	end

	#-- Tests ---------------------------------------------------
	# DESC: Check that the MX
	def chk_mail_openrelay_domain
	    # Mailhost to use to contact the person responsible for the domain
	    mdom  = soa(bestresolver).rname.domain
	    mhost = bestmx(mdom)
	    mip   = addresses(mhost, bestresolver(mhost))[0]
	    puts "DOM=#{mdom}   HOST=#{mhost}   IP=#{mip}"

	    mrelay = nil
	    begin
		mrelay = ZCMail::new(mdom, mip.to_s)
		mrelay.test_openrelay
	    ensure
		mrelay.close if mrelay
	    end
	end

#	def chk_mail_openrelay_hostmaster
#	    
#	end
	
	def chk_mail_hostmaster
	end
	
#	def chk_mail_postmaster
#	end
    end
end
