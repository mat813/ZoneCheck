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
			text = xmlnode.to_a('src').collect { |xmlsrc|
			    type  = $mc.get("tag_#{xmlsrc['type']}")
			    title = do_text(xmlsrc.child('title'))

			    type + ': ' + title + "\n" +
			    xmlsrc.to_a('para').collect { |xmlpara|
				fmt_para(do_text(xmlpara, var)) }.join
			}.join("\n")
			::Text::Formater.lbox(text, [ ' |', ' `', '-', ' ' ])
		    when MsgCat::DETAILS	# not displayed in tagonly
			text = xmlnode.to_a('para').collect { |xmlpara|
			    fmt_para(do_text(xmlpara, var)) }.join("\n")
			::Text::Formater.lbox(text, [ ' :', ' `', '.', ' ' ])
		    else
			do_text(xmlnode, var)
		    end
		when MyXML::Node::Text
		    xmlnode.value
		else
		    ''
		end
	    end

	    #-- [private] -----------------------------------------------
	    private
	    def fmt_para(text, width=MaxLineLength-7, tag='  ')
		::Text::Formater.paragraph(text, width, tag)
	    end

	    def do_text(xmlnode, var={})
		case xmlnode
		when MyXML::Node::Element
		    case xmlnode.name
		    when 'zcvar', 'zcconst'
			display = xmlnode['display']
			data	= case xmlnode.name
				  when 'zcvar'   then var
				  when 'zcconst' then @const
				  end
			name    = xmlnode['name']
			value	= data.fetch(name)
			case display
			when 'duration'
			    Publisher.to_bind_duration(value.to_i) 
			else
			    value
			end
		    else
			xmlnode.to_a(:child).collect { |xmlchild| 
			    do_text(xmlchild, var) }.join
		    end
		when MyXML::Node::Text
		    xmlnode.value
		else
		    ''
		end
	    end
	end



	##
	## Display progression information about the tests being performed.
	##
	class Progress
	    ##
	    ## Progession bar implementation
	    ## 
	    class PBar
		BarSize	= 37

		def initialize(output, precision)
		    @output	= output
		    @precision	= precision
		    @mutex	= Mutex::new
		    @updater	= nil
		    @l10n_unit	= $mc.get('pgr_speed_unit')
		end
		
		def start(length)
		    @length     = length
		    @starttime  = @lasttime = Time.now
		    @totaltime  = 0
		    @processed	= 0
		    @tick       = 0

		    @output.write $console.ctl['vi']
		    @output.print barstr

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

				@output.write "\r"
				@output.print barstr
				@output.write $console.ctl['ce']
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
		    @output.write "\r" + $console.ctl['ce']
		    @output.flush
		end
		
		def finish
		    @output.write $console.ctl['ve']
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
			bar_s	= '=' * (BarSize * pct / 100) + '>'
			
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
		@counter	= if @publisher.rflag.counter && @o.tty?
				  then PBar::new(@o, 1)
				  else nil
				  end
		@l10n_testing	= $mc.get('word:testing').capitalize
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
	    def process(checkname, ns, ip)
		# Counter
		if @counter
		    @counter.processed(1)
		end

		# Test description
		if @publisher.rflag.testdesc
		    xtra = if    ip then " (IP=#{ip})"
			   elsif ns then " (NS=#{ns})"
			   else          ''
			   end
		    if @publisher.rflag.tagonly
			@o.puts "Testing: #{checkname}#{xtra}"
		    else
			desc = @publisher.xmltrans.apply($mc.get(checkname, 
						MsgCat::CHECK, MsgCat::NAME))
			@o.puts "#{@l10n_testing}: #{desc}#{xtra}"
		    end
		end
	    end
	end

	#------------------------------------------------------------

	def initialize(rflag, option, ostream=$stdout)
	    super(rflag, option, ostream)
	    @progress	= Progress::new(self)
	    @xmltrans	= XMLTransform::new
	end


	#------------------------------------------------------------

	def testdesc(testname, subtype)
	    l10n = @xmltrans.apply($mc.get(testname, MsgCat::CHECK, subtype))
	    case subtype
	    when MsgCat::NAME, MsgCat::FAILURE, MsgCat::SUCCESS
		l10n += "\n"
	    end
	    @o.puts testname + ':'
	    @o.print l10n
	    @o.puts
	end
	
	def error(text)
	    @o.print ::Text::Formater.paragraph(text, MaxLineLength,
					$mc.get('word:error').upcase+': ')
	end


	def intro(domain)
	    return unless @rflag.intro

	    l10n_zone	= $mc.get('ns_zone').upcase
	    l10n_ns	= $mc.get('ns_ns'  ).upcase
	    sz		= [ l10n_zone.length, l10n_ns.length+3 ].max

	    @o.printf "%-*s : %s\n", sz, l10n_zone, domain.name
	    domain.ns.each_index { |i| 
		n = domain.ns[i]
		@o.printf "%-*s : %s [%s]\n", 
		    sz, i == 0 ? "#{l10n_ns} <=" : "#{l10n_ns}  ",
		    n[0].to_s, n[1].join(', ')
	    }
	    @o.puts
	end

	def diag_start()
	end

	def diag_section(title)
	    @o.print ::Text::Formater.title(title, MaxLineLength)
	end

	def diagnostic1(domainname, 
		i_count, i_unexp, w_count, w_unexp, f_count, f_unexp,
		res, severity)

	    i_tag, w_tag, f_tag = 
		severity_description(i_unexp, w_unexp, f_unexp)

	    summary = "%1s%03d %1s%03d %1s%03d" % [ 
		i_tag, i_count, 
		w_tag, w_count, 
		f_tag, f_count ]

	    @o.printf "%-*s    %s\n", 
		MaxLineLength - 4 - summary.length, domainname, summary

	    if !res.nil?
		if @rflag.tagonly
		    @o.puts "  #{res.testname}"
		    @o.puts "  #{severity}: #{res.source || 'generic'}"
		else
		    status      = Config.severity2tag(severity)
		    l10n_status = $mc.get("word:#{status}").capitalize
		    source = res.source || $mc.get('word:generic')
		    msg    = status_message(res.testname, res.desc, severity)
		    @o.puts "  #{msg}"
		    @o.puts "  #{l10n_status}: #{source}"
		end
	    else
		@o.puts "  --", "  --"
	    end
	end

	def diagnostic(severity, testname, desc, lst)
	    # Testname
	    if  desc.check && @rflag.testname && !@rflag.tagonly
		l10n_name = @xmltrans.apply($mc.get(testname, 
					    MsgCat::CHECK, MsgCat::NAME))
		@o.puts "[> #{l10n_name}"
	    end

	    # Status messsage
	    status_tag		= Config.severity2tag(severity)

	    if @rflag.tagonly
		status_shorttag	= severity || Config::Ok
		status = desc.error ? "[Unexpected] #{testname}" : testname
	    else
		status_shorttag	= $mc.get("word:#{status_tag}_id")
		status = status_message(testname, desc, severity)
	    end
	    @o.puts "#{status_shorttag}> #{status}"
	    
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
	    lst.each { |elt| 
		elt ||= (@rflag.tagonly ? 'generic' : $mc.get('word:generic'))
		@o.print ::Text::Formater.item(elt) 
	    }

	    # Blank
	    @o.puts ''
	end
	    

	def status(domainname, i_count, w_count, f_count)
	    @o.puts "==> " + super(domainname, i_count, w_count, f_count)
	end
    end
end
