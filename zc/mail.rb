# $Id$

# 
# CONTACT     : zonecheck@nic.fr
# AUTHOR      : Stephane D'Alu <sdalu@nic.fr>
#
# CREATED     : 2002/09/25 08:58:17
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

require 'socket'
require 'timeout'


##
##
##
class ZCMail
    ##
    ##
    ##
    class ZCMailError < StandardError
    end

    def initialize(mhost, mip, dbgio=nil)
	@myhostname = Socket::gethostname
	@mhost      = mhost
	@mip        = mip
	@mrelay     = nil
	@dbgio      = dbgio
    end

    def open(tout=nil)
	Timeout::timeout(tout) {
	    @mrelay = TCPSocket::new(@mip, 25)
	}
    end

    def fake_info(user, mdest, mfrom)
	@user	= user
	@mdest	= mdest
	@mfrom	= mfrom

	@openrelay_testlist = [ 
	    [ "Test 0",
		"spamtest@#{@mhost}",	"\"nobody@#{@mdest}\""		],
	    [ "Test 1",
		"spamtest@#{@mdest}",	"nobody@#{@mdest}"		],
	    [ "Test 2",
		"spamtest@#{@mfrom}",	"nobody@#{@mdest}"		],
	    [ "Test 3",
		"spamtest@localhost",	"nobody@#{@mdest}"		],
	    [ "Test 4",
		"spamtest",		"nobody@#{@mdest}"		],
	    [ "Test 5",
		"",			"nobody@#{@mdest}"		],
	    [ "Test 6",
		"spamtest@#{@mhost}",	"nobody@#{@mdest}"		],
	    [ "Test 7",
		"spamtest@[#{@mip}]",	"nobody@#{@mdest}"		],
	    [ "Test 8",
		"spamtest@#{@mhost}",	"nobody%#{@mdest}@#{@mhost}"	],
	    [ "Test 9",
		"spamtest@#{@mhost}",	"nobody%#{@mdest}@[#{@mip}]"	],
	    [ "Test 10",
		"spamtest@#{@mhost}",	"\"nobody@#{@mdest}\""		],
	    [ "Test 11",
		"spamtest@#{@mhost}",	"\"nobody%#{@mdest}\""		],
	    [ "Test 12",
		"spamtest@[#{@mip}]",	"\"nobody@#{@mdest}@#{@mhost}\""],
	    [ "Test 13",
		"spamtest@#{@mhost}",	"\"nobody@#{@mdest}\"@[#{@mip}]"],
	    [ "Test 14",
		"spamtest@#{@mhost}",	"nobody@#{@mdest}@[#{@mip}]"	],
	    [ "Test 15",
		"spamtest@[#{@mip}]",	"@#{@mhost}:nobody@#{@mdest}"	],
	    [ "Test 16",
		"spamtest@#{@mhost}",	"@[#{@mip}]:nobody@#{@mdest}"	],
	    [ "Test 17",
		"spamtest@[#{@mip}]",	"#{@mdest}!nobody"		],
	    [ "Test 18",
		"spamtest@#{@mhost}",	"#{@mdest}!nobody@[#{@mip}]"	],
	    [ "test 19",
		"postmaster@#{@mhost}",	"nobody@#{@mdest}"		] ]
    end

    def close
	@mrelay.close
    end

    def cmd(str)
	if str
	    @dbgio << ">> #{str}\n" if @dbgio
	    @mrelay.write("#{str}\r\n") ; @mrelay.flush
	end

	begin
	    desc = ""	
	    while true
		line = @mrelay.readline
		@dbgio << "<< #{line}" if @dbgio
		case line
		when NilClass         then raise ZCMailError, "parsing error"
		when /^(\d{3}) (.*)$/ then return [ $1.to_i, desc << $2 ]
		when /^(\d{3})-(.*)$/ then desc << $2
		else raise ZCMailError, "parsing error"
		end
	    end
	rescue EOFError
	    raise ZCMailError, "Unexpected closing of connection"
	end
	# NOT REACHED
    end

    def banner          ; cmd(nil)					; end
    def helo(host)      ; cmd("HELO #{host.gsub(/\.$/, "")}")		; end
    def vrfy(user)	; cmd("VRFY #{user.gsub(/\.$/, "")}")		; end
    def mail_from(from) ; cmd("MAIL FROM: <#{from.gsub(/\.$/, "")}>")	; end
    def rcpt_to(to)     ; cmd("RCPT TO: <#{to.gsub(/\.$/, "")}>")	; end
    def rset            ; cmd("RSET")					; end
    def quit            ; cmd("QUIT")					; end


    def test_userexists(user, use_vrfy=false)
	if use_vrfy
	    case vrfy(user)[0]
	    when 250, 251, 252 then rset ; return true
	    end
	end
	mail_from("#{@user}@#{@mdest}")
	res = rcpt_to(user)[0] == 250
	rset
	res
    end


    def test_openrelay(count=1)
	tests = [ @openrelay_testlist[1] ]

	tests.each { |name, from, to|
	    if (r = mail_from(from)[0]) == 250
		case rcpt_to(to)[0]
		when 250..259 then return true
		end
	    else
		raise ZCMailError, "Unexpected return code #{r}"
	    end
	    rset
	}
	false
    end
end



#         500 Syntax error, command unrecognized
#            [This may include errors such as command line too long]
#         501 Syntax error in parameters or arguments
#         502 Command not implemented
#         503 Bad sequence of commands
#         504 Command parameter not implemented
#          
#         211 System status, or system help reply
#         214 Help message
#            [Information on how to use the receiver or the meaning of a
#            particular non-standard command; this reply is useful only
#            to the human user]
#          
#         220 <domain> Service ready
#         221 <domain> Service closing transmission channel
#         421 <domain> Service not available,
#             closing transmission channel
#            [This may be a reply to any command if the service knows it
#            must shut down]
#          
#         250 Requested mail action okay, completed
#         251 User not local; will forward to <forward-path>
#         450 Requested mail action not taken: mailbox unavailable
#            [E.g., mailbox busy]
#         550 Requested action not taken: mailbox unavailable
#            [E.g., mailbox not found, no access]
#         451 Requested action aborted: error in processing
#         551 User not local; please try <forward-path>
#         452 Requested action not taken: insufficient system storage
#         552 Requested mail action aborted: exceeded storage allocation
#         553 Requested action not taken: mailbox name not allowed
#            [E.g., mailbox syntax incorrect]
#         354 Start mail input; end with <CRLF>.<CRLF>
#         554 Transaction failed
 
