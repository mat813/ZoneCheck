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

require 'xtra/progress'


module Publisher
    ##
    ##
    ##
    class Text < Template
	Mime		= "text/plain"
	MaxLineLength	= 79

	class Progress
	    class PBar < TTY::ProgressBar
		def unit            ; $mc.get("pgr_speed_unit") ; end
		def unit_cvt(value) ; value                     ; end
	    end

	    def initialize(publisher)
		@publisher  = publisher
		@o          = publisher.output
		@counter    = if @publisher.rflag.counter && @o.tty?
			      then PBar::new(@o, 1, PBar::DisplayNoFinalStatus)
			      else nil
			      end
	    end
	    
	    def start(count)
		@counter.start(count)	if @counter
	    end
	    
	    def done(desc)
		@counter.done(desc)	if @counter
	    end
	    
	    def failed(desc)
		@counter.failed(desc)	if @counter
	    end
	    
	    def finish
		@counter.finish		if @counter
	    end
	    
	    def process(desc, ns, ip)
		if @counter
		    @counter.processed(1)
		end
		if @publisher.rflag.testdesc
		    xtra = if    ip then " (IP=#{ip})"
			   elsif ns then " (NS=#{ns})"
			   else          ""
			   end
	    
		    @o.printf $mc.get("testing_fmt"), "#{desc}#{xtra}"
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
	    l10n_zone	= $mc.get("ns_zone").upcase
	    l10n_ns	= $mc.get("ns_ns"  ).upcase
	    sz		= [ l10n_zone.length, l10n_ns.length+3 ].max

	    @o.printf "%-*s : %s\n", sz, l10n_zone, domain.name
	    domain.ns.each_index { |i| 
		n = domain.ns[i]
		@o.printf "%-*s : %s [%s]\n", 
		    sz, i == 0 ? "#{l10n_ns} <=" : "#{l10n_ns}  ",
		    n[0], n[1].join(", ")
	    }
	    @o.puts
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

	    summary = "%1s%03d %1s%03d %1s%03d" % [ 
		i_tag, i_count, 
		w_tag, w_count, 
		f_tag, f_count ]

	    printf "%-*s    %s\n", 
		MaxLineLength - 4 - summary.length, domainname, summary

	    if @rflag.tagonly
		@o.puts "  #{severity}: #{res.tag}"
		@o.puts "  #{res.testname}"
	    else
		@o.puts "  #{severity}: #{res.tag}"
		@o.puts "  #{res.desc.msg}"
	    end

	end


	def diagnostic(severity, testname, desc, lst)
	    msg, xpl_lst = nil, nil
	    if @rflag.tagonly
		if desc.is_error?
		    l10n_unexpected = $mc.get("w_unexpected").capitalize
		    msg = "#{severity}[#{l10n_unexpected}]: #{testname}"
		else
		    msg = "#{severity}: #{testname}"
		end
	    else
		msg = desc.msg
	    end


	    if @rflag.explain && !@rflag.tagonly
		xpl_lst = xpl_split(desc.xpl)
	    end
	    
	    @o.puts msg

	    if xpl_lst
		xpl_lst.each { |t, h, b|
		    tag = $mc.get("xpltag_#{t}")
		    @o.puts " | #{tag}: #{h}"
		    b.each { |l| @o.puts " | #{l}" }
		}
		@o.puts " `----- -- -- - -  -"
	    end


	    lst.each { |elt|
		lines  = elt.split(/\n/)
		
		if !lines.empty?
		    @o.puts "=> #{lines[0]}"
		    lines[1..-1].each { |e|
			@o.puts "   #{e}"
		    }
		end
	    }

	    @o.puts ""
	end
	    

	def status(domainname, i_count, w_count, f_count)
	    @o.print "==> ", super(domainname, i_count, w_count, f_count)
	end


	#------------------------------------------------------------
	def h1(h)
	end

	def h2(h)
	    txtlen = [h.length, MaxLineLength-20].min
	    txt    = h.capitalize[0..txtlen]
	    @o.print "       ", "_" * (8+txtlen), "\n"
	    @o.print "     ,", "-" * (8+txtlen), ".|\n"
	    @o.print "~~~~ |    #{txt}    || ", 
		"~" * (MaxLineLength-19-txtlen), "\n"
	    @o.print "     `", "-" * (8+txtlen), "'\n"
	    @o.print "\n"
	end
    end
end
