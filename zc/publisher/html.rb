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
    
#####
#
# TODO:
#  - escape html text
#  - clean up html
#  - only load javascript when needed
#

module Publisher
    ##
    ##
    ##
    class HTML < Template
	Mime		= "text/html"

	# Shortcut for enclosing javascript
	def self.jscript
	    '<SCRIPT type="text/javascript">' + yield + '</SCRIPT>'
	end

	# Shortcut for enclosing noscript
	def self.nscript
	    '<NOSCRIPT>' + yield + '</NOSCRIPT>'
	end


	##
	## Class for displaying progression information about
	## the tests being performed.
	##
	class Progress
	    # Initialization
	    def initialize(publisher)
		@publisher = publisher
		@o         = publisher.output
	    end
	    
	    # Start progression
	    def start(count)
		title = if @publisher.rflag.quiet
			then ""
			else "<H2>" + $mc.get("title_progress") + "</H2>"
			end

		# Counter
		if @publisher.rflag.counter
		    @o.puts HTML.jscript {
			pgr_quiet_param  = @publisher.rflag.quiet ? "true" \
			                                          : "false"
			pgr_locale_param = [ 
			    $mc.get("title_progress"),
			    $mc.get("pgr_progress"),
			    $mc.get("pgr_test"),
			    $mc.get("pgr_speed"),
			    $mc.get("pgr_time") ]
			pgr_start_param  = count

			str  = 'zc_pgr_quiet(%s);' % pgr_quiet_param
			str += 'zc_pgr_locale("%s", "%s", "%s", "%s", "%s");' % pgr_locale_param
			str += 'zc_pgr_start(%d);' % pgr_start_param
			str
		    }
		    @o.puts HTML.nscript { title }
		end

		# Test description
		if @publisher.rflag.testdesc
		    @o.puts title
		    @o.puts "<UL class=\"zc_test\">"
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
		if @publisher.rflag.counter
		    @o.puts HTML.jscript { "zc_pgr_finish();" }
		    @o.puts HTML.nscript { "</UL>" }
		end

		# Test description
		if @publisher.rflag.testdesc
		    @o.puts "</UL>"
		end
	    end
	    
	    # Process an item
	    def process(desc, ns, ip)
		xtra = if    ip then " (IP=#{ip})"
		       elsif ns then " (NS=#{ns})"
		       else          ""
		       end

		# Counter
		if @publisher.rflag.counter
		    @o.puts HTML.jscript { 
			"zc_pgr_process(\"#{desc} #{xtra}\")" }
		    @o.puts HTML.nscript {
			"<LI>" +
			    $mc.get("testing_fmt") % [ "#{desc}#{xtra}" ] +
			    "</LI>"
		    }
		end

		# Test description
		if @publisher.rflag.testdesc
		    @o.puts "<LI>"
		    @o.printf $mc.get("testing_fmt"), "#{desc}#{xtra}"
		    @o.puts "</LI>"
		end

		# Flush
		@o.flush
	    end
	end


	#------------------------------------------------------------

	def initialize(rflag, ostream=$stdout)
	    super(rflag, ostream)
	    @progress	= Progress::new(self)
	end


	def error(text)
	    @o.puts "<BLOCKQUOTE class=\"zc_error\">#{text}</BLOCKQUOTE>"
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
    <STYLE>
        UL.zc_ref LI { 
            list-style: url(/zc/img/ref.png) disc
        }

        UL.zc_element LI { 
            list-style: url(/zc/img/element.png) disc
        }

        UL.zc_details LI { 
            list-style: url(/zc/img/details.png) disc
        }
    </STYLE>
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

	    l10n_zone = $mc.get("ns_zone").capitalize

	    @o.puts "<DIV class=\"zc_zinfo\">"
	    @o.puts tbl_beg
	    @o.puts tbl_zone % [ "<IMG src=\"/zc/img/zone.png\" alt=\"#{l10n_zone}\">", domain.name ]
	    domain.ns.each_index { |i| 
		ns_ip = domain.ns[i]
		if i == 0
		    css  = "zc_ns_prim"
		    desc = $mc.get("ns_primary").capitalize
		    logo = "primary"
		else
		    css  = "zc_ns_sec"
		    desc = $mc.get("ns_secondary").capitalize
		    logo = "secondary"
		end

		desc = "<IMG src=\"/zc/img/#{logo}.png\" alt= \"#{desc}\">"

		@o.puts tbl_ns % [ css, desc, ns_ip[0], ns_ip[1].join(", ") ]
	    }
	    @o.puts tbl_end
	    @o.puts "</DIV>"
	    @o.flush
	end

	def diag_section(title)
	    h2(title)
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

	    logo = case severity
		   when "Info"    then "info"
		   when "Warning" then "warning"
		   when "Fatal"   then "fatal"
		   else raise RuntimError, "XXX: unknown severity: #{severity}"
		   end

	    @o.puts "<DIV class=\"zc_diag\">"
	    @o.puts "<DIV class=\"zc_title\"><IMG src=\"/zc/img/#{logo}.png\" alt=\"\"> #{msg}</DIV>"

	    if @rflag.details && desc.dtl
		@o.puts "<UL class=\"zc_details\">"
		@o.puts "<LI>"
		@o.puts desc.dtl
		@o.puts "</LI>"
		@o.puts "</UL>"
	    end

	    if xpl_lst
		@o.puts "<UL class=\"zc_ref\">"
		xpl_lst.each { |t, h, b|
		    l10n_tag = $mc.get("xpltag_#{t}")
		    b.each { |l| l.gsub!(/<URL:([^>]+)>/, '<A href="\1">\1</A>') }
		    @o.puts "<LI>"
		    @o.puts "<SPAN class=\"zc_ref\">#{l10n_tag}: #{h}</SPAN>"
		    @o.puts "<BR>"
		    @o.puts b.join(" ")
		    @o.puts "</LI>"
		}
		@o.puts "</UL>"
	    end

	    if ! lst.empty?
		@o.puts "<UL class=\"zc_element\">"
		lst.each { |elt| @o.puts "  <LI>#{elt}</LI>" }
		@o.puts "</UL>"
	    end

	    @o.puts "<BR>"
	    @o.puts "</DIV>"
	end
	    

	def status(domainname, i_count, w_count, f_count)
	    unless @rflag.quiet
		l10n_title = $mc.get("title_status")
		@o.puts "<H2>#{l10n_title}</H2>"
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
	    @o.puts "<H3 class=\"zc_warning\">---- #{h.capitalize} ----</H3>"
	end
    end
end
