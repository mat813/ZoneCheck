# $Id$

# 
# AUTHOR : Stephane D'Alu <sdalu@nic.fr>
# CREATED: 2002/08/02 13:58:17
#
# $Revivion$ 
# $Date$
#
# CONTRIBUTORS:
#
#


require 'thread'
require 'xtra'

module Publisher
    class PBar < Xtra::ProgressBar
	def unit            ; "T/s"  ; end
	def unit_cvt(value) ;  value ; end
    end

    class Text
	MaxLineLength           = 79

	#------------------------------------------------------------

	def initialize(rflag, ostream=$stdout)
	    @rflag	= rflag
	    @ostream	= ostream
	    @mutex	= Mutex::new
	    @count_txt	= $mc.get("test_progress")
	    @counter	= PBar::new($stdout, 1, PBar::DisplayNoFinalStatus)
	end


	#------------------------------------------------------------

	def synchronize(&block)
	    @mutex.synchronize(&block)
	end

	#------------------------------------------------------------

	def begin
	end

	def end
	end
	
	#------------------------------------------------------------

	def counter
	    @counter
	end

	def testing(desc, ns, ip)
	    xtra = if    ip then " (IP=#{ip})"
		   elsif ns then " (NS=#{ns})"
		   else          ""
		   end
	    
	    printf $mc.get("testing_fmt"), "#{desc}#{xtra}"
	end

	def intro(domain)
	    puts "DOMAIN: #{domain.name}"
	    domain.ns.each_index { |i| 
		n = domain.ns[i]
		printf "NS %2s : %s [%s]\n",
		    i == 0 ? "<=" : "  ", n[0], n[1].join(", ")
	    }
	    puts "CACHE : #{domain.cache}"
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
	    printf $mc.get(tag), w_count
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



    class HTML
	#------------------------------------------------------------

	def initialize
	    @mutex     = Mutex::new
	    @count_txt = $mc.get("test_progress")
	end


	#------------------------------------------------------------

	def synchronize(&block)
	    @mutex.synchronize(&block)
	end

	#------------------------------------------------------------

	def begin
	    print <<"EOT"
<HTML>
  <HEAD>
    <META http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
    <TITLE>ZoneCheck results</TITLE>
    <link rel="StyleSheet" href="tpl.css" type="text/css" media="screen">
<STYLE>
BODY {
    background: #EEEEEF;
    color: black;
}

TABLE.intro TR.primary {
background: #F4F4F4;
}

TABLE.intro TR.secondary


</STYLE>
  </HEAD>
  <BODY>
EOT
	end

	def end
	    print <<"EOT"
  </BODY>
</HTML>
EOT
	end
	
	#------------------------------------------------------------

	def counter_start
	end

	def counter(pos, total)
	end

	def counter_end
	end

	#------------------------------------------------------------

	def testing(desc, ns, ip)
	    xtra = if ip
		       " (IP=#{ip})"
		   elsif ns
		       " (NS=#{ns})"
		   else
		       ""
		   end
	    
	    printf $mc.get("testing_fmt"), "#{desc}#{xtra}"
	end

	#------------------------------------------------------------

	def intro(domainname, ns, cache)
	    h1("Summary")
	    puts '<TABLE>'
	    puts "<TR><TD>Domain</TD><TD colspan='2'>#{domainname}</TD></TR>"
	    ns.each_index { |i| 
		n = ns[i]
		printf "<TR class=\"%s\"><TD>NS</TD><TD>%s</TD><TD>%s</TD></TR>\n",
		    i == 0 ? "exerg" : "secondary", n[0], n[1].join(", ")
	    }
	    puts "<TR><TD>CACHE</TD><TD colspan='2'>#{cache}</TD></TR>"
	    puts "</TABLE>"
	end

	#------------------------------------------------------------
	def h1(h)
	    puts "<H1>#{h.capitalize}</H1>"
	end

	def h2(h)
	    puts "<H2>---- #{h.capitalize} ----</H2>"
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

	def list(l, tag="=>")
	    puts "<UL>"
	    l.each { |elt| puts "<LI>#{elt}</LI>" }
	    puts "</UL>"
	end

	def vskip(skip=1)
	    skip.times { puts "<BR>" }
	end
    end


    class BatchText 
    end
end

