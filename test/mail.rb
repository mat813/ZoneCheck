# ZCTEST 1.0
# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/09/25 19:14:21
#
# COPYRIGHT: AFNIC (c) 2003
# CONTACT  : zonecheck@nic.fr
# LICENSE  : GPL v2.0
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
	with_msgcat "test/mail.%s"

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

	def mhosttest(mdom, mhost)
	    # Mailhost and IP 
	    mip   = addresses(mhost, bestresolverip(mhost))[0]
#	    puts "DOM=#{mdom}   HOST=#{mhost}   IP=#{mip}"
#	    puts "DEST=#{@fake_dest}  FROM=#{@fake_from}  USER=#{@fake_user}"

	    raise "No host servicing mail for domain #{mdom}" if mip.nil?

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
	
	
	def openrelay(mdom, mhost)
	    mhosttest(mdom, mhost) { |mrelay| return mrelay.test_openrelay }
	end

	def testuser(user, mdom, mhost)
#	    puts "USER = #{user}"
	    mhosttest(mdom, mhost) { 
		|mrelay| return mrelay.test_userexists(user, true)
	    }
	end

	#-- Checks --------------------------------------------------
	# DESC: Check that the best MX for hostmaster is not an openrelay
	def chk_mail_openrelay_hostmaster
	    rname = soa(bestresolverip).rname
	    mdom  = rname.domain
	    mhost = bestmx(mdom) || mdom
	    return true unless openrelay(mdom, mhost)
	    { "mailhost"   => mhost,
	      "hostmaster" => "#{rname[0]}@#{mdom}",
	      "from_host"  => @fake_from,
	      "to_host"    => @fake_dest }
	end

	# DESC: Check that the best MX for the domain is not an openrelay
	def chk_mail_openrelay_domain
	    mdom  = @domain.name
	    mhost = bestmx(mdom) || mdom
	    return true unless openrelay(mdom, mhost)
	    { "mailhost"   => mhost,
	      "from_host"  => @fake_from,
	      "to_host"    => @fake_dest }
	end

	# DESC: Check that hostmaster address is valid
	def chk_mail_hostmaster
	    rname = soa(bestresolverip).rname
	    mdom  = rname.domain
	    mhost = bestmx(mdom) || mdom
	    user  = "#{rname[0]}@#{mdom}"
	    return true if testuser(user, mdom, mhost)
	    { "hostmaster" => user }
	end
	
	# DESC: Check that postmaster address is valid
	def chk_mail_postmaster
	    mdom  = @domain.name
	    mhost = bestmx(mdom) || mdom
	    user  = "postmaster@#{mdom}"
	    return true if testuser(user, mdom, mhost)
	    { "postmaster" => user }
	end
    end
end
