# ZCTEST 1.0
# $Id$

# 
# CONTACT     : zonecheck@nic.fr
# AUTHOR      : Stephane D'Alu <sdalu@nic.fr>
#
# CREATED     : 2002/09/25 19:14:21
# REVISION    : $Revision$ 
# DATE        : $Date$
#
# CONTRIBUTORS: (see also CREDITS file)
#
#
# LICENSE     : GPL v2 (or MIT/X11-like after agreement)
# COPYRIGHT   : AFNIC (c) 2003
#
# This file is part of ZoneCheck.
#
# ZoneCheck is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# ZoneCheck is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ZoneCheck; if not, write to the Free Software Foundation,
# Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
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
		if mrelay
		    mrelay.quit
		    mrelay.close
		end
	    end
	end
	
	
	def openrelay(mdom, mhost)
	    mhosttest(mdom, mhost) { |mrelay| return mrelay.test_openrelay }
	end

	def testuser(user, mdom, mhost)
	    mhosttest(mdom, mhost) { 
		|mrelay| return mrelay.test_userexists(user)
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
	      "hostmaster" => "#{rname[0].data}@#{mdom}",
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
	def chk_mail_delivery_hostmaster
	    rname = soa(bestresolverip).rname
	    mdom  = rname.domain
	    user  = "#{rname[0].data}@#{mdom}"

	    mxlist = mx(bestresolverip(mdom), mdom).sort { |a,b|
		a.preference <=> b.preference }

	    if mxlist.empty?
		return true if testuser(user, mdom, mdom)
	    else
		mxlist.each { |m|
		    begin
			return true if testuser(user, mdom, m.exchange)
			break
		    rescue TimeoutError
		    end
		}
	    end
	    { "hostmaster" => user }
	end
	
	# DESC: check for MX or A
	def chk_mail_mx_or_addr
	    ip = bestresolverip
	    !mx(ip).empty? || !addresses(@domain.name, ip).empty?
	end

	# DESC: Check that postmaster address is valid
	def chk_mail_delivery_postmaster
	    mdom  = @domain.name
	    user  = "postmaster@#{mdom}"

	    mxlist = mx(bestresolverip(mdom), mdom).sort { |a,b|
		a.preference <=> b.preference }

	    if mxlist.empty?
		return true if testuser(user, mdom, mdom)
	    else
		mxlist.each { |m|
		    begin
			return true if testuser(user, mdom, m.exchange)
			break
		    rescue TimeoutError
		    end
		}
	    end
	    { "postmaster" => user }
	end

	# DESC:
	def chk_mail_hostmaster_mx_cname
	    rname = soa(bestresolverip).rname
	    mdom  = rname.domain
	    mhost = bestmx(mdom)
	    return true if mhost.nil?	# No MX
	    ! is_cname?(mhost) 
	end

	#-- Tests ---------------------------------------------------
	# 
	def tst_mail_delivery
	    ip = bestresolverip
	    if    !mx(ip).empty?			then "MX"
	    elsif !addresses(@domain.name, ip).empty?	then "A"
	    else					     "nodelivery"
	    end
	end
    end
end
