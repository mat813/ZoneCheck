# $Id$

# 
# CONTACT     : zonecheck@nic.fr
# AUTHOR      : Stephane D'Alu <sdalu@nic.fr>
#
# CREATED     : 2002/08/02 13:58:17
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
    
#####
#
# TODO:
#  - escape html text
#  - clean up html
#  - only load javascript when needed
#

require 'cgi'
require 'config'

module Publisher
    ##
    ##
    ##
    class HTML < Template
	Mime		= "text/html"

	# Shortcut for enclosing javascript
	def self.jscript
	    '<script type="text/javascript">' + yield + '</script>'
	end

	# Shortcut for enclosing noscript
	def self.nscript
	    '<noscript>' + yield + '</noscript>'
   	end


	##
	## Rendering of XML chunks
	##
	class XMLTransform
	    attr_writer :const

	    def initialize
		@const	= {}
	    end

	    def apply(xmlnode, var={})
		case xmlnode
		when MyXML::Node::Element
		    case xmlnode.name
		    when MsgCat::NAME, MsgCat::FAILURE, MsgCat::SUCCESS
			do_text(xmlnode, var)
		    when MsgCat::EXPLANATION	# not displayed in tagonly
			"<ul class=\"zc-ref\">" +
			xmlnode.to_a('src').collect { |xmlsrc|
			    type  = $mc.get("tag_#{xmlsrc['type']}")
			    title = do_text(xmlsrc.child('title'))

			    from  = xmlsrc['from']
			    fid   = xmlsrc['fid']
			    link  = case from
				    when 'rfc'
					case fid
					when NilClass
					    'http://www.ietf.org/'
					when /^(rfc\d+)/
					    "ftp://ftp.ietf.org/rfc/#{$1}.txt"
					end
				    end

			    title = "<a href=\"#{link}\">#{title}</a>" if link

			    "<li>" +
			    "<span class=\"zc-ref\">#{type}: <i>#{title}</i></span>" +
			    "<br>" +
			    xmlsrc.to_a('para').collect { |xmlpara|
				fmt_para(do_text(xmlpara, var)) }.join +
			    "</li>"
			}.join("\n") +
			"</ul>"
		    when MsgCat::DETAILS	# not displayed in tagonly
			"<ul class=\"zc-details\"><li>" +
			xmlnode.to_a('para').collect { |xmlpara|
			    fmt_para(do_text(xmlpara, var)) }.join +
			'</li></ul>'
		    else
			do_text(xmlnode, var)
		    end
		when MyXML::Node::Text
		    CGI::escapeHTML(xmlnode.value)
		else
		    ''
		end
	    end

	    #-- [private] -----------------------------------------------
	    private
	    def fmt_para(text)
		'<p>' + text + '</p>'
	    end

	    def do_text(xmlnode, var={})
		case xmlnode
		when MyXML::Node::Element
		    case xmlnode.name
		    when 'zcvar', 'zcconst'
			display = xmlnode['display']
			data    = case xmlnode.name
				  when 'zcvar'   then var
				  when 'zcconst' then @const
				  end
			name    = xmlnode['name']
			value	= data.fetch(name)
			case display
			when 'duration'
			    unit  = $mc.get('word:second_abbr')
			    "<abbr title=\"#{value} #{unit}\">" +
				Publisher.to_bind_duration(value.to_i) +
				'</abbr>'
			else
			    value
			end
		    when 'uri'
			link = xmlnode['link']
			"<a href=\"#{link}\">" + xmlnode.text + "</a>"
		    else
			xmlnode.to_a(:child).collect { |xmlchild| 
			    do_text(xmlchild, var) }.join
		    end
		when MyXML::Node::Text
		    CGI::escapeHTML(xmlnode.value)
		else
		    ''
		end
	    end
	end


	##
	## Class for displaying progression information about
	## the tests being performed.
	##
	class Progress
	    # Initialization
	    def initialize(publisher)
		@publisher	= publisher
		@jscript_off	= publisher.option['nojavascript']
		@o		= publisher.output
		@l10n_testing	= $mc.get('word:testing').capitalize
	    end
	    
	    # Start progression
	    def start(count)
		title = if @publisher.rflag.quiet
			then ""
			else "<h2 id=\"t_progress\">" + 
				$mc.get('title_progress') + "</h2>"
			end

		# Counter
		if @publisher.rflag.counter && !@jscript_off
		    @o.puts HTML.jscript {
			pgr_quiet_param  = @publisher.rflag.quiet ? "true" \
			                                          : "false"
			pgr_locale_param = [ 
			    $mc.get('title_progress'),
			    $mc.get('pgr_progress'),
			    $mc.get('pgr_test'),
			    $mc.get('pgr_speed'),
			    $mc.get('pgr_time'),
			    $mc.get('pgr_na') ]
			pgr_start_param  = count

			str  = 'zc_pgr_setlocale("%s", "%s", "%s", "%s", "%s", "%s");' % pgr_locale_param
			str += 'zc_pgr_setquiet(%s);' % pgr_quiet_param
			str += 'zc_pgr_start(%d);'    % pgr_start_param
			str
		    }
		    @o.puts HTML.nscript { title  }
		    @o.puts HTML.nscript { "<ul>" }
		end

		# Test description
		if @publisher.rflag.testdesc
		    @o.puts title
		    @o.puts "<ul class=\"zc-test\">"
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
		if @publisher.rflag.counter && !@jscript_off
		    @o.puts HTML.jscript { "zc_pgr_finish();" }
		    @o.puts HTML.nscript { "</ul>" }
		end

		# Test description
		if @publisher.rflag.testdesc
		    @o.puts "</ul>"
		end
	    end
	    
	    # Process an item
	    def process(checkname, ns, ip)
		# Don't bother, if there is no output asked
		return unless (@publisher.rflag.counter ||
			       @publisher.rflag.testdesc)

		xtra = if    ip then " (IP=#{ip})"
		       elsif ns then " (NS=#{ns})"
		       else          ''
		       end
		desc = if @publisher.rflag.tagonly
			   checkname
		       else
			   @publisher.xmltrans.apply($mc.get(checkname, 
						MsgCat::CHECK, MsgCat::NAME))
		       end
		msg = "#{desc}#{xtra}"

		# Counter
		if @publisher.rflag.counter && !@jscript_off
		    jmsg = msg.gsub(/\"/, '\\"')
		    @o.puts HTML.jscript { "zc_pgr_process(\"#{jmsg}\")" }
		    @o.puts HTML.nscript { "<li>#{@l10n_testing}: #{msg}</li>"}
		end

		# Test description
		if @publisher.rflag.testdesc
		    @o.puts "<li>#{@l10n_testing}: #{msg}</li>"
		end

		# Flush
		@o.flush
	    end
	end


	#------------------------------------------------------------

	def initialize(rflag, option, ostream=$stdout)
	    super(rflag, option, ostream)
	    @progress		= Progress::new(self)
	    @publish_path	= ZC_HTML_PATH.gsub(/\/+$/, '')
	    @xmltrans		= XMLTransform::new
	end

	def error(text)
	    @o.puts "<blockquote class=\"zc-error\">"
	    @o.puts "<!-- ERROR: xxx -->"
	    @o.puts text
	    @o.puts "</blockquote>"
	end

	#------------------------------------------------------------

	def begin
	    return if @option['ihtml']

	    l10n_form        = $mc.get('word:form').capitalize
	    l10n_batch_form  = l10n_form+': '+$mc.get('t_batch' ).capitalize
	    l10n_single_form = l10n_form+': '+$mc.get('t_single').capitalize

	    # XXX: javascript only if counter
	    langpath = $locale.language
	    langpath << "_" + $locale.country if $locale.country
	    @o.print <<"EOT"
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title>ZoneCheck results</title>

    <!-- Navigation -->
    <link rel="start" href="#{@publish_path}/"              type="text/html">
    <link rel="up"    href="#{@publish_path}/#{langpath}/"  type="text/html">

    <link rel="bookmark" title="ZoneCheck website"
	  href="http://www.zonecheck.fr/"                   type="text/html">
    <link rel="bookmark" title="#{l10n_batch_form}"
	  href="#{@publish_path}/#{$langpath}/batch.html"   type="text/html">
    <link rel="bookmark" title="#{l10n_single_form}"
	  href="#{@publish_path}/#{langpath}/"              type="text/html">

    <link rel="section" title="#{$mc.get('title_zoneinfo')}"
          href="#t_zoneinfo"                                type="text/html">
    <link rel="section" title="#{$mc.get('title_progress')}"
          href="#t_progress"                                type="text/html">
    <link rel="section" title="#{$mc.get('title_testres')}"
          href="#t_testres"                                 type="text/html">
    <link rel="section" title="#{$mc.get('title_status')}"
          href="#t_status"                                  type="text/html">


    <!-- Favicon -->
    <link rel="icon"       href="#{@publish_path}/img/zc-fav.png" type="image/png">


    <!-- Style -->
    <link rel="stylesheet" href="#{@publish_path}/style/zc.css"   type="text/css">

    <style type="text/css">
        ul.zc-ref li { 
            list-style: url(#{@publish_path}/img/ref.png)     disc }

        ul.zc-element li { 
            list-style: url(#{@publish_path}/img/element.png) disc }

        ul.zc-details li { 
            list-style: url(#{@publish_path}/img/details.png) disc }
    </style>
EOT

	    unless @option['nojavascript']
	        @o.print <<"EOT"
    <!-- Javascript -->
    <script type="text/javascript">
      zc_publish_path = "#{@publish_path}"
    </script>
    <script src="#{@publish_path}/js/progress.js"  type="text/javascript">
    </script>
EOT
            end
	    @o.print <<"EOT"
  </head>
  <body>
    <img class="zc-logo" alt="ZoneCheck" src="#{@publish_path}/img/logo.png">
EOT
            @o.flush
	end

	def end
	    return if @option['ihtml']

	    profileinfo = if info.profile
			  then "#{info.profile[0]} (#{info.profile[1]})"
			  else 'N/A'
			  end
#	    @o.puts @HTML.jscript { 
#		"zc_contextmenu_setlocale(\"#{$mc.get('word:name')}\", \"#{$mc.get('word:details')}\", \"#{$mc.get('word:references')}\", \"#{$mc.get('word:elements')}\");\n" +
#		    "zc_contextmenu_start();" }
	    @o.print <<"EOT"

    <hr>
    <span style="float: right;">
      <a href="http://jigsaw.w3.org/css-validator/check/referer">
	<img style="border:0;width:88px;height:31px"
	     src="http://jigsaw.w3.org/css-validator/images/vcss" 
	     alt="Valid CSS!"></a>
      <a href="http://validator.w3.org/check/referer">
	<img style="border:0;width:88px;height:31px"
	     src="http://www.w3.org/Icons/valid-html401"
	     alt="Valid HTML 4.01!"></a>
    </span>
Profile: #{profileinfo} <br>
Statistics: #{"%d tests in %.2f sec accross %d nameservers" % [info.testcount, info.testingtime, info.nscount]} <br>
Release: #{$zc_name}-#{CGI::escapeHTML($zc_version)} <br>
Last generated: #{Time::now.gmtime.strftime("%Y/%m/%d %H:%M UTC")}
<!-- <br> Contact: #{$zc_contact} -->
  </body>
</html>
EOT
	end
	

	def setup(domain_name)
	    if !@rflag.quiet && !@option['ihtml']
		@o.puts "<h1>ZoneCheck: #{domain_name}</h1>"
	    end
	end

	#------------------------------------------------------------


	def intro(domain)
	    return unless @rflag.intro

	    tbl_beg   = '<table rules="rows" class="zc-domain">'
	    tbl_zone  = '<tr class="zc-zone"><td>%s</td><td colspan="4">%s</td></tr>'
	    tbl_ns    = '<tr class="%s"><td>%s</td><td>%s</td><td>%s</td></tr>'
	    tbl_end   = '</table>'


	    unless @rflag.quiet
		title = $mc.get('title_zoneinfo')
		@o.puts "<h2 id=\"t_zoneinfo\">#{title}</h2>"
	    end

	    l10n_zone = $mc.get('ns_zone').capitalize

	    @o.puts "<div class=\"zc-zinfo\">"
	    # Easy parseable comment
	    ([ "ZONE: #{domain.name}" ] +
		domain.ns.collect { |ns, ips|
		 "NS  : #{ns} [#{ips.join(', ')}]" }).each { |e|
		@o.puts "<!-- #{e.ljust(70)} -->" }
	    # Result
	    @o.puts tbl_beg
	    @o.puts tbl_zone % [ "<img src=\"#{@publish_path}/img/zone.png\" alt=\"#{l10n_zone}\">", domain.name ]
	    domain.ns.each_index { |i| 
		ns_ip = domain.ns[i]
		if i == 0
		    css  = 'zc-ns-prim'
		    desc = $mc.get('ns_primary').capitalize
		    logo = 'primary'
		else
		    css  = 'zc-ns-sec'
		    desc = $mc.get('ns_secondary').capitalize
		    logo = 'secondary'
		end

		desc = "<img src=\"#{@publish_path}/img/#{logo}.png\" alt= \"#{desc}\">"

		@o.puts tbl_ns % [ css, desc, 
		    ns_ip[0].to_s, ns_ip[1].join(", ") ]
	    }
	    @o.puts tbl_end
	    @o.puts "</div>"
	    @o.flush
	end

	def diag_start()
	    @o.puts "<h2 id=\"t_testres\">#{$mc.get('title_testres')}</h2>"
	end

	def diag_section(title)
	    @o.puts "<h3 class=\"zc-diagsec\">---- #{title} ----</h3>"
	end

	def diagnostic1(domainname, 
		i_count, i_unexp, w_count, w_unexp, f_count, f_unexp,
		res, severity)

	    i_tag, w_tag, f_tag = 
		severity_description(i_unexp, w_unexp, f_unexp)

	    summary = "%1s%03d&nbsp;%1s%03d&nbsp;%1s%03d" % [ 
		i_tag, i_count, 
		w_tag, w_count, 
		f_tag, f_count ]

	    @o.puts "<div class=\"zc-diag1\">"
	    @o.puts "<table width=\"100%\">"
	    @o.puts "<tr class=\"zc-title\"><td width=\"100%\">#{domainname}</td><td>#{summary}</td></tr>"
	    if !res.nil?
		if @rflag.tagonly
		    status = severity
		    source = res.source || 'generic'
		    msg    = res.testname
		else
		    status = Config.severity2tag(severity)
		    status = $mc.get("word:#{status}").capitalize
		    source = res.source || $mc.get('word:generic')
		    msg    = status_message(res.testname, res.desc, severity)
		end
		@o.puts "<tr><td colspan=\"2\">#{status}: #{source}</td></tr>"
		@o.puts "<tr><td colspan=\"2\">#{msg}</td></tr>"
	    else
		@o.puts "<tr><td colspan=\"2\">&nbsp;--</td></tr>"
		@o.puts "<tr><td colspan=\"2\">&nbsp;--</td></tr>"
	    end

	    @o.puts "</table>"
	    @o.puts "</div>"
	end


	def diagnostic(severity, testname, desc, lst)
	    @o.puts "<!-- TEST: #{testname.ljust(40)} -->"
	    @o.puts "<div class=\"zc-diag\">"

	    # Testname
	    if  desc.check && @rflag.testname && !@rflag.tagonly
		l10n_name = @xmltrans.apply($mc.get(testname, 
					    MsgCat::CHECK, MsgCat::NAME))
		@o.puts "<div class=\"zc-name\"><img src=\"#{@publish_path}/img/gear.png\" alt=\"\"> #{l10n_name}</div>"
	    end

	    # Status messsage
	    status_tag		= Config.severity2tag(severity)
	    logo		= status_tag + ".png"

	    if @rflag.tagonly
		status_shorttag	= severity || Config::Ok
		status = desc.error ? "[Unexpected] #{testname}" : testname
	    else
		status_shorttag	= $mc.get("word:#{status_tag}_id")
		status = status_message(testname, desc, severity)
	    end

	    @o.puts "<div class=\"zc-msg\"><img src=\"#{@publish_path}/img/#{logo}\" alt=\"#{status_shorttag}:\"> #{status}</div>"
		
	    # Explanation & Details
	    #  => only in case of failure (ie: not for Ok or Error)
	    #     not when in 'tag only' mode
	    if  desc.check && !severity.nil? && 
		    desc.error.nil? && !@rflag.tagonly
		# Explanation
		if @rflag.explain 
		    explanation = $mc.get(testname, 
					  MsgCat::CHECK, MsgCat::EXPLANATION)
		    @o.print @xmltrans.apply(explanation) if explanation
		end

		# Details
		if @rflag.details && desc.details
		    details = $mc.get(testname, MsgCat::CHECK, MsgCat::DETAILS)
		    @o.print @xmltrans.apply(details, desc.details) if details
		end
	    end

	    # Elements
	    if ! lst.empty?
		@o.puts "<ul class=\"zc-element\">"
		lst.each { |elt| 
		    elt ||= (@rflag.tagonly ? 'generic' : $mc.get('word:generic'))
		    @o.puts "  <li>#{elt}</li>" }
		@o.puts "</ul>"
	    end

	    @o.puts "<br>"
	    @o.puts "</div>"
	end
	    

	def status(domainname, i_count, w_count, f_count)
	    unless @rflag.quiet
		l10n_title = $mc.get('title_status')
		@o.puts "<h2 id=\"t_status\">#{l10n_title}</h2>"
	    end

	    @o.puts "<div class=\"zc-status\">"
	    # Easy parseable comment
	    [   "STATUS  : #{f_count > 0 ? "FAILED" : "PASSED"}",
		" error  : #{f_count}",
		" warning: #{w_count}" ].each { |e|
		@o.puts "<!-- #{e.ljust(20)} -->" }
	    # Result
	    @o.puts super(domainname, i_count, w_count, f_count)
	    @o.puts "</div>"

	    @o.puts "<br>"
	    if @rflag.quiet
		@o.puts "<hr width=\"60%\">"
		@o.puts "<br>"
	    end
	end
    end
end
