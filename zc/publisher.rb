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


require 'thread'
require 'xtra'


module Publisher
    ##
    ##
    ##
    class Template # --> ABSTRACT <--
	attr_reader :progress
	attr_reader :rflag

	def initialize(rflag, ostream=$stdout)
	    @rflag	= rflag
	    @o		= ostream
	    @mutex	= Mutex::new
	end

	def output ; @o ; end

	def synchronize(&block)
	    @mutex.synchronize(&block)
	end

	def status(domainname, i_count, w_count, f_count)
	    if f_count == 0
		tag = (w_count > 0) ? "res_succeed_but" : "res_succeed"
	    else
		if ! @rflag.stop_on_fatal # XXX: bad $
		    tag = "res_failed_on"
		else
		    tag = (w_count > 0) ? "res_failed_and" : "res_failed"
		end
	    end
	    $mc.get(tag) % [ w_count ]
	end

	def begin ; end
	def end   ; end
    end


    
    ##
    ##
    ##
    class Text < Template
	Mime		= "text/plain"
	MaxLineLength	= 79

	class Progress
	    class PBar < TTY::ProgressBar
		def unit            ; "T/s"  ; end
		def unit_cvt(value) ;  value ; end
	    end

	    def initialize(publisher)
		@publisher = publisher
		@counter = PBar::new($stdout, 1, PBar::DisplayNoFinalStatus)
	    end
	    
	    def start(count)
		return unless @publisher.rflag.counter
		@counter.start(count)
	    end
	    
	    def done(desc)
		return unless @publisher.rflag.counter
		@counter.done(desc)
	    end
	    
	    def failed(desc)
		return unless @publisher.rflag.counter
		@counter.failed(desc)
	    end
	    
	    def finish
		return unless @publisher.rflag.counter
		@counter.finish
	    end
	    
	    def process(desc, ns, ip)
		if @publisher.rflag.counter
		    @counter.processed(1)
		end
		if @publisher.rflag.testdesc
		    xtra = if    ip then " (IP=#{ip})"
			   elsif ns then " (NS=#{ns})"
			   else          ""
			   end
	    
		    printf $mc.get("testing_fmt"), "#{desc}#{xtra}"
		end
	    end
	end

	#------------------------------------------------------------

	def initialize(rflag, ostream=$stdout)
	    super(rflag, ostream)
	    @count_txt	= $mc.get("test_progress")
	    @progress	= Progress::new(self)
	end


	#------------------------------------------------------------


	def intro(domain)
	    puts "ZONE  : #{domain.name}"
	    domain.ns.each_index { |i| 
		n = domain.ns[i]
		printf "NS %2s : %s [%s]\n",
		    i == 0 ? "<=" : "  ", n[0], n[1].join(", ")
	    }
	    puts
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

	    summary = "%1s%03d %1s%03d %1s%03d" % [ 
		i_tag, i_count, 
		w_tag, w_count, 
		f_tag, f_count ]

	    printf "%-*s    %s\n", 
		MaxLineLength - 4 - summary.length, domainname, summary

	    if @rflag.tagonly
		msg1("  #{severity}: #{res.tag}")
		msg1("  #{res.testname}")
	    else
		msg1("  #{severity}: #{res.tag}")
		msg1("  #{res.desc.msg}")
	    end

	end


	def diagnostic(severity, testname, desc, lst)
	    msg, xpl = nil, nil
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
		xpl = desc.xpl
	    end
	    
	    msg1(msg)
	    explanation(xpl)
	    list(lst)
	    vskip
	end
	    

	def status(domainname, i_count, w_count, f_count)
	    print super(domainname, i_count, w_count, f_count)
	end


	#------------------------------------------------------------
	def h1(h)
	end

	def h2(h)
	    txtlen = [h.length, MaxLineLength-20].min
	    txt    = h.capitalize[0..txtlen]
	    print "       ", "_" * (8+txtlen), "\n"
	    print "     ,", "-" * (8+txtlen), ".|\n"
	    print "~~~~ |    #{txt}    || ", 
		"~" * (MaxLineLength-19-txtlen), "\n"
	    print "     `", "-" * (8+txtlen), "'\n"
	    print "\n"
	end

	def explanation(xpl)
	    return unless xpl
	    xpl.split(/\n/).each { |e|
		puts " | #{e}"
	    }
	    puts " `----- -- -- - -  -"
	end
	
	def msg1(str)
	    puts str
	end

	def list(l, tag=" =>")
	    l.each { |elt|
		lines  = elt.split(/\n/)
		spacer = " " * (tag.length + 1)
		
		if !lines.empty?
		    puts "#{tag} #{lines[0]}"
		    lines[1..-1].each { |e|
			puts "#{spacer} #{e}"
		    }
		end
	    }
	end

	def vskip(skip=1)
	    skip.times { puts }
	end
    end



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
		title = "<H2>Progress</H2>"
		if @publisher.rflag.counter
		    @o.puts HTML.jscript { "zc_pgr_start(#{count})" }
		    @o.puts HTML.nscript { title + "<UL>" }
		end
		if @publisher.rflag.testdesc
		    @o.puts title
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
		    printf $mc.get("testing_fmt"), "#{desc}#{xtra}"
		    puts "<BR>"
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
	    print <<"EOT"
<HTML>
  <HEAD>
    <META http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
    <TITLE>ZoneCheck results</TITLE>
    <LINK rel="stylesheet" href="/zc/zc.css" type="text/css">
    <SCRIPT language="JavaScript" src="/zc/progress.js" type="text/javascript">
    </SCRIPT>
  </HEAD>
  <BODY>
<H1>ZoneCheck</H1>
EOT
@o.flush
	end

	def end
	    print <<"EOT"
  </BODY>
</HTML>
EOT
	end
	
	#------------------------------------------------------------


	def intro(domain)
	    tbl_beg   = '<TABLE rules="rows" class="zc_domain">'
	    tbl_zone  = '<TR class="zc_zone"><TD>%s</TD><TD colspan="4">%s</TD></TR>'
	    tbl_ns    = '<TR class="%s"><TD>%s</TD><TD>%s</TD><TD>%s</TD></TR>'
	    tbl_end   = '</TABLE>'


	    h1("Zone information")


	    puts tbl_beg
	    puts tbl_zone % [ "Zone", domain.name ]
	    domain.ns.each_index { |i| 
		ns_ip = domain.ns[i]
		if i == 0
		    css  = "zc_ns_prim"
		    desc = "Primary"
		else
		    css  = "zc_ns_sec"
		    desc = "Secondary"
		end

		puts tbl_ns % [ css, desc, ns_ip[0], ns_ip[1].join(", ") ]
	    }
	    puts tbl_end
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

	    summary = "%1s%03d %1s%03d %1s%03d" % [ 
		i_tag, i_count, 
		w_tag, w_count, 
		f_tag, f_count ]

	    printf "%-*s    %s\n", 
		MaxLineLength - 4 - summary.length, domainname, summary

	    if @rflag.tagonly
		msg1("  #{severity}: #{res.tag}")
		msg1("  #{res.testname}")
	    else
		msg1("  #{severity}: #{res.tag}")
		msg1("  #{res.desc.msg}")
	    end

	end


	def diagnostic(severity, testname, desc, lst)
	    msg, xpl = nil, nil
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
		xpl = desc.xpl
	    end
	    
	    @o.puts "<DIV class=\"zc_diag\">"
	    @o.puts "<DIV class=\"zc_title\">#{msg}</DIV>"
	    explanation(xpl)
	    @o.puts "<UL>"
	    lst.each { |elt| @o.puts "  <LI>#{elt}</LI>" }
	    @o.puts "</UL>"
	    @o.puts "<BR>"
	    @o.puts "</DIV>"
	end
	    

	def status(domainname, i_count, w_count, f_count)
	    h1("Final status")
	    print super(domainname, i_count, w_count, f_count)
	end



	#------------------------------------------------------------

	def h1(h)
	    @o.puts "<H2>#{h.capitalize}</H2>"
	end

	def h2(h)
	    @o.puts "<H3 class=\"warning\">---- #{h.capitalize} ----</H3>"
#	    @o.puts "<P class=\"warning\">---- #{h.capitalize} ----</P>"
	end

	def explanation(xpl)
	    return unless xpl
	    puts "<UL class=\"zc_ref\">"
	    xpl.split(/\n/).each { |e|
		if e =~ /^Ref/
		    puts "<LI><SPAN class=\"zc_ref\">#{e}</SPAN><BR>"
		else
		    puts e
		end
	    }
	    puts "</UL>"
	end
	
	def msg1(str)
	    puts "<H3>#{str}</H3>"
	end

	def list(l, tag="=>")
	    @o.puts "<UL>"
	    l.each { |elt| @o.puts "  <LI>#{elt}</LI>" }
	    @o.puts "</UL>"
	end

	def vskip(skip=1)
	    skip.times { puts "<BR>" }
	end
    end
end
