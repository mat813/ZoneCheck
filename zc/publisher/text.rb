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
# CONTRIBUTORS:
#
#

require 'textfmt'
require 'config'

module Publisher
    ##
    ##
    ##
    class Text < Template
	Mime		= "text/plain"
	MaxLineLength	= 79

	##
	## Class for displaying progression information about
	## the tests being performed.
	##
	class Progress
	    class PBar
		EraseEndLine            = "\033[K" 
		HideCursor              = "\033[?25l"
		ShowCursor              = "\033[?25h"
		BarSize			= 37

		def initialize(output, precision)
		    @output	= output
		    @precision	= precision
		    @mutex	= Mutex::new
		    @updater	= nil
		    @l10n_unit	= $mc.get("pgr_speed_unit")
		end
		
		def start(length)
		    @length     = length
		    @starttime  = @lasttime = Time.now
		    @totaltime  = 0
		    @processed	= 0
		    @tick       = 0

		    @output.print HideCursor, barstr

		    @updater	= Thread::new { 
			last_processed = nil
			while true
			    sleep(@precision)
			    nowtime      = Time.now
			    
			    @mutex.synchronize {
				@totaltime      = if @lasttime == @starttime
						  then 0.0
						  else nowtime - @starttime
						  end
				@lasttime       = nowtime

				if @processed != last_processed
				    @tick += 1
				    last_processed = @processed
				end

				@output.print "\r", barstr, EraseEndLine
				@output.flush
			    }
			end
		    }
		end
		
		def processed(size)
		    @mutex.synchronize { @processed  += size }
		end

		def done
		    @mutex.synchronize { @updater.kill }
		    @output.print "\r#{EraseEndLine}"
		    @output.flush
		end
		
		def finish
		    @output.print ShowCursor
		end
                
		protected
		def barstr
		    speed	= if @totaltime == 0.0
				  then -1.0
				  else @processed / @totaltime
				  end
		    speed_s	= if speed < 0.0 
				  then "--.--%s" % [ @l10n_unit ]
				  else "%7.2f%s" % [ speed, @l10n_unit ]
				  end
		    
		    if @length > 0 then
			pct	= 100 * @processed / @length
			eta	= if speed < 0.0 
				  then -1
				  else ((@length-@processed) / speed).to_i
				  end
			pct_s	= "%2d%%" % pct
			eta_s	= "ETA " + sec_to_timestr(eta)
			bar_s	= "=" * (BarSize * pct / 100) + ">"
			
			"%-4s[%-#{BarSize}.#{BarSize}s] %-11s %10s %12s" % [
			    pct_s, bar_s, @processed, speed_s, eta_s ]
		    else
			ind	= @tick % (BarSize * 2 - 6)
			pos	= if ind < BarSize - 2
				  then ind + 1;
				  else BarSize - (ind - BarSize + 5)
				  end
			bar_s	= " " * BarSize
			bar_s[pos-1,3] = '<=>'
			
			"    [%s] %-11s %10s" % [ bar_s, @processed, speed_s ]
		    end
		end
		
		private
		def sec_to_timestr(sec)
		    return "--:--" if sec < 0
		    
		    hrs = sec / 3600; sec %= 3600;
		    min = sec / 60;   sec %= 60;
		    
		    if (hrs > 0)
		    then sprintf "%2d:%02d:%02d", hrs, min, sec
		    else sprintf "%2d:%02d", min, sec
		    end
		end
	    end


	    # Initialization
	    def initialize(publisher)
		@publisher	= publisher
		@o		= publisher.output
		@counte		= if @publisher.rflag.counter && @o.tty?
				  then PBar::new(@o, 1)
				  else nil
				  end
		@l10n_testing	= $mc.get("w_testing").capitalize
	    end
	    
	    # Start progression
	    def start(count)
		@counter.start(count)	if @counter
	    end
	    
	    # Finished on success
	    def done(desc)
		@counter.done		if @counter
	    end
	    
	    # Finished on failure
	    def failed(desc)
		@counter.done		if @counter
	    end
	    
	    # Finish (finalize) output
	    def finish
		@counter.finish		if @counter
	    end
	    
	    # Process an item
	    def process(desc, ns, ip)
		# Counter
		if @counter
		    @counter.processed(1)
		end

		# Test description
		if @publisher.rflag.testdesc
		    xtra = if    ip then " (IP=#{ip})"
			   elsif ns then " (NS=#{ns})"
			   else          ""
			   end
	    
		    @o.puts "#{@l10n_testing}: #{desc}#{xtra}"
		end
	    end
	end

	#------------------------------------------------------------

	def initialize(rflag, ostream=$stdout)
	    super(rflag, ostream)
	    @count_txt	= $mc.get("title_progress")
	    @progress	= Progress::new(self)
	end


	#------------------------------------------------------------
	
	def error(text)
	    paragraph = ::Text::Format::new
	    paragraph.width = 72
	    paragraph.tag   = $mc.get("w_error").upcase + ": "
	    @o.puts paragraph.format(text)
	end


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

	def diag_start()
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

	    if @rflag.details && desc.dtl
		txt = ::Text::Format::new
		txt.width = 72
		txt.tag   = "  "
		txt.format(desc.dtl).split(/\n/).each { |l|
		    @o.puts " : #{l}"
		}
		@o.puts " `..... .. .. . .  ."
	    end
	    
	    if xpl_lst
		xpl_lst.each { |t, h, b|
		    tag = $mc.get("tag_#{t}")
		    @o.puts " | #{tag}: #{h}"
		    b.each { |l| @o.puts " |  #{l}" }
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
	    @o.printf "==> %s\n", super(domainname, i_count, w_count, f_count)
	end


	#------------------------------------------------------------

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
