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

module Formatter
    class PBar < Xtra::ProgressBar
	def unit            ; "T/s"  ; end
	def unit_cvt(value) ;  value ; end
    end

    class Text
	MaxLineLength           = 78

	#------------------------------------------------------------

	attr_reader :counter
	def initialize(ostream=$stdout)
	    @ostream   = ostream
	    @mutex     = Mutex::new
	    @count_txt = $mc.get("test_progress")
	    @counter   = PBar::new($stdout, 1, PBar::DisplayNoFinalStatus)
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



	#------------------------------------------------------------

	def testing(desc, ns, ip)
	    xtra = if    ip then " (IP=#{ip})"
		   elsif ns then " (NS=#{ns})"
		   else          ""
		   end
	    
	    printf $mc.get("testing_fmt"), "#{desc}#{xtra}"
	end

	#------------------------------------------------------------

	def intro(domainname, ns, cache)
	    puts "DOMAIN: #{domainname}"
	    ns.each_index { |i| 
		n = ns[i]
		printf "NS %2s : %s [%s]\n",
		    i == 0 ? "<=" : "  ", n[0], n[1].join(", ")
	    }
	    puts "CACHE : #{cache}"
	    puts
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
