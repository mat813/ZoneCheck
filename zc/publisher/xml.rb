# $Id$

# 
# CONTACT     : 
# AUTHOR      : Stephane D'Alu <sdalu@sdalu.com>
#
# CREATED     : 2003/06/26 22:32:43
# REVISION    : $Revision$ 
# DATE        : $Date$
#
# CONTRIBUTORS: (see also CREDITS file)
#
#
# LICENSE     : GPL v2 (or MIT/X11-like after agreement)
# COPYRIGHT   : Stephane D'Alu (c) 2003
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
    
require 'config'

module Publisher
    ##
    ##
    ##
    class XML < Template
	Mime		= "text/xml"

	##
	## Class for displaying progression information about
	## the tests being performed.
	##
	class Progress
	    # Initialization
	    def initialize(publisher)
		@publisher	= publisher
		@o		= publisher.output
		@l10n_testing	= $mc.get("word:testing").capitalize
	    end
	    
	    # Start progression
	    def start(count)
		# Counter
		if @publisher.rflag.counter || @publisher.rflag.testdesc
		    @o.puts "<testlist>"
		end
	    end
	    
	    # Finished on success
	    def done(desc)
	    end
	    
	    # Finished on failure
	    def failed(desc)
	    end
	    
	    # Finish (finalize) output
	    def finish
		# Counter
		if @publisher.rflag.counter || @publisher.rflag.testdesc
		    @o.puts "</testlist>"
		end
	    end
	    
	    # Process an item
	    def process(desc, ns, ip)
		# Don't bother, if there is no output asked
		return unless (@publisher.rflag.counter ||
			       @publisher.rflag.testdesc)

		@o.puts "  <testid></testid>"
		xtra = if    ip then " (IP=#{ip})"
		       elsif ns then " (NS=#{ns})"
		       else          ""
		       end
		msg = "#{desc}#{xtra}"
	    end
	end


	#------------------------------------------------------------

	def initialize(rflag, info, ostream=$stdout)
	    super(rflag, info, ostream)
	    @progress		= Progress::new(self)
	    @publish_path	= ZC_HTML_PATH.gsub(/\/+$/, "")
	end

	def error(text)
	    @o.puts "<BLOCKQUOTE class=\"zc-error\">#{text}</BLOCKQUOTE>"
	end

	#------------------------------------------------------------

	def begin
	    # XXX: javascript only if counter
	    @o.print <<"EOT"
<?xml version="1.0" encoding='UTF-8'?>
<!DOCTYPE zonecheck SYSTEM "zc.dtd">

<zonecheck>
EOT
	end

	def end
@o.print <<"EOT"
  <zcstamp> release=\"#{$zc_name}-#{$zc_version.gsub(/</,'&lt;').gsub(/>/,'&gt;')}\" date=\"#{Time::now}\">
  </zcstamp>
</zonecheck>
EOT
	end
	

	def setup(domain_name)
	end

	#------------------------------------------------------------


	def intro(domain)
	    return unless @rflag.intro

	    @o.puts "  <intro>"
	    @o.puts "    <zone>#{domain.name}</zone>"
	    domain.ns.each_index { |i| 
		ns_ip = domain.ns[i]
		if i == 0 
		then @o.puts "    <nameserver type=\"primary\">"
		else @o.puts "    <nameserver type=\"secondary\">"
		end
		@o.puts "      <hostname>#{ns_ip[0]}</hostname>"
		ns_ip[1].each { |ip|
		    type = case ip
			   when Address::IPv4 then "ipv4"
			   when Address::IPv6 then "ipv6"
			   else raise "Unknown address type"
			   end
		    @o.puts "      <address type=\"#{type}\">#{ip}</address>"
		}
		@o.puts "    </nameserver>"
	    }
	    @o.puts "  </intro>"
	end

	def diag_start()
	end

	def diag_section(title)
	end

	def diagnostic1(domainname, 
		i_count, i_unexp, w_count, w_unexp, f_count, f_unexp,
		res, severity)

	    i_tag = @rflag.tagonly ? Config::Info    : $mc.get("word:info_id")
	    w_tag = @rflag.tagonly ? Config::Warning : $mc.get("word:warning_id")
	    f_tag = @rflag.tagonly ? Config::Fatal   : $mc.get("word:fatal_id")
	    
	    i_tag = i_tag.upcase if i_unexp
	    w_tag = w_tag.upcase if w_unexp
	    f_tag = f_tag.upcase if f_unexp

	    summary = "%1s%03d&nbsp;%1s%03d&nbsp;%1s%03d" % [ 
		i_tag, i_count, 
		w_tag, w_count, 
		f_tag, f_count ]


	    @o.puts "<DIV class=\"zc-diag1\">"
	    @o.puts "<TABLE width=\"100%\">"
	    @o.puts "<TR class=\"zc-title\"><TD width=\"100%\">#{domainname}</TD><TD>#{summary}</TD></TR>"
	    if res.nil?
		l10n_perfect = $mc.get("word:perfect").capitalize
		@o.puts "<TR><TD colspan=\"2\"><B>#{l10n_perfect}</B></TD></TR>"
		@o.puts "<TR><TD colspan=\"2\">&nbsp;</TD></TR>"

	    else
		msg = if @rflag.tagonly
		      then res.testname
		      else res.desc.msg
		      end
		@o.puts "<TR><TD colspan=\"2\">#{severity}: #{res.tag}</TD></TR>"
		@o.puts "<TR><TD colspan=\"2\">#{msg}</TD></TR>"
	    end

	    @o.puts "</TABLE>"
	    @o.puts "</DIV>"
	end


	def diagnostic(severity, testname, desc, lst)
	    msg, xpl_lst = nil, nil

	    @o.puts "<diagnostic>"
	    @o.puts "  <testid>#{testname}</testid>"

	    # Severity
	    @o.puts "  <severity type=\"#{Config.severity2tag(severity)}\"/>"

	    # Testname
	    if @rflag.testname
		@o.puts "  <testname>#{$mc.get("#{testname}_testname")}"
	    end

	    # Message
	    if severity.nil?
		msg     = $mc.get("#{testname}_ok")
		msgtype = "passed"
	    else
		msg     = desc.msg
		msgtype = desc.is_error? ? "exception" : "failed"
	    end
	    @o.puts "  <message type=\"#{msgtype}\">#{msg}</message>"
		
	    if !severity.nil?
		# Details
		if @rflag.details && desc.dtl
		    @o.puts "  <details>#{desc.dtl}</details>"
		end

		# Explanation
		if @rflag.explain && !@rflag.tagonly
		    xpl_lst = xpl_split(desc.xpl)
		end

		if xpl_lst
		    xpl_lst.each { |t, h, b|
			@o.puts "  <explanation>"
			@o.puts "    <reference type=\"#{t}\">" +
			    h.gsub(/<URL:([^>]+)>/, '\1') + "</reference>"
			@o.puts "    <content>"
			b.each { |l| @o.puts l.gsub(/<URL:([^>]+)>/, '\1') }
			@o.puts "    </content>"
			@o.puts "  </explanation>"
		    }
		end
	    end

	    # Elements
	    lst.each { |elt| @o.puts "  <element>#{elt}</element>" }

	    @o.puts "</diagnostic>"
	end
	    

	def status(domainname, i_count, w_count, f_count)
	    @o.puts "<status info=\"#{i_count}\" warning=\"#{w_count}\" fatal=\"#{f_count}\">"
	    @o.puts "</status>"
	end
    end
end
