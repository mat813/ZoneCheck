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

require 'thread'
require 'gtk'
require 'publisher/xpm_data'

module Publisher
    ##
    ##
    ##
    class GTK < Template
	Mime		= nil

	class Output < Gtk::CTree
	    L_H1      = "h1"
	    L_H2      = "h2"
	    L_Zone    = "zone"
	    L_Prim    = "prim"
	    L_Sec     = "sec"
	    L_Root    = "root"
	    L_Element = "element"
	    L_Warning = "warning"
	    L_Info    = "info"
	    L_Fatal   = "fatal"

	    def initialize(*args)
		super(*args)

		winroot = Gdk::Window::foreign_new(Gdk::Window::root_window)
		
		# Build Pixmap
		make_pixmap = Proc::new { |pixmap_data|
		    Gdk::Pixmap::create_from_xpm_d(winroot, style.white,
						   pixmap_data) 
		}
		
		@xpm_book_o	= make_pixmap.call(XPM::Book_closed)
		@xpm_book_c	= make_pixmap.call(XPM::Book_open)
		@xpm_minipage	= make_pixmap.call(XPM::Minipage)
		@xpm_element	= make_pixmap.call(XPM::Element)
		@xpm_reference	= make_pixmap.call(XPM::Reference)
		@xpm_info	= make_pixmap.call(XPM::Info)
		@xpm_warning	= make_pixmap.call(XPM::Warning)
		@xpm_fatal	= make_pixmap.call(XPM::Fatal)
		@xpm_zone	= make_pixmap.call(XPM::Zone)
		@xpm_primary	= make_pixmap.call(XPM::Primary)
		@xpm_secondary	= make_pixmap.call(XPM::Secondary)
	    end

	    def add_node(type, lvl, str, is_leaf, expanded)
		xpm_open, xpm_closed = 
		    case type
		    when L_Zone    then [ @xpm_zone,      @xpm_zone      ]
		    when L_Prim    then [ @xpm_primary,   @xpm_primary   ]
		    when L_Sec     then [ @xpm_secondary, @xpm_secondary ]
		    when L_Element then [ @xpm_element,   @xpm_element   ]
		    when L_Info    then [ @xpm_info,      @xpm_info      ]
		    when L_Warning then [ @xpm_warning,   @xpm_warning   ]
		    when L_Fatal   then [ @xpm_fatal,     @xpm_fatal     ]
		    when L_H1      then [ @xpm_book_o,    @xpm_book_c    ]
		    when L_H2      then [ @xpm_book_o,    @xpm_book_c    ]
		    else                [ @xpm_book_o,    @xpm_book_c    ]
		    end
		sibling = nil
		parent = nil
		insert_node(parent, sibling, [ str ], 5,
			    xpm_open[0],   xpm_open[1], 
			    xpm_closed[0], xpm_closed[1],
			    is_leaf, expanded)
	    end
	end
	
	class Progress < Gtk::Table
	    def initialize(publisher)
		super(2, 5, false)

		l10n_progress = $mc.get("pgr_progress")
		l10n_test   = $mc.get("pgr_test")
		l10n_speed  = $mc.get("pgr_speed")
		l10n_time   = $mc.get("pgr_time")

		lbl_progress= Gtk::Label::new(l10n_progress).set_alignment(0,0.5)
		lbl_test    = Gtk::Label::new(l10n_test ).set_alignment(0.5, 0.5)
		lbl_speed   = Gtk::Label::new(l10n_speed).set_alignment(0.5, 0.5)
		lbl_time    = Gtk::Label::new(l10n_time ).set_alignment(0.5, 0.5)

		set_col_spacings(5)
		set_row_spacings(2)

		

		@pct   = Gtk::Label::new("???")
		@tests = Gtk::Label::new("???")
		@speed = Gtk::Label::new("???")
		@eta   = Gtk::Label::new("???")
		adj    = Gtk::Adjustment::new(0, 1, 100, 0, 0, 0)
		@pbar  = Gtk::ProgressBar::new(adj)
		@tname = Gtk::Label::new("???").set_alignment(0, 0.5)

		attach(lbl_progress, 0, 2, 0, 1, 0, Gtk::SHRINK)
		attach(lbl_test    , 2, 3, 0, 1, 0, Gtk::SHRINK)
		attach(lbl_speed   , 3, 4, 0, 1, 0, Gtk::SHRINK)
		attach(lbl_time    , 4, 5, 0, 1, 0, Gtk::SHRINK)

		attach(@pct        , 0, 1, 1, 2, 0, Gtk::SHRINK)
		attach(@pbar       , 1, 2, 1, 2, 0, Gtk::SHRINK)
		attach(@tests      , 2, 3, 1, 2, 0, Gtk::SHRINK)
		attach(@speed      , 3, 4, 1, 2, 0, Gtk::SHRINK)
		attach(@eta        , 4, 5, 1, 2, 0, Gtk::SHRINK)

		attach(@tname      , 0, 5, 2, 3, Gtk::EXPAND|Gtk::FILL, Gtk::SHRINK)

		@publisher = publisher
		@o = publisher.output

	    end
	    
	    def start(count)
		@count		= count
		@processed	= 0
		@starttime	= Time.now

		if @publisher.rflag.counter
		    @updater = Thread::new { 
			while true ; update_bar ; sleep(1) ; end
		    }
		end

		if @publisher.rflag.testdesc
		    @parent = @publisher.parent
		    @ctree  = @publisher.ctree
		    if ! @publisher.rflag.quiet
			@parent = @ctree.insert_node(@parent, nil, 
						     [$mc.get("title_progress")], 5,
				   @pixmap1, @mask1, @pixmap2, @mask2,
				   false, true)

		    end
		end
	    end
	    
	    def done(desc)
	    end
	    
	    def failed(desc)
	    end
	    
	    def finish
		if @publisher.rflag.counter
		    @updater.kill
		end

		if @publisher.rflag.testdesc
		    @o.puts "</UL>"
		end

		hide_all
	    end
	    
	    def process(desc, ns, ip)
		@processed += 1

		xtra = if    ip then " (IP=#{ip})"
		       elsif ns then " (NS=#{ns})"
		       else          ""
		       end

		if @publisher.rflag.counter
		    pct = 100 * @processed / @count

		    @tname.set_text("#{desc} #{xtra}")
		    @pct  .set_text("%3d%%" % [ pct ])
		    @tests.set_text(@processed.to_s)
		    @pbar.set_value(pct)
		end

		if @publisher.rflag.testdesc
		    @ctree.add_node(Output::L_Element, nil,
				       "#{desc}#{xtra}", true, false)
		end
	    end

	    private
	    def update_bar
		nowtime      = Time.now
		totaltime    = nowtime - @starttime
		
		speed = totaltime <= 1 ? -1.0 : @processed / totaltime
		eta   = speed < 0.0    ? -1   : (@count-@processed) / speed
		
		@speed.set_text(speed_to_str(speed))
		@eta.set_text(sec_to_timestr(eta))
	    end

	    def speed_to_str(speed)
		unit = $mc.get("pgr_speed_unit")

		if speed < 0.0 
		then "--.--#{unit}"
		else "%7.2f#{unit}" % speed
		end
	    end


	    def sec_to_timestr(sec)
		return "--:--" if sec < 0
		
		hrs = sec / 3600; sec %= 3600;
		min = sec / 60;   sec %= 60;
		
		if (hrs > 0)
		    return sprintf("%2d:%02d:%02d", hrs, min, sec)
		else
		    return sprintf("%2d:%02d", min, sec)
		end
	    end
	end


	#------------------------------------------------------------

	attr_reader :ctree, :parent
	attr_reader :xpm_element

	def initialize(rflag, ostream=$stdout)
	    super(rflag, ostream)
	    @progress	= Progress::new(self)

	    # Create default style
	    style = Gtk::Style::new

	    # Create initial windows
	    window = Gtk::Window::new
	    window.realize	# requiered before pixmap creation




	    window.set_title("ZoneCheck result")
	    window.signal_connect("delete_event") {|*args| delete_event(*args) }
	    window.signal_connect("destroy") {|*args| destroy(*args) }
	    window.border_width = 10

	    @output = Gtk::VBox::new(false)
	    



	    scrolled_window = Gtk::ScrolledWindow::new
	    scrolled_window.set_policy(Gtk::POLICY_AUTOMATIC,
				       Gtk::POLICY_ALWAYS)
	    scrolled_window.add_with_viewport(@output);
	    @output.set_focus_vadjustment(scrolled_window.get_vadjustment)


	    #
	    @quit   = Gtk::Button::new($mc.get("w_abort"))
	    @quit_sigclicked = @quit.signal_connect("clicked") { 
		exit EXIT_ABORTED 
	    }

	    @hbbox  = Gtk::HButtonBox::new
	    @hbbox.pack_start(@quit)



	    toto = Gtk::VBox::new(false)
	    toto.pack_start(@progress)
	    toto.pack_start(scrolled_window)
	    toto.pack_start(@hbbox)
	    scrolled_window.set_usize(500, 400)


	    window.add(toto)




	    @ctree = Output::new([ "Tree" ], 0)
	    @ctree.set_row_height(18) # XXX: pixmap / font size
	    @ctree.column_titles_hide
	    @output.pack_start(@ctree)

	    window.show_all
	    
	    Thread::new { Gtk::main() }
	end


	#------------------------------------------------------------


	def setup(domain_name)
	    if ! @rflag.quiet
		@ctree.add_node(Output::L_Root, "root",
				domain_name.to_s, false, true)
#		lbl.set_name("H1")
	    end
	end

	#------------------------------------------------------------


	def intro(domain)
	    parent = @parent

	    # Title
	    unless rflag.quiet
		title = $mc.get("title_zoneinfo")
		@ctree.add_node(Output::L_H1, nil, title, false, true)
	    end

	    # Zone
	    l10n_zone  = $mc.get("ns_zone").capitalize
	    @ctree.add_node(Output::L_Zone, nil,
			    "#{l10n_zone}: #{domain.name.to_s}", true, false)

	    # DNS (Primary / Secondary)
	    domain.ns.each_index { |idx| 
		ns_ip = domain.ns[idx]
		if idx == 0
		    desc = $mc.get("ns_primary").capitalize
		    xpm  = @xpm_primary
		else
		    desc = $mc.get("ns_secondary").capitalize
		    xpm  = @xpm_secondary
		end

		str = "#{desc}: #{ns_ip[0].to_s} (#{ns_ip[1].join(", ")})"
		@ctree.add_node(Output::L_Prim, nil, str, true, false)
	    }
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

	    summary = "%1s%03d&nbsp;%1s%03d&nbsp;%1s%03d" % [ 
		i_tag, i_count, 
		w_tag, w_count, 
		f_tag, f_count ]


	    if @rflag.tagonly
		msg = res.testname
	    else
		msg = res.desc.msg
	    end

	    @o.puts "<DIV class=\"zc_diag1\">"
	    @o.puts "<TABLE width=\"100%\">"
	    @o.puts "<TR class=\"zc_title\"><TD width=\"100%\">#{domainname}</TD><TD>#{summary}</TD></TR>"
	    @o.puts "<TR><TD colspan=\"2\">#{severity}: #{res.tag}</TD></TR>"
	    @o.puts "<TR><TD colspan=\"2\">#{msg}</TD></TR>"
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
		   when "Info"    then Output::L_Info
		   when "Warning" then Output::L_Warning
		   when "Fatal"   then Output::L_Fatal
		   end


	    @ctree.add_node(logo, nil, msg, false, true)


	    if xpl_lst
		@ctree.add_node(Output::L_H1, nil, 
				"Explanation", false, true)

		xpl_lst.each { |t, h, b|
		    l10n_tag = $mc.get("xpltag_#{t}")
		    b.each { |l| l.gsub!(/<URL:([^>]+)>/, '<A href="\1">\1</A>') }
		    @ctree.add_node(Output::L_H1, nil,
				    "#{l10n_tag}: #{h}", false, false)
		    b.each { |l|
			@ctree.add_node(Output::L_H1, nil, l, true, false)
		    }
		}

	    end

	    if ! lst.empty?
		@ctree.add_node(Output::L_H1, nil,
				"Affected host(s)", false, true)
		sibling = nil
		lst.each { |elt| 
		    @ctree.add_node(Output::L_Element, nil, elt, true, false)
		}
	    end

	end
	    

	def status(domainname, i_count, w_count, f_count)
	    unless @rflag.quiet
		l10n_title = $mc.get("title_status")
		@o.puts "<H2>#{l10n_title}</H2>"
	    end
	    @o.print "<DIV class=\"zc_status\">", 
		super(domainname, i_count, w_count, f_count), "</DIV>"
	    @o.puts "<BR>"
	    if @rflag.quiet
		@o.puts "<HR width=\"60%\">"
		@o.puts "<BR>"
	    end
	end


	def end
	    q = Queue::new	# Semaphore

	    # Change "Abort" to "Quit"
	    @quit.signal_disconnect(@quit_sigclicked)
	    @quit.child.text = $mc.get("w_quit")
	    @quit.signal_connect("clicked") { q.push("end") }

	    # Wait...
	    q.pop
	end

	#------------------------------------------------------------

	def h1(h)
	    @ctree.add_node(Output::L_H1, "h1", h.capitalize, false, true)
	end

	def h2(h)
	    @ctree.add_node(Output::L_H2, "h2", h.capitalize, false, true)
	end
    end
end
