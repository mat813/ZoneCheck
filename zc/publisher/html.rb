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
	## Class for displaying progression information about
	## the tests being performed.
	##
	class Progress
	    # Initialization
	    def initialize(publisher)
		@publisher	= publisher
		@o		= publisher.output
		@l10n_testing	= $mc.get('w_testing').capitalize
	    end
	    
	    # Start progression
	    def start(count)
		title = if @publisher.rflag.quiet
			then ""
			else "<h2 id=\"t_progress\">" + 
				$mc.get('title_progress') + "</h2>"
			end

		# Counter
		if @publisher.rflag.counter
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
		if @publisher.rflag.counter
		    @o.puts HTML.jscript { "zc_pgr_finish();" }
		    @o.puts HTML.nscript { "</ul>" }
		end

		# Test description
		if @publisher.rflag.testdesc
		    @o.puts "</ul>"
		end
	    end
	    
	    # Process an item
	    def process(desc, ns, ip)
		# Don't bother, if there is no output asked
		return unless (@publisher.rflag.counter ||
			       @publisher.rflag.testdesc)

		xtra = if    ip then " (IP=#{ip})"
		       elsif ns then " (NS=#{ns})"
		       else          ''
		       end
		msg = CGI::escapeHTML("#{desc}#{xtra}")

		# Counter
		if @publisher.rflag.counter
		    @o.puts HTML.jscript {
			"zc_pgr_process(\"#{msg}\")" }
		    @o.puts HTML.nscript {
			"<li>#{@l10n_testing}: #{msg}</li>" }
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

	def initialize(rflag, ostream=$stdout)
	    super(rflag, ostream)
	    @progress		= Progress::new(self)
	    @publish_path	= ZC_HTML_PATH.gsub(/\/+$/, '')
	end

	def error(text)
	    @o.puts "<blockquote class=\"zc-error\">#{text}</blockquote>"
	end

	#------------------------------------------------------------

	def begin
	    l10n_form        = $mc.get('w_form').capitalize
	    l10n_batch_form  = l10n_form+': '+$mc.get('t_batch' ).capitalize
	    l10n_single_form = l10n_form+': '+$mc.get('t_single').capitalize

	    # XXX: javascript only if counter
	    @o.print <<"EOT"
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title>ZoneCheck results</title>

    <!-- Navigation -->
    <link rel="start" href="#{@publish_path}/"             type="text/html">
    <link rel="up"    href="#{@publish_path}/#{$mc.lang}/" type="text/html">

    <link rel="bookmark" title="ZoneCheck website"
	  href="http://www.zonecheck.fr/"                  type="text/html">
    <link rel="bookmark" title="#{l10n_batch_form}"
	  href="#{@publish_path}/#{$mc.lang}/batch.html"   type="text/html">
    <link rel="bookmark" title="#{l10n_single_form}"
	  href="#{@publish_path}/#{$mc.lang}/"             type="text/html">

    <link rel="section" title="#{$mc.get('title_zoneinfo')}"
          href="#t_zoneinfo"                               type="text/html">
    <link rel="section" title="#{$mc.get('title_progress')}"
          href="#t_progress"                               type="text/html">
    <link rel="section" title="#{$mc.get('title_testres')}"
          href="#t_testres"                                type="text/html">
    <link rel="section" title="#{$mc.get('title_status')}"
          href="#t_status"                                 type="text/html">


    <!-- Favicon -->
    <link rel="icon"       href="#{@publish_path}/img/zc-fav.png" type="image/png">


    <!-- Style -->
    <link rel="stylesheet" href="#{@publish_path}/style/zc.css"   type="text/css">

    <style type="text/css">
        UL.zc-ref LI { 
            list-style: url(#{@publish_path}/img/ref.png)     disc }

        UL.zc-element LI { 
            list-style: url(#{@publish_path}/img/element.png) disc }

        UL.zc-details LI { 
            list-style: url(#{@publish_path}/img/details.png) disc }
    </style>

    <!-- Javascript -->
    <script type="text/javascript">
      zc_publish_path = "#{@publish_path}"
    </script>
    <script src="#{@publish_path}/js/progress.js"  type="text/javascript">
    </script>
    <script src="#{@publish_path}/js/popupmenu.js" type="text/javascript">
    </script>
  </head>
  <body>
    <img class="zc-logo" alt="ZoneCheck" src="#{@publish_path}/img/logo.png">
EOT
@o.flush
	end

	def end
	    @o.puts HTML.jscript { 
		"zc_contextmenu_setlocale(\"#{$mc.get('w_name')}\", \"#{$mc.get('w_details')}\", \"#{$mc.get('w_references')}\", \"#{$mc.get('w_elements')}\");\n" +
		    "zc_contextmenu_start();" }
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
Release: #{$zc_name}-#{CGI::escapeHTML($zc_version)} <br>
Last generated: #{Time::now}
<!-- <br> Contact: #{$zc_contact} -->
  </body>
</html>
EOT
	end
	

	def setup(domain_name)
	    if ! @rflag.quiet
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

	    i_tag = @rflag.tagonly ? Config::Info    : $mc.get('w_info_id')
	    w_tag = @rflag.tagonly ? Config::Warning : $mc.get('w_warning_id')
	    f_tag = @rflag.tagonly ? Config::Fatal   : $mc.get('w_fatal_id')
	    
	    i_tag = i_tag.upcase if i_unexp
	    w_tag = w_tag.upcase if w_unexp
	    f_tag = f_tag.upcase if f_unexp

	    summary = "%1s%03d&nbsp;%1s%03d&nbsp;%1s%03d" % [ 
		i_tag, i_count, 
		w_tag, w_count, 
		f_tag, f_count ]


	    @o.puts "<div class=\"zc-diag1\">"
	    @o.puts "<table width=\"100%\">"
	    @o.puts "<tr class=\"zc-title\"><td width=\"100%\">#{domainname}</td><td>#{summary}</td></tr>"
	    if res.nil?
		l10n_perfect = $mc.get('w_perfect').capitalize
		@o.puts "<tr><td colspan=\"2\"><b>#{l10n_perfect}</b></td></tr>"
		@o.puts "<tr><td colspan=\"2\">&nbsp;</td></tr>"

	    else
		msg = if @rflag.tagonly
		      then res.testname
		      else res.desc.msg
		      end
		@o.puts "<tr><td colspan=\"2\">#{severity}: #{res.tag}</td></tr>"
		@o.puts "<tr><td colspan=\"2\">#{msg}</td></tr>"
	    end

	    @o.puts "</table>"
	    @o.puts "</div>"
	end


	def diagnostic(severity, testname, desc, lst)
	    msg, xpl_lst = nil, nil

	    @o.puts "<!-- TEST: #{testname.ljust(40)} -->"
	    @o.puts "<div class=\"zc-diag\">"

	    # Testname
	    if @rflag.testname
		l10n_name = $mc.get("#{testname}_testname")
		@o.puts "<div class=\"zc-name\"><img src=\"#{@publish_path}/img/gear.png\" alt=\"\"> #{l10n_name}</div>"
	    end

	    # Severity
	    severity_tag		= Config.severity2tag(severity)
	    logo			= severity_tag + ".png"
	    l10n_severity_shorttag	= if @rflag.tagonly
					  then #{severity_tag}
					  else $mc.get("w_#{severity_tag}_id")
					  end

	    # Message
	    msg = if severity.nil?
		      $mc.get("#{testname}_ok")
		  else
		      if @rflag.tagonly
			  if desc.is_error?
			  then "#{severity_tag}[Unexpected]: #{testname}"
			  else "#{severity_tag}: #{testname}"
			  end
		      else
			  desc.msg
		      end
		  end
	    
	    @o.puts "<div class=\"zc-msg\"><img src=\"#{@publish_path}/img/#{logo}\" alt=\"#{l10n_severity_shorttag}:\"> #{msg}</div>"
		
	    if !severity.nil?
		# Details
		if @rflag.details && desc.dtl
		    @o.puts "<ul class=\"zc-details\">"
		    @o.puts "<li>"
		    @o.puts desc.dtl
		    @o.puts "</li>"
		    @o.puts "</ul>"
		end

		# Explanation
		if @rflag.explain && !@rflag.tagonly
		    xpl_lst = xpl_split(desc.xpl)
		end

		if xpl_lst
		    @o.puts "<ul class=\"zc-ref\">"
		    xpl_lst.each { |t, h, b|
			l10n_tag = $mc.get("tag_#{t}")
			h.gsub!(/<URL:([^>]+)>/, '<a href="\1">\1</a>')
			b.each { |l| l.gsub!(/<URL:([^>]+)>/, '<a href="\1">\1</a>') }
			@o.puts "<li>"
			@o.puts "<span class=\"zc-ref\">#{l10n_tag}: #{h}</span>"
			@o.puts "<br>"
			@o.puts b.join(" ")
			@o.puts "</li>"
		    }
		    @o.puts "</ul>"
		end
	    end

	    # Elements
	    if ! lst.empty?
		@o.puts "<ul class=\"zc-element\">"
		lst.each { |elt| @o.puts "  <li>#{elt}</li>" }
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
	    [   "STATUS : #{f_count > 0 ? "FAILED" : "PASSED"}",
		"ERROR  : #{f_count}",
		"WARNING: #{w_count}" ].each { |e|
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
