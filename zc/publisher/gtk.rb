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



		title = if @publisher.rflag.quiet
			then ""
			else "<H2>" + $mc.get("title_progress") + "</H2>"
			end
		if @publisher.rflag.counter
		    @updater = Thread::new { 
			while true ; update_bar ; sleep(1) ; end
		    }
		end
		if @publisher.rflag.testdesc
		    @o.puts title
		    @o.puts "<UL class=\"zc_test\">"
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
	    end
	    
	    def process(desc, ns, ip)
		@processed += 1

		xtra = if    ip then " (IP=#{ip})"
		       elsif ns then " (NS=#{ns})"
		       else          ""
		       end

		if @publisher.rflag.counter

		    @tname.set_text("#{desc} #{xtra}")
		    pct = 100 * @processed / @count

		    @pct.set_text("%3d%%" % [  pct ])
		    @tests.set_text(@processed.to_s)
		    
		    @pbar.set_value(pct)

		end

		if @publisher.rflag.testdesc
		    @o.puts "<LI>"
		    @o.printf $mc.get("testing_fmt"), "#{desc}#{xtra}"
		    @o.puts "</LI>"
		end
		@o.flush
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

	def initialize(rflag, ostream=$stdout)
	    super(rflag, ostream)
	    @progress	= Progress::new(self)


	    window = Gtk::Window::new
	    window.signal_connect("delete_event") {|*args| delete_event(*args) }
	    window.signal_connect("destroy") {|*args| destroy(*args) }
	    window.border_width = 10
	    window.set_title("ZoneCheck result")


	    @output = Gtk::VBox::new(false)
	    
	    style = Gtk::Style::new

	    scrolled_window = Gtk::ScrolledWindow.new
	    scrolled_window.set_policy(Gtk::POLICY_AUTOMATIC,
				       Gtk::POLICY_ALWAYS)
	    scrolled_window.add_with_viewport(@output);
	    @output.set_focus_vadjustment(scrolled_window.get_vadjustment)

	    toto = Gtk::VBox::new(false)
	    toto.pack_start(@progress)
	    toto.pack_start(scrolled_window)
	    scrolled_window.set_usize(500, 400)


	    window.add(toto)


	    @pixmap1, @mask1 = Gdk::Pixmap::create_from_xpm_d(window.window,
							      style.white,
							      XPM::Book_closed)
	    @pixmap2, @mask2 = Gdk::Pixmap::create_from_xpm_d(window.window,
							      style.white,
							      XPM::Book_open)
	    @pixmap3, @mask3 = Gdk::Pixmap::create_from_xpm_d(window.window,
							      style.white,
							      XPM::Minipage)

	    @xpm_element = Gdk::Pixmap::create_from_xpm_d(window.window,
						       style.white,
						       XPM::Element)

	    @xpm_reference = Gdk::Pixmap::create_from_xpm_d(window.window,
						       style.white,
						       XPM::Reference)

	    @xpm_info = Gdk::Pixmap::create_from_xpm_d(window.window,
						       style.white,
						       XPM::Info)

	    @xpm_info = Gdk::Pixmap::create_from_xpm_d(window.window,
						       style.white,
						       XPM::Info)

	    @xpm_warning = Gdk::Pixmap::create_from_xpm_d(window.window,
						       style.white,
						       XPM::Warning)

	    @xpm_fatal = Gdk::Pixmap::create_from_xpm_d(window.window,
						       style.white,
						       XPM::Fatal)

	    @xpm_zone = Gdk::Pixmap::create_from_xpm_d(window.window,
						       style.white,
						       XPM::Zone)

	    @xpm_primary = Gdk::Pixmap::create_from_xpm_d(window.window,
							  style.white,
							  XPM::Primary)

	    @xpm_secondary = Gdk::Pixmap::create_from_xpm_d(window.window,
							    style.white,
							    XPM::Secondary)


	    @ctree = Gtk::CTree::new([ "Tree" ], 0)
	    @ctree.set_row_height(18) # XXX: pixmap / font size
	    @ctree.column_titles_hide
	    @output.pack_start(@ctree)

	    window.show_all
	    
	    Thread::new { Gtk::main() }
	end


	#------------------------------------------------------------


	def setup(domain_name)
	    if ! @rflag.quiet
		@parent = @ctree.insert_node(nil, nil, [domain_name.to_s], 5,
				   @pixmap1, @mask1, @pixmap2, @mask2,
				   false, true)
#		lbl.set_name("H1")
	    end
	end

	#------------------------------------------------------------


	def intro(domain)
	    parent = nil
	    unless rflag.quiet
		title = $mc.get("title_zoneinfo")
		parent = @ctree.insert_node(@parent, nil, [title], 5,
					    @pixmap1, @mask1, @pixmap2, @mask2,
					    false, true)
#		lbl.set_name("H2")
	    end


	    
	    l10n_zone  = $mc.get("ns_zone").capitalize
	    
	    @ctree.insert_node(parent, nil, [ "#{l10n_zone}: #{domain.name.to_s}"], 5,
					nil, nil, @xpm_zone[0], @xpm_zone[1],
					false, true)



	    domain.ns.each_index { |idx| 
		ns_ip = domain.ns[idx]
		if idx == 0
		    name = "ns_prim"
		    desc = $mc.get("ns_primary").capitalize
		    pxm  = [ nil, nil, *@xpm_primary ]
		else
		    name = "ns_sec"
		    desc = $mc.get("ns_secondary").capitalize
		    pxm  = [ nil, nil, *@xpm_secondary ]
		end

		str = "#{desc}: #{ns_ip[0].to_s} (#{ns_ip[1].join(", ")})"
		@ctree.insert_node(parent, nil, [ str ], 5,
				   pxm[0], pxm[1], pxm[2], pxm[3], false, true)

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
	    
	    case severity
	    when "Warning"
		pxm = [ @xpm_warning[0], @xpm_warning[1], @xpm_warning[0], @xpm_warning[1] ]
	    when "Info"
		pxm = [ @xpm_info[0], @xpm_info[1], @xpm_info[0], @xpm_info[1] ]
	    when "Fatal"
		pxm = [ @xpm_fatal[0], @xpm_fatal[1], @xpm_fatal[0], @xpm_fatal[1] ]
	    end


	    parent = @ctree.insert_node(@parent, nil, [msg], 5,
					pxm[0], pxm[1], pxm[2], pxm[3],
					false, true)


	    if xpl_lst
		xpl_parent = @ctree.insert_node(parent, nil, 
						["Explanation"], 5,
						@pixmap1, @mask1, @pixmap2, @mask2,
						false, true)
		ref_sibling = nil

		xpl_lst.each { |t, h, b|
		    l10n_tag = $mc.get("xpltag_#{t}")
		    b.each { |l| l.gsub!(/<URL:([^>]+)>/, '<A href="\1">\1</A>') }
		    ref_sibling = @ctree.insert_node(xpl_parent, ref_sibling, 
						     [ "#{l10n_tag}: #{h}" ], 5,
						     @xpm_reference[0], @xpm_reference[1], @xpm_reference[0], @xpm_reference[1], 

						     false, false)
		    b.each { |l|
			@ctree.insert_node(ref_sibling, nil,
					   [ l ], 5, 
					   nil, nil, nil, nil,
					   true, false)
		    }
		}

	    end

	    if ! lst.empty?
		parent = @ctree.insert_node(parent, nil, ["Affected host(s)"], 5,
					@pixmap1, @mask1, @pixmap2, @mask2,
					    false, true)
		sibling = nil
		lst.each { |elt| 
		    @ctree.insert_node(parent, nil, [elt], 5,
				       @xpm_element[0], @xpm_element[1], nil, nil,
				       true, false)
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

	    sleep(60)
	end



	#------------------------------------------------------------

	def h1(h)
	    @h1 = @parent = @ctree.insert_node(@parent, nil, [ h.capitalize ], 5,
					 @pixmap1, @mask1, @pixmap2, @mask2,
					 false, true)
	end

	def h2(h)
	    parent = @h1.nil? ? @parent : @h1
	    @h2 = @parent = @ctree.insert_node(parent, nil, [ h.capitalize ], 5,
					 @pixmap1, @mask1, @pixmap2, @mask2,
					 false, true)
	end
    end
end
