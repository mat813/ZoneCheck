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
    
#
# WARN: this file is LOADED by publisher
#

#####
#
# TODO:
#  - escape html text
#  - clean up html
#

module Publisher
    ##
    ##
    ##
    class HTML < Template
	Mime		= "text/html"

	def self.jscript
	    '<SCRIPT type="text/javascript">' + yield + '</SCRIPT>'
	end

	def self.nscript
	    '<NOSCRIPT>' + yield + '</NOSCRIPT>'
	end

	class Progress
	    def initialize(publisher)
		@publisher = publisher
		@o         = publisher.output
	    end
	    
	    def start(count)
		title = if @publisher.rflag.quiet
			then ""
			else "<H2>" + $mc.get("title_progress") + "</H2>"
			end
		if @publisher.rflag.counter
		    @o.puts HTML.jscript {
			title_progress = $mc.get("title_progress")
			pgr_progress   = $mc.get("pgr_progress")
			pgr_test       = $mc.get("pgr_test")
			pgr_speed      = $mc.get("pgr_speed")
			pgr_time       = $mc.get("pgr_time")

			str = if @publisher.rflag.quiet
			      then "zc_pgr_locale(null, \"#{pgr_progress}\", \"#{pgr_test}\", \"#{pgr_speed}\", \"#{pgr_time}\");"
			      else "zc_pgr_locale(\"#{title_progress}\", \"#{pgr_progress}\", \"#{pgr_test}\", \"#{pgr_speed}\", \"#{pgr_time}\");"
			      end
			str += "zc_pgr_start(#{count});"
			str
		    }
		    @o.puts HTML.nscript { title + "<UL>" }
		end
		if @publisher.rflag.testdesc
		    @o.puts title
		    @o.puts "<UL class=\"zc_test\">"
		end
	    end
	    
	    def done(desc)
	    end
	    
	    def failed(desc)
	    end
	    
	    def finish
		if @publisher.rflag.counter
		    @o.puts HTML.jscript { "zc_pgr_finish();" }
		    @o.puts HTML.nscript { "</UL>" }
		end

		if @publisher.rflag.testdesc
		    @o.puts "</UL>"
		end
	    end
	    
	    def process(desc, ns, ip)
		xtra = if    ip then " (IP=#{ip})"
		       elsif ns then " (NS=#{ns})"
		       else          ""
		       end

		if @publisher.rflag.counter
		    @o.puts HTML.jscript { 
			"zc_pgr_process(\"#{desc} #{xtra}\")" }
		    @o.puts HTML.nscript {
			"<LI>" +
			    $mc.get("testing_fmt") % [ "#{desc}#{xtra}" ] +
			    "</LI>"
		    }
		end

		if @publisher.rflag.testdesc
		    @o.puts "<LI>"
		    @o.printf $mc.get("testing_fmt"), "#{desc}#{xtra}"
		    @o.puts "</LI>"
		end
		@o.flush
	    end
	end


	#------------------------------------------------------------

	def initialize(rflag, ostream=$stdout)
	    super(rflag, ostream)
	    @progress	= Progress::new(self)
	end


	#------------------------------------------------------------

	def begin
	    # XXX: javascript only if counter
	    @o.print <<"EOT"
<HTML>
  <HEAD>
    <META http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
    <TITLE>ZoneCheck results</TITLE>
    <LINK rel="stylesheet" href="/zc/zc.css" type="text/css">
    <SCRIPT language="JavaScript" src="/zc/progress.js" type="text/javascript">
    </SCRIPT>
  </HEAD>
  <BODY>
EOT
@o.flush
	end

	def end
	    @o.print <<"EOT"
  </BODY>
</HTML>
EOT
	end
	

	def setup(domain_name)
	    if ! @rflag.quiet
		@o.puts "<H1>ZoneCheck: #{domain_name}</H1>"
	    end
	end

	#------------------------------------------------------------


	def intro(domain)
	    tbl_beg   = '<TABLE rules="rows" class="zc_domain">'
	    tbl_zone  = '<TR class="zc_zone"><TD>%s</TD><TD colspan="4">%s</TD></TR>'
	    tbl_ns    = '<TR class="%s"><TD>%s</TD><TD>%s</TD><TD>%s</TD></TR>'
	    tbl_end   = '</TABLE>'


	    unless rflag.quiet
		title = $mc.get("title_zoneinfo")
		@o.puts "<H2>#{title}</H2>"
	    end


	    @o.puts "<DIV class=\"zc_zinfo\">"
	    @o.puts tbl_beg
	    @o.puts tbl_zone % [ $mc.get("ns_zone").capitalize, domain.name ]
	    domain.ns.each_index { |i| 
		ns_ip = domain.ns[i]
		if i == 0
		    css  = "zc_ns_prim"
		    desc = $mc.get("ns_primary").capitalize
		else
		    css  = "zc_ns_sec"
		    desc = $mc.get("ns_secondary").capitalize
		end

		@o.puts tbl_ns % [ css, desc, ns_ip[0], ns_ip[1].join(", ") ]
	    }
	    @o.puts tbl_end
	    @o.puts "</DIV>"
	    @o.flush
	end

	def diagnostic1(domainname, 
		i_count, i_unexp, w_count, w_unexp, f_count, f_unexp,
		res, severity)

	    i_tag = @rflag.tagonly ? "i" : $mc.get("i_tag")
	    w_tag = @rflag.tagonly ? "w" : $mc.get("w_tag")
	    f_tag = @rflag.tagonly ? "f" : $mc.get("f_tag")
	    
	    i_tag = i_tag.upcase if i_unexp
	    w_tag = w_tag.upcase if w_unexp
	    f_tag = f_tag.upcase if f_unexp

	    summary = "%1s%03d&nbsp;%1s%03d&nbsp;%1s%03d" % [ 
		i_tag, i_count, 
		w_tag, w_count, 
		f_tag, f_count ]


	    if @rflag.tagonly
		msg = res.testname
	    else
		msg = res.desc.msg
	    end

	    @o.puts "<DIV class=\"zc_diag1\">"
	    @o.puts "<TABLE width=\"100%\">"
	    @o.puts "<TR class=\"zc_title\"><TD width=\"100%\">#{domainname}</TD><TD>#{summary}</TD></TR>"
	    @o.puts "<TR><TD colspan=\"2\">#{severity}: #{res.tag}</TD></TR>"
	    @o.puts "<TR><TD colspan=\"2\">#{msg}</TD></TR>"
	    @o.puts "</TABLE>"
	    @o.puts "</DIV>"
	end


	def diagnostic(severity, testname, desc, lst)
	    msg, xpl_lst = nil, nil
	    if @rflag.tagonly
		if desc.is_error?
		    msg = "#{severity}[Unexpected]: #{testname}"
		else
		    msg = "#{severity}: #{testname}"
		end
	    else
		msg = desc.msg
	    end

	    if @rflag.explain && !@rflag.tagonly
		xpl_lst = xpl_split(desc.xpl)
	    end
	    

	    @o.puts "<DIV class=\"zc_diag\">"
	    @o.puts "<DIV class=\"zc_title\">#{msg}</DIV>"

	    if xpl_lst
		@o.puts "<UL class=\"zc_ref\">"
		xpl_lst.each { |h, t|
		    h =~ /^\[(\w+)\]:\s*/
		    tag = $mc.get("xpltag_#{$1}")
		    @o.puts "<LI>"
		    @o.puts "<SPAN class=\"zc_ref\">#{tag}: #{$'}</SPAN>"
		    @o.puts "<BR>"
		    @o.puts t.join(" ")
		    @o.puts "</LI>"
		}
		puts "</UL>"
	    end

	    if ! lst.empty?
		@o.puts "<UL>"
		lst.each { |elt| @o.puts "  <LI>#{elt}</LI>" }
		@o.puts "</UL>"
	    end

	    @o.puts "<BR>"
	    @o.puts "</DIV>"
	end
	    

	def status(domainname, i_count, w_count, f_count)
	    unless @rflag.quiet
		title = $mc.get("title_status")
		@o.puts "<H2>#{title}</H2>"
	    end
	    @o.print "<DIV class=\"zc_status\">", 
		super(domainname, i_count, w_count, f_count), "</DIV>"
	    @o.puts "<BR>"
	    if @rflag.quiet
		@o.puts "<HR width=\"60%\">"
		@o.puts "<BR>"
	    end
	end



	#------------------------------------------------------------

	def h1(h)
	    @o.puts "<H2>#{h.capitalize}</H2>"
	end

	def h2(h)
	    @o.puts "<H3 class=\"warning\">---- #{h.capitalize} ----</H3>"
	end
    end
end