# ZCTEST 1.0
# $Id$

# 
# AUTHOR : Stephane D'Alu <sdalu@nic.fr>
# CREATED: 2002/09/25 19:14:21
#
# $Revision$ 
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
	#-- Initialisation ------------------------------------------
	def initialize(*args)
	    super(*args)
	    @fake_dest = const("fake_mail_dest")
	    @fake_from = const("fake_mail_from")
	    @fake_user = const("fake_mail_user")
	    @fake_host = const("fake_mail_host")
	end

	#-- Shortcuts -----------------------------------------------
	def bestmx(name)
	    pref, exch = 65536, nil
	    mx(bestresolverip(name), name).each { |m|
		if m.preference < pref
		    pref, exch = m.preference, m.exchange
		end
	    }
	    exch
	end

	def mhosttest(mdom)
	    # Mailhost and IP 
	    mhost = bestmx(mdom)
	    mip   = addresses(mhost, bestresolverip(mhost))[0]

#	    puts "DOM=#{mdom}   HOST=#{mhost}   IP=#{mip}"
#	    puts "DEST=#{@fake_dest}  FROM=#{@fake_from}  USER=#{@fake_user}"
	    # Execute test on mailhost
	    mrelay = nil
	    begin
		mrelay = ZCMail::new(mdom, mip.to_s)
		mrelay.banner
		mrelay.helo(@fake_host)
		mrelay.fake_info(@fake_user, @fake_dest, @fake_from)
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
#	    puts "USER = #{user}"
	    mhosttest(mdom) { |mrelay| return mrelay.test_userexists(user) }
	end

	#-- Tests ---------------------------------------------------
	# DESC: Check that the best MX for hostmaster is not an openrelay
	def chk_mail_openrelay_hostmaster
	    ! openrelay(soa(bestresolverip).rname.domain)
	end

	# DESC: Check that the best MX for the domain is not an openrelay
	def chk_mail_openrelay_domain
	    ! openrelay(@domain.name)
	end

	# DESC: Check that hostmaster address is valid
	def chk_mail_hostmaster
	    rname = soa(bestresolverip).rname
	    testuser("#{rname[0]}@#{rname.domain}", rname.domain)
	end
	
	# DESC: Check that postmaster address is valid
	def chk_mail_postmaster
	    testuser("postmaster@#{@domain.name}", @domain.name)
	end
    end
end
