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
# CONTRIBUTORS: (see also CREDITS file)
#
#
    
require 'thread'
require 'gtk2'
require 'textfmt'
require 'data/xpm'

Gtk.init


module Publisher
    ##
    ##
    ##
    class GTK < Template
	Mime		= nil

	class LeaveButton < Gtk::Button
	    QUIT  = 1
	    ABORT = 2
	    def initialize
                hbox  = Gtk::HBox::new(false)
                hbox.pack_start(Gtk::Image::new(Gtk::Stock::QUIT), 
				false, false, 2)
                hbox.pack_start(Gtk::Label::new($mc.get("w_quit").capitalize),
				false, false, 0)
		@quit = Gtk::Alignment::new(0.5, 0.5, 0, 0)
		@quit.child = hbox

                hbox = Gtk::HBox::new(false)
                hbox.pack_start(Gtk::Image::new(Gtk::Stock::CANCEL), 
				false, false, 2)
                hbox.pack_start(Gtk::Label::new($mc.get("w_abort").capitalize),
				false, false, 0)
		@abort = Gtk::Alignment::new(0.5, 0.5, 0, 0)
		@abort.child = hbox

		super()
		self.child = @quit
		self
	    end
	    
	    def set_face(face)
	    end
	end

	class PixmapAlbum
	    def initialize
		@pixmap = {}
	    end

	    def put(name, xpm_data)
		winroot = Gdk::Window::default_root_window
		@pixmap[name] = Gdk::Pixmap::create_from_xpm_d(winroot, nil,
							       xpm_data)
	    end

	    def [](name)
		@pixmap[name]
	    end
	end


	class Intro < Gtk::Table
	    def initialize(main, domain)
		# Initialize widget
		super(2, 3, false)
		set_col_spacings(5)
		set_row_spacings(2)
		
		# Zone
		img      = Gtk::Image::new(*main.pixmap[:zone])
		zone_str = Gtk::Label::new(domain.name.to_s)
		zone_str .set_alignment(0, 0.5)
		attach(img,      0, 1, 0, 1, Gtk::SHRINK, Gtk::SHRINK)
		attach(zone_str, 1, 3, 0, 1, Gtk::FILL,   Gtk::SHRINK)

		# DNS (Primary / Secondary)
		domain.ns.each_index { |idx| 
		    ns_ip = domain.ns[idx]
		    img   = if idx == 0
			    then Gtk::Image::new(*main.pixmap[:primary])
			    else Gtk::Image::new(*main.pixmap[:secondary])
			    end
		    name_str = Gtk::Label::new(ns_ip[0].to_s)
		    name_str .set_alignment(0, 0.5)
		    ips_str  = Gtk::Label::new(ns_ip[1].join(", "))
		    ips_str  .set_alignment(0, 0.5)

		    attach(img,      0, 1, idx+1, idx+2, 
			   Gtk::SHRINK, Gtk::SHRINK)
		    attach(name_str, 1, 2, idx+1, idx+2,
			   Gtk::FILL,   Gtk::SHRINK)
		    attach(ips_str,  2, 3, idx+1, idx+2,
			   Gtk::FILL,   Gtk::SHRINK)
		}

		#
		show_all
	    end
	end

	class ItemList < Gtk::Table
	    def initialize(main)
		@main = main
		super(0, 2, false)
		set_col_spacings(5)
		set_row_spacings(2)
		show
		@idx = 0
	    end

	    def add_item(str)
		img = Gtk::Image::new(*@main.pixmap[:element])
		lbl = Gtk::Label::new(str)
		lbl.set_alignment(0, 0.5)
		img.show
		lbl.show
		attach(img, 0, 1, @idx, @idx+1, Gtk::SHRINK, Gtk::SHRINK)
		attach(lbl, 1, 2, @idx, @idx+1, Gtk::FILL,   Gtk::SHRINK)
		@idx += 1
	    end
	end



	class Out < Gtk::VBox
	    def initialize
		super(false)
		
	    end
	    def add(child)
		pack_start(child)
		set_child_packing(child, false, false, 5, Gtk::PACK_START)
	    end
		
	    def add_node(*args)
	    end
	    def forget_level(*args)
	    end
	end


	##
	##
	##
	class Output < Gtk::TreeView
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
	    L_None    = "none"
	    L_Ref     = "reference"
	end
	
	##
	## Class for displaying progression information about
	## the tests being performed.
	##
	class Progress < Gtk::Table
	    # Initialization
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
		@pbar  = Gtk::ProgressBar::new
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
	    
	    # Start progression
	    def start(count)
		@count		= count
		@processed	= 0
		@starttime	= Time.now

		# Counter
		if @publisher.rflag.counter
		    @updater = Thread::new { 
			while true ; update_bar ; sleep(1) ; end
		    }
		end

		# Test description
		if @publisher.rflag.testdesc
		    if ! @publisher.rflag.quiet
			@node = @o.add_node(Output::L_H1, "h1", 
					$mc.get("title_progress"), false, true)
			@il = ItemList::new(@publisher)
			@o.add(@il)
		    end
		end
	    end
	    
	    # Finished on success
	    def done(desc)
	    end
	    
	    # Finished on failure
	    def failed(desc)
	    end
	    
	    # Finish (finalize) output
	    def finish
		# Counter
		if @publisher.rflag.counter
		    @updater.kill
		end

		# Test description
		if @publisher.rflag.testdesc && !@node.nil?
#		    @o.collapse(@node)
		end

		hide_all
	    end
	    
	    # Process an item
	    def process(desc, ns, ip)
		@processed += 1

		xtra = if    ip then " (IP=#{ip})"
		       elsif ns then " (NS=#{ns})"
		       else          ""
		       end

		# Counter
		if @publisher.rflag.counter
		    pct = 100 * @processed / @count

		    @tname.set_text("#{desc} #{xtra}")
		    @pct  .set_text("%3d%%" % [ pct ])
		    @tests.set_text(@processed.to_s)
		    @pbar .adjustment.set_value(pct)
		end

		# Test description
		if @publisher.rflag.testdesc
		    puts "#{desc}#{xtra}"
		    @il.add_item("#{desc}#{xtra}")
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
		then sprintf("%2d:%02d:%02d", hrs, min, sec)
		else sprintf("%2d:%02d", min, sec)
		end
	    end
	end


	#------------------------------------------------------------


	attr_reader :pixmap

	def initialize(rflag, ostream=$stdout)
	    super(rflag, ostream)

	    #
	    Thread::new { Gtk::main() }

	    # Create pixmap album
	    @pixmap = PixmapAlbum::new
	    @pixmap.put(:book_closed,	ZCData::XPM::Book_closed)
	    @pixmap.put(:book_open,	ZCData::XPM::Book_open)
	    @pixmap.put(:minipage,	ZCData::XPM::Minipage)
	    @pixmap.put(:element,	ZCData::XPM::Element)
	    @pixmap.put(:reference,	ZCData::XPM::Reference)
	    @pixmap.put(:gear,		ZCData::XPM::Gear)
	    @pixmap.put(:detail,	ZCData::XPM::Detail)
	    @pixmap.put(:info,		ZCData::XPM::Info)
	    @pixmap.put(:warning,	ZCData::XPM::Warning)
	    @pixmap.put(:fatal,		ZCData::XPM::Fatal)
	    @pixmap.put(:zone,		ZCData::XPM::Zone)
	    @pixmap.put(:primary,	ZCData::XPM::Primary)
	    @pixmap.put(:secondary,	ZCData::XPM::Secondary)


	    # Create initial windows
	    window = Gtk::Window::new
	    window.set_title("ZoneCheck result")
	    window.signal_connect("delete_event") {|*args| delete_event(*args) }
	    window.signal_connect("destroy") {|*args| destroy(*args) }
	    window.border_width = 10




	    @o = @output = Out::new
#	    @output.set_homogeneous(false)
	    


	    scroller = Gtk::ScrolledWindow::new
	    scroller.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_ALWAYS)



	    #
	    @quit   = LeaveButton::new
	    @quit_sigclicked = @quit.signal_connect("clicked") { 
		exit EXIT_ABORTED 
	    }

	    @hbbox  = Gtk::HButtonBox::new
	    @hbbox.pack_start(@quit)


	    @progress	= Progress::new(self)

	    toto = Gtk::VBox::new(false)
	    toto.pack_start(@progress)
	    toto.pack_start(scroller)
	    toto.pack_start(@hbbox)

	    scroller.add_with_viewport(@output)
	    scroller.set_size_request(600, 400)
	    

	    window.add(toto)


	    window.show_all




	end


	#------------------------------------------------------------


	def setup(domain_name)
	    if ! @rflag.quiet
		@o.add_node(Output::L_Root, "root", 
			    domain_name.to_s, false, true)
	    end
	end

	#------------------------------------------------------------


	def intro(domain)
	    return unless @rflag.intro

	    @o.add(Intro::new(self, domain))

	    # Title
#	    unless @rflag.quiet
#		@o.add_node(Output::L_H1, "h1", 
#			    $mc.get("title_zoneinfo"), false, true)
#	    end
	end

	def diag_start()
	    @o.add_node(Output::L_H1, "h1", $mc.get("title_testres"), false, true)
	end

	def diag_section(title)
	    if !@rflag.quiet
		@o.add_node(Output::L_H2, "h2", title.capitalize, false, true)
		@o.forget_level("diagnostic")
	    end
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

	    # Initialize widget
	    tbl = Gtk::Table::new(3, 7, false)
	    tbl.set_col_spacings(5)
	    tbl.set_row_spacings(2)
		

	    # Zone
	    i_img = Gtk::Image::new(*self.pixmap[:info])
	    w_img = Gtk::Image::new(*self.pixmap[:warning])
	    f_img = Gtk::Image::new(*self.pixmap[:fatal])
	    i_lbl = Gtk::Label::new("%03d"  % i_count).set_alignment(0, 0.5)
	    w_lbl = Gtk::Label::new("%03d"  % w_count).set_alignment(0, 0.5)
	    f_lbl = Gtk::Label::new("%03d"  % f_count).set_alignment(0, 0.5)
	    d_lbl = Gtk::Label::new(domainname.to_s).set_alignment(0, 0.5)
	    tbl.attach(d_lbl, 0, 1, 0, 1, Gtk::EXPAND | Gtk::FILL,   Gtk::SHRINK)
	    tbl.attach(i_img, 1, 2, 0, 1, Gtk::SHRINK, Gtk::SHRINK)
	    tbl.attach(i_lbl, 2, 3, 0, 1, Gtk::SHRINK, Gtk::SHRINK)
	    tbl.attach(w_img, 3, 4, 0, 1, Gtk::SHRINK, Gtk::SHRINK)
	    tbl.attach(w_lbl, 4, 5, 0, 1, Gtk::SHRINK, Gtk::SHRINK)
	    tbl.attach(f_img, 5, 6, 0, 1, Gtk::SHRINK, Gtk::SHRINK)
	    tbl.attach(f_lbl, 6, 7, 0, 1, Gtk::SHRINK, Gtk::SHRINK)


	    

	    #
	    tbl.show_all
	    
	    @o.add(tbl)

	    if @rflag.tagonly
		msg = res.testname
	    else
		msg = res.desc.msg
	    end

#	    @o.puts "<DIV class=\"zc_diag1\">"
#	    @o.puts "<TABLE width=\"100%\">"
#	    @o.puts "<TR class=\"zc_title\"><TD width=\"100%\">#{domainname}</TD><TD>#{summary}</TD></TR>"
#	    @o.puts "<TR><TD colspan=\"2\">#{severity}: #{res.tag}</TD></TR>"
#	    @o.puts "<TR><TD colspan=\"2\">#{msg}</TD></TR>"
#	    @o.puts "</TABLE>"
#	    @o.puts "</DIV>"
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
		   when Config::Info    then :info
		   when Config::Warning then :warning
		   when Config::Fatal   then :fatal
		   else raise RuntimError, "XXX: unknown severity: #{severity}"
		   end


	    dtbl = Gtk::Table::new(1, 2, false)
	    dtbl.set_col_spacings(5)
	    dtbl.set_row_spacings(2)
	    didx  = 0

	    img = Gtk::Image::new(*self.pixmap[logo])
	    lbl = Gtk::Label::new(msg)
	    lbl.set_alignment(0, 0.5)
	    dtbl.attach(img, 0, 1, didx, didx+1, Gtk::SHRINK, Gtk::SHRINK)
	    dtbl.attach(lbl, 1, 2, didx, didx+1, Gtk::FILL,   Gtk::SHRINK)
	    didx += 1

	    # Details
	    if @rflag.details && desc.dtl
		txt = ::Text::Format::new
		txt.width = 72
		txt.tag   = ""
		str = txt.format(desc.dtl)
		str.chop!
		tbl = Gtk::Table::new(0, 2, false)
		tbl.set_col_spacings(5)
		tbl.set_row_spacings(2)
		img = Gtk::Image::new(*self.pixmap[:detail])
		lbl = Gtk::Label::new(str)
		lbl.set_alignment(0, 0.5)
		tbl.attach(img, 0, 1, 0, 1, Gtk::SHRINK, Gtk::SHRINK)
		tbl.attach(lbl, 1, 2, 0, 1, Gtk::FILL,   Gtk::SHRINK)
		dtbl.attach(tbl, 1, 2, didx, didx+1, Gtk::FILL, Gtk::SHRINK)
		didx += 1
	    end


	    # Explanation
	    if xpl_lst
		tbl = Gtk::Table::new(0, 2, false)
		tbl.set_col_spacings(5)
		tbl.set_row_spacings(2)
		idx = 0
		xpl_lst.each { |t, h, b|
		    l10n_tag = $mc.get("tag_#{t}")
		    b.each { |l| l.gsub!(/<URL:([^>]+)>/, '\1') }
		    img = Gtk::Image::new(*self.pixmap[:reference])
		    lbl = Gtk::Label::new("#{l10n_tag}: #{h}")
		    lbl.set_alignment(0, 0.5)
		    tbl.attach(img, 0, 1, idx, idx+1, Gtk::SHRINK, Gtk::SHRINK)
		    tbl.attach(lbl, 1, 2, idx, idx+1, Gtk::FILL,   Gtk::SHRINK)
		    idx += 1
		    lbl = Gtk::Label::new(b.join("\n"))
		    lbl.set_alignment(0, 0.5)
		    tbl.attach(lbl, 1, 2, idx, idx+1, Gtk::FILL,   Gtk::SHRINK)
		    idx += 1
		}
		dtbl.attach(tbl, 1, 2, didx, didx+1, Gtk::FILL, Gtk::SHRINK)
		didx += 1
	    end

	    # Elements
	    if ! lst.empty?
		tbl = Gtk::Table::new(0, 2, false)
		tbl.set_col_spacings(5)
		tbl.set_row_spacings(2)
		lst.each_index { |idx| 
		    img = Gtk::Image::new(*self.pixmap[:element])
		    lbl = Gtk::Label::new(lst[idx])
		    lbl.set_alignment(0, 0.5)
		    tbl.attach(img, 0, 1, idx, idx+1, Gtk::SHRINK, Gtk::SHRINK)
		    tbl.attach(lbl, 1, 2, idx, idx+1, Gtk::FILL,   Gtk::SHRINK)
		}
		dtbl.attach(tbl, 1, 2, didx, didx+1, Gtk::FILL, Gtk::SHRINK)
		didx += 1
	    end

	    @o.add(dtbl)
	    dtbl.show_all
	end
	    

	def status(domainname, i_count, w_count, f_count)
	    unless @rflag.quiet
		l10n_title = $mc.get("title_status")
		@o.add_node(Output::L_H1, "h1", l10n_title, false, true)
	    end
	    @o.add_node(Output::L_H2, nil,  
		super(domainname, i_count, w_count, f_count), true, false)

#	    if @rflag.quiet
#		@o.puts "<HR width=\"60%\">"
#		@o.puts "<BR>"
#	    end
	end


	def end
	    q = Queue::new	# Semaphore

	    # Change "Abort" to "Quit"
	    @quit.signal_handler_disconnect(@quit_sigclicked)
	    @quit.set_face(LeaveButton::QUIT)
#	    @quit.child.text = $mc.get("w_quit")
	    @quit.signal_connect("clicked") { q.push("end") }

	    # Wait...
	    q.pop
	end

	#------------------------------------------------------------

	def h2(h)
	    @o.add_node(Output::L_H2, "h2", h.capitalize, false, true)
	    @o.forget_level("diagnostic")
	end
    end
end
