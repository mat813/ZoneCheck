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


$book_open_xpm = [
  "16 16 4 1",
  "       c None s None",
  ".      c black",
  "X      c #808080",
  "o      c white",
  "                ",
  "  ..            ",
  " .Xo.    ...    ",
  " .Xoo. ..oo.    ",
  " .Xooo.Xooo...  ",
  " .Xooo.oooo.X.  ",
  " .Xooo.Xooo.X.  ",
  " .Xooo.oooo.X.  ",
  " .Xooo.Xooo.X.  ",
  " .Xooo.oooo.X.  ",
  "  .Xoo.Xoo..X.  ",
  "   .Xo.o..ooX.  ",
  "    .X..XXXXX.  ",
  "    ..X.......  ",
  "     ..         ",
  "                " ]

$book_closed_xpm = [
  "16 16 6 1",
  "       c None s None",
  ".      c black",
  "X      c red",
  "o      c yellow",
  "O      c #808080",
  "#      c white",
  "                ",
  "       ..       ",
  "     ..XX.      ",
  "   ..XXXXX.     ",
  " ..XXXXXXXX.    ",
  ".ooXXXXXXXXX.   ",
  "..ooXXXXXXXXX.  ",
  ".X.ooXXXXXXXXX. ",
  ".XX.ooXXXXXX..  ",
  " .XX.ooXXX..#O  ",
  "  .XX.oo..##OO. ",
  "   .XX..##OO..  ",
  "    .X.#OO..    ",
  "     ..O..      ",
  "      ..        ",
  "                " ]

$mini_page_xpm = [
  "16 16 4 1",
  "       c None s None",
  ".      c black",
  "X      c white",
  "o      c #808080",
  "                ",
  "   .......      ",
  "   .XXXXX..     ",
  "   .XoooX.X.    ",
  "   .XXXXX....   ",
  "   .XooooXoo.o  ",
  "   .XXXXXXXX.o  ",
  "   .XooooooX.o  ",
  "   .XXXXXXXX.o  ",
  "   .XooooooX.o  ",
  "   .XXXXXXXX.o  ",
  "   .XooooooX.o  ",
  "   .XXXXXXXX.o  ",
  "   ..........o  ",
  "    oooooooooo  ",
  "                " ]


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

		attach(lbl_progress, 0, 2, 0, 1)
		attach(lbl_test    , 2, 3, 0, 1)
		attach(lbl_speed   , 3, 4, 0, 1)
		attach(lbl_time    , 4, 5, 0, 1)

		attach(@pct        , 0, 1, 1, 2)
		attach(@pbar       , 1, 2, 1, 2)
		attach(@tests      , 2, 3, 1, 2)
		attach(@speed      , 3, 4, 1, 2)
		attach(@eta        , 4, 5, 1, 2)

		attach(@tname      , 0, 5, 2, 3)

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

	    toto = Gtk::VBox::new
	    toto.add(@progress)

	    @output = Gtk::VBox::new
	    
	    style = Gtk::Style::new

	    scrolled_window = Gtk::ScrolledWindow.new
	    scrolled_window.set_policy(Gtk::POLICY_NEVER,
				       Gtk::POLICY_AUTOMATIC)
	    scrolled_window.add_with_viewport(@output);
	    @output.set_focus_vadjustment(scrolled_window.get_vadjustment)

	    toto.add(scrolled_window)



	    window.add(toto)
	    window.realize

	    @pixmap1, @mask1 = Gdk::Pixmap::create_from_xpm_d(window.window,
							      style.white,
							      $book_closed_xpm)
	    @pixmap2, @mask2 = Gdk::Pixmap::create_from_xpm_d(window.window,
							      style.white,
							      $book_open_xpm)
	    @pixmap3, @mask3 = Gdk::Pixmap::create_from_xpm_d(window.window,
							      style.white,
							      $mini_page_xpm)

	    window.show_all
	    
	    Thread::new { Gtk::main() }
	end


	#------------------------------------------------------------


	def setup(domain_name)
	    if ! @rflag.quiet
		lbl = Gtk::Label::new("ZoneCheck: #{domain_name}")
		lbl.set_alignment(0, 0.5)
		lbl.set_name("H1")
		lbl.show_all
		@output.pack_start(lbl)
	    end
	end

	#------------------------------------------------------------


	def intro(domain)
	    unless rflag.quiet
		lbl = Gtk::Label::new($mc.get("title_zoneinfo"))
		lbl.set_alignment(0, 0.5)
		lbl.set_name("H2")
		lbl.show_all
		@output.pack_start(lbl)
	    end


	    tbl = Gtk::Table::new(1, 3, false)
	    tbl.set_col_spacings(5)
	    tbl.set_row_spacings(2)
	    
	    l10n_zone  = $mc.get("ns_zone").capitalize
	    lbl_zone   = Gtk::Label::new(l10n_zone)
	    lbl_zone.set_alignment(0, 0.5)
	    lbl_domain = Gtk::Label::new(domain.name.to_s)
	    lbl_domain.set_alignment(0, 0.5)
	    
	    i = 0

	    tbl.attach(lbl_zone,   0, 1, i, i+1)
	    tbl.attach(lbl_domain, 1, 3, i, i+1)

	    i += 1


	    domain.ns.each_index { |idx| 
		ns_ip = domain.ns[idx]
		if idx == 0
		    name = "ns_prim"
		    desc = $mc.get("ns_primary").capitalize
		else
		    name = "ns_sec"
		    desc = $mc.get("ns_secondary").capitalize
		end

		lbl_desc = Gtk::Label::new(desc)
		lbl_desc.set_alignment(0, 0.5)
		lbl_desc.set_name(name)
		lbl_ns   = Gtk::Label::new(ns_ip[0].to_s)
		lbl_ns.set_alignment(0, 0.5)
		lbl_ips  = Gtk::Label::new(ns_ip[1].join(", "))
		lbl_ips.set_alignment(0, 0.5)

		tbl.attach(lbl_desc, 0, 1, i, i+1)
		tbl.attach(lbl_ns  , 1, 2, i, i+1)
		tbl.attach(lbl_ips , 2, 3, i, i+1)
		i += 1
	    }

	    tbl.show_all

	    @output.pack_start(tbl)
	    
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
	    if @ctree.nil?
		@ctree = Gtk::CTree::new([ "Tree" ], 0)
		@ctree.column_titles_hide
	    @ctree.show_all
		
		@output.pack_start(@ctree)
	    end
	    
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
	    
	    parent = @ctree.insert_node(nil, nil, [msg], 5,
					@pixmap1, @mask1, @pixmap2, @mask2,
					false, true)

	    @o.puts "<DIV class=\"zc_diag\">"
	    @o.puts "<DIV class=\"zc_title\">#{msg}</DIV>"

	    if xpl_lst
		parent = @ctree.insert_node(parent, nil, ["Explanation"], 5,
					   @pixmap1, @mask1, @pixmap2, @mask2,
					   false, true)
		sibling = nil

		@o.puts "<UL class=\"zc_ref\">"
		xpl_lst.each { |t, h, b|
		    l10n_tag = $mc.get("xpltag_#{t}")
		    b.each { |l| l.gsub!(/<URL:([^>]+)>/, '<A href="\1">\1</A>') }
		    sibling = @ctree.insert_node(parent, sibling, [ "#{l10n_tag}: #{h}\n" + b.join("\n")], 5,
						@pixmap3, @mask3, nil, nil,
						true, false)


		    @o.puts "<LI>"
		    @o.puts "<SPAN class=\"zc_ref\">#{l10n_tag}: #{h}</SPAN>"
		    @o.puts "<BR>"
		    @o.puts b.join(" ")
		    @o.puts "</LI>"
		}
		puts "</UL>"
	    end

	    if ! lst.empty?
		parent = @ctree.insert_node(parent, nil, ["Affected host(s)"], 5,
					    @pixmap3, @mask3, nil, nil,
					    false, true)
		sibling = nil
		lst.each { |elt| 
		sibling = @ctree.insert_node(parent, sibling, [elt], 5,
					    @pixmap3, @mask3, nil, nil,
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
	    puts "H1"
	    lbl = Gtk::Label::new(h.capitalize)
	    lbl.set_alignment(0, 0.5)
	    lbl.set_name("H2")
	    lbl.show_all
	    @output.pack_start(lbl)
	end

	def h2(h)
	    puts "H2"
	    lbl = Gtk::Label::new("---- #{h.capitalize} ----")
	    lbl.set_alignment(0, 0.5)
	    lbl.set_name("H3")
	    lbl.show_all
	    @output.pack_start(lbl)
	end
    end
end
