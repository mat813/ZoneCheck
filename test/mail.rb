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
	ZC_Category = "mail"

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

	def mhosttest(mdom)
	    # Mailhost and IP 
	    mhost = bestmx(mdom)
	    mip   = addresses(mhost, bestresolver(mhost))[0]

#	    puts "DOM=#{mdom}   HOST=#{mhost}   IP=#{mip}"
	    # Execute test on mailhost
	    mrelay = nil
	    begin
		mrelay = ZCMail::new(mdom, mip.to_s)
		mrelay.banner
		yield mrelay
	    ensure
		mrelay.quit
		mrelay.close if mrelay
	    end
	end
	
	
	def openrelay(mdom)
	    mhosttest(mdom) { |mrelay| return mrelay.test_openrelay }
	end

	def testuser(user, mdom)
	    mhosttest(mdom) { |mrelay| return mrelay.test_userexists(user) }
	end

	#-- Tests ---------------------------------------------------
	# DESC: Check that the best MX for hostmaster is not an openrelay
	def chk_mail_openrelay_hostmaster
	    ! openrelay(soa(bestresolver).rname.domain)
	end

	# DESC: Check that the best MX for the domain is not an openrelay
	def chk_mail_openrelay_domain
	    ! openrelay(@domain_name)
	end

	# DESC: Check that hostmaster address is valid
	def chk_mail_hostmaster
	    rname = soa(bestresolver).rname
	    testuser(rname[0], rname.domain)
	end
	
	# DESC: Check that postmaster address is valid
	def chk_mail_postmaster
	    testuser("postmaster", @domain_name)
	end
    end
end
