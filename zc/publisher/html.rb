# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/08/02 13:58:17
#
# COPYRIGHT: AFNIC (c) 2003
# CONTACT  : zonecheck@nic.fr
# LICENSE  : GPL v2.0 (or MIT/X11-like after agreement)
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS: (see also CREDITS file)
#
#
    
#####
#
# TODO:
#  - escape html text
#  - clean up html
#  - only load javascript when needed
#

require 'config'

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
		@publisher	= publisher
		@o		= publisher.output
		@l10n_testing	= $mc.get("w_testing").capitalize
	    end
	    
	    # Start progression
	    def start(count)
		title = if @publisher.rflag.quiet
			then ""
			else "<H2 id=\"t_progress\">" + 
				$mc.get("title_progress") + "</H2>"
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
			    $mc.get("pgr_time"),
			    $mc.get("pgr_na")]
			pgr_start_param  = count

			str  = 'zc_pgr_setlocale("%s", "%s", "%s", "%s", "%s", "%s");' % pgr_locale_param
			str += 'zc_pgr_setquiet(%s);' % pgr_quiet_param
			str += 'zc_pgr_start(%d);'    % pgr_start_param
			str
		    }
		    @o.puts HTML.nscript { title }
		end

		# Test description
		if @publisher.rflag.testdesc
		    @o.puts title
		    @o.puts "<UL class=\"zc-test\">"
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
		# Don't bother, if there is no output asked
		return unless (@publisher.rflag.counter ||
			       @publisher.rflag.testdesc)

		xtra = if    ip then " (IP=#{ip})"
		       elsif ns then " (NS=#{ns})"
		       else          ""
		       end
		msg = CGI::escapeHTML("#{desc}#{xtra}")

		# Counter
		if @publisher.rflag.counter
		    @o.puts HTML.jscript {
			"zc_pgr_process(\"#{msg}\")" }
		    @o.puts HTML.nscript {
			"<LI>#{@l10n_testing}: #{msg}</LI>" }
		end

		# Test description
		if @publisher.rflag.testdesc
		    @o.puts "<LI>#{@l10n_testing}: #{msg}</LI>"
		end

		# Flush
		@o.flush
	    end
	end


	#------------------------------------------------------------

	def initialize(rflag, ostream=$stdout)
	    super(rflag, ostream)
	    @progress		= Progress::new(self)
	    @publish_path	= ZC_HTML_PATH.gsub(/\/+$/, "")
	end

	def error(text)
	    @o.puts "<BLOCKQUOTE class=\"zc-error\">#{text}</BLOCKQUOTE>"
	end

	#------------------------------------------------------------

	def begin
	    l10n_form        = $mc.get("w_form").capitalize
	    l10n_batch_form  = l10n_form+": "+$mc.get("t_batch").capitalize
	    l10n_single_form = l10n_form+": "+$mc.get("t_single").capitalize

	    # XXX: javascript only if counter
	    @o.print <<"EOT"
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<HTML>
  <HEAD>
    <META http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <TITLE>ZoneCheck results</TITLE>

    <!-- Navigation -->
    <LINK rel="start" href="#{@publish_path}/"             type="text/html">
    <LINK rel="up"    href="#{@publish_path}/#{$mc.lang}/" type="text/html">
    <LINK rel="bookmark" title="#{l10n_batch_form}"
	  href="#{@publish_path}/#{$mc.lang}/batch.html"   type="text/html">
    <LINK rel="bookmark" title="#{l10n_single_form}"
	  href="#{@publish_path}/#{$mc.lang}/"             type="text/html">

    <LINK rel="alternate" title="Original AFNIC version"
	  href="http://zonecheck.afnic.fr/v2/"             type="text/html">

    <LINK rel="section" title="#{$mc.get("title_zoneinfo")}"
          href="#t_zoneinfo"                               type="text/html">
    <LINK rel="section" title="#{$mc.get("title_progress")}"
          href="#t_progress"                               type="text/html">
    <LINK rel="section" title="#{$mc.get("title_testres")}"
          href="#t_testres"                                type="text/html">
    <LINK rel="section" title="#{$mc.get("title_status")}"
          href="#t_status"                                 type="text/html">


    <!-- Favicon -->
    <LINK rel="icon"       href="#{@publish_path}/img/zc-fav.png" type="image/png">


    <!-- Style -->
    <LINK rel="stylesheet" href="#{@publish_path}/style/zc.css"   type="text/css">

    <STYLE type="text/css">
        UL.zc-ref LI { 
            list-style: url(#{@publish_path}/img/ref.png)     disc }

        UL.zc-element LI { 
            list-style: url(#{@publish_path}/img/element.png) disc }

        UL.zc-details LI { 
            list-style: url(#{@publish_path}/img/details.png) disc }
    </STYLE>

    <!-- Javascript -->
    <SCRIPT type="text/javascript">
      zc_publish_path = "#{@publish_path}"
    </SCRIPT>
    <SCRIPT src="#{@publish_path}/js/progress.js"  type="text/javascript">
    </SCRIPT>
    <SCRIPT src="#{@publish_path}/js/popupmenu.js" type="text/javascript">
    </SCRIPT>
  </HEAD>
  <BODY>
    <IMG class="zc-logo" alt="ZoneCheck" src="#{@publish_path}/img/logo.png">
EOT
@o.flush
	end

	def end
	    @o.puts HTML.jscript { 
		"zc_contextmenu_setlocale(\"#{$mc.get("w_details")}\", \"#{$mc.get("w_references")}\", \"#{$mc.get("w_elements")}\");\n" +
		    "zc_contextmenu_start();" }
	    @o.print <<"EOT"

    <HR>
    <SPAN style="float: right;">
      <a href="http://jigsaw.w3.org/css-validator/check/referer">
	<img style="border:0;width:88px;height:31px"
	     src="http://jigsaw.w3.org/css-validator/images/vcss" 
	     alt="Valid CSS!"></a>
      <a href="http://validator.w3.org/check/referer">
	<img style="border:0;width:88px;height:31px"
	     src="http://www.w3.org/Icons/valid-html401"
	     alt="Valid HTML 4.01!"></a>
    </SPAN>
Release: #{$zc_version} <BR>
Last modified: #{Time::now}

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
	    return unless @rflag.intro

	    tbl_beg   = '<TABLE rules="rows" class="zc-domain">'
	    tbl_zone  = '<TR class="zc-zone"><TD>%s</TD><TD colspan="4">%s</TD></TR>'
	    tbl_ns    = '<TR class="%s"><TD>%s</TD><TD>%s</TD><TD>%s</TD></TR>'
	    tbl_end   = '</TABLE>'


	    unless @rflag.quiet
		title = $mc.get("title_zoneinfo")
		@o.puts "<H2 id=\"t_zoneinfo\">#{title}</H2>"
	    end

	    l10n_zone = $mc.get("ns_zone").capitalize

	    @o.puts "<DIV class=\"zc-zinfo\">"
	    @o.puts tbl_beg
	    @o.puts tbl_zone % [ "<IMG src=\"#{@publish_path}/img/zone.png\" alt=\"#{l10n_zone}\">", domain.name ]
	    domain.ns.each_index { |i| 
		ns_ip = domain.ns[i]
		if i == 0
		    css  = "zc-ns-prim"
		    desc = $mc.get("ns_primary").capitalize
		    logo = "primary"
		else
		    css  = "zc-ns-sec"
		    desc = $mc.get("ns_secondary").capitalize
		    logo = "secondary"
		end

		desc = "<IMG src=\"#{@publish_path}/img/#{logo}.png\" alt= \"#{desc}\">"

		@o.puts tbl_ns % [ css, desc, ns_ip[0], ns_ip[1].join(", ") ]
	    }
	    @o.puts tbl_end
	    @o.puts "</DIV>"
	    @o.flush
	end

	def diag_start()
	    @o.puts "<H2 id=\"t_testres\">#{$mc.get("title_testres")}</H2>"
	end

	def diag_section(title)
	    h2(title)
	end

	def diagnostic1(domainname, 
		i_count, i_unexp, w_count, w_unexp, f_count, f_unexp,
		res, severity)

	    i_tag = @rflag.tagonly ? Config::Info    : $mc.get("w_info_id")
	    w_tag = @rflag.tagonly ? Config::Warning : $mc.get("w_warning_id")
	    f_tag = @rflag.tagonly ? Config::Fatal   : $mc.get("w_fatal_id")
	    
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
		l10n_perfect = $mc.get("w_perfect").capitalize
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

	    @o.puts "<DIV class=\"zc-diag\">"

#	    l10n_name = $mc.get("#{testname}_testname")
#	    @o.puts "<DIV class=\"zc-name\"><IMG src=\"#{@publish_path}/img/element.png\" alt=\"\"> #{l10n_name}</DIV>"

	    @o.puts "<DIV class=\"zc-msg\"><IMG src=\"#{@publish_path}/img/#{logo}.png\" alt=\"\"> #{msg}</DIV>"

	    if @rflag.details && desc.dtl
		@o.puts "<UL class=\"zc-details\">"
		@o.puts "<LI>"
		@o.puts desc.dtl
		@o.puts "</LI>"
		@o.puts "</UL>"
	    end

	    if xpl_lst
		@o.puts "<UL class=\"zc-ref\">"
		xpl_lst.each { |t, h, b|
		    l10n_tag = $mc.get("tag_#{t}")
		    h.gsub!(/<URL:([^>]+)>/, '<A href="\1">\1</A>')
		    b.each { |l| l.gsub!(/<URL:([^>]+)>/, '<A href="\1">\1</A>') }
		    @o.puts "<LI>"
		    @o.puts "<SPAN class=\"zc-ref\">#{l10n_tag}: #{h}</SPAN>"
		    @o.puts "<BR>"
		    @o.puts b.join(" ")
		    @o.puts "</LI>"
		}
		@o.puts "</UL>"
	    end

	    if ! lst.empty?
		@o.puts "<UL class=\"zc-element\">"
		lst.each { |elt| @o.puts "  <LI>#{elt}</LI>" }
		@o.puts "</UL>"
	    end

	    @o.puts "<BR>"
	    @o.puts "</DIV>"
	end
	    

	def status(domainname, i_count, w_count, f_count)
	    unless @rflag.quiet
		l10n_title = $mc.get("title_status")
		@o.puts "<H2 id=\"t_status\">#{l10n_title}</H2>"
	    end
	    @o.print "<DIV class=\"zc-status\">", 
		super(domainname, i_count, w_count, f_count), "</DIV>"
	    @o.puts "<BR>"
	    if @rflag.quiet
		@o.puts "<HR width=\"60%\">"
		@o.puts "<BR>"
	    end
	end



	#------------------------------------------------------------

	def h2(h)
	    @o.puts "<H3 class=\"zc-severity\">---- #{h.capitalize} ----</H3>"
	end
    end
end
