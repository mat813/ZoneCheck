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
		def unit            ; "T/s"  ; end
		def unit_cvt(value) ;  value ; end
	    end

	    def initialize(publisher)
		@publisher  = publisher
		@o          = publisher.output
		@do_counter = @publisher.rflag.counter && @o.tty?
		if @do_counter
		    @counter = PBar::new(@o, 1, PBar::DisplayNoFinalStatus)
		end
	    end
	    
	    def start(count)
		return unless @do_counter
		@counter.start(count)
	    end
	    
	    def done(desc)
		return unless @do_counter
		@counter.done(desc)
	    end
	    
	    def failed(desc)
		return unless @do_counter
		@counter.failed(desc)
	    end
	    
	    def finish
		return unless @do_counter
		@counter.finish
	    end
	    
	    def process(desc, ns, ip)
		if @do_counter
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
	    @o.puts "ZONE  : #{domain.name}"
	    domain.ns.each_index { |i| 
		n = domain.ns[i]
		@o.printf "NS %2s : %s [%s]\n",
		    i == 0 ? "<=" : "  ", n[0], n[1].join(", ")
	    }
	    @o.puts
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
	    
	    @o.puts msg

	    if xpl_lst
		xpl_lst.each { |h, t|
		    h =~ /^\[(\w+)\]:\s*/
		    tag = $mc.get("xpltag_#{$1}")
		    @o.puts " | #{tag}: #{$'}"
		    t.each { |l| @o.puts " | #{l}" }
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
