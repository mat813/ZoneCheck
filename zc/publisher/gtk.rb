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
    
require 'thread'
require 'gtk2'
require 'publisher/xpm_data'

Gtk.init


module Publisher
    ##
    ##
    ##
    class GTK < Template
	Mime		= nil

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

	    def initialize
		@model = Gtk::TreeStore.new( String )

		super(@model)

# Create the renderer and set properties
render = Gtk::CellRendererText.new
render.set_property( "background", "black" )
render.set_property( "foreground", "green" )

# Create the columns
@c1 = Gtk::TreeViewColumn.new( "Headings", render, {:text => 0} )

append_column( @c1 )

		@hh = Hash::new
		
		# Build Pixmap
		winroot = Gdk::Window::default_root_window
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
		@xpm_none	= [ nil, nil ]
	    end

	    def forget_level(*lvl)
		lvl.each { |l| @hh.delete(l) }
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
		    when L_None    then [ @xpm_none,      @xpm_none      ]
		    when L_Ref     then [ @xpm_reference, @xpm_reference ]
		    else                [ @xpm_book_o,    @xpm_book_c    ]
		    end
		sibling = nil

		pparent2 = if lvl.nil? || !@hh.has_key?(lvl)
			   then @parent2
			   else @hh[lvl]
			   end

		
#		parent2 = insert_node(pparent2, sibling, [ str ], 5,
#				     xpm_open[0],   xpm_open[1], 
#				     xpm_closed[0], xpm_closed[1],
#				     is_leaf, expanded)
		parent2 = @model.append(pparent2)
		parent2.set_value(0, str)

		case lvl
		when NilClass
		when String
		    @hh[lvl] = pparent2
		    @parent2 = is_leaf ? pparent2 : parent2
		end
	    end
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
		    @o.collapse(@node)
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
		    @o.add_node(Output::L_Element, "testdesc",
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

	attr_reader :parent
	attr_reader :xpm_element

	def initialize(rflag, ostream=$stdout)
	    super(rflag, ostream)

	    # Create default style
	    style = Gtk::Style::new

	    # Create initial windows
	    window = Gtk::Window::new
	    window.set_title("ZoneCheck result")
	    window.signal_connect("delete_event") {|*args| delete_event(*args) }
	    window.signal_connect("destroy") {|*args| destroy(*args) }
	    window.border_width = 10




	    @output = Gtk::VBox::new(false)
	    



	    scroller = Gtk::ScrolledWindow::new
	    scroller.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_ALWAYS)



	    #
	    @quit   = Gtk::Button::new($mc.get("w_abort"))
	    @quit_sigclicked = @quit.signal_connect("clicked") { 
		exit EXIT_ABORTED 
	    }

	    @hbbox  = Gtk::HButtonBox::new
	    @hbbox.pack_start(@quit)

	    @o = Output::new



	    @progress	= Progress::new(self)

	    toto = Gtk::VBox::new(false)
	    toto.pack_start(@progress)
	    toto.pack_start(scroller)
	    toto.pack_start(@hbbox)
	    scroller.set_size_request(500, 400)


	    window.add(toto)

#	    @output.pack_start(@o)


	    window.show_all
	    
	    Thread::new { Gtk::main() }

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
	    # Title
	    unless @rflag.quiet
		@o.add_node(Output::L_H1, "h1", 
			    $mc.get("title_zoneinfo"), false, true)
	    end

	    # Zone
	    @o.add_node(Output::L_Zone, "zoneinfo",
			"#{domain.name.to_s}", true, false)

	    # DNS (Primary / Secondary)
	    domain.ns.each_index { |idx| 
		ns_ip = domain.ns[idx]
		logo = if idx == 0
		       then Output::L_Prim
		       else Output::L_Sec
		       end

		str = "#{ns_ip[0].to_s} (#{ns_ip[1].join(", ")})"
		@o.add_node(logo, "zoneinfo", str, true, false)
	    }
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

	    summary = "%1s%03d&nbsp;%1s%03d&nbsp;%1s%03d" % [ 
		i_tag, i_count, 
		w_tag, w_count, 
		f_tag, f_count ]


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
		   when "Info"    then Output::L_Info
		   when "Warning" then Output::L_Warning
		   when "Fatal"   then Output::L_Fatal
		   else raise RuntimError, "XXX: unknown severity: #{severity}"
		   end


	    @o.add_node(logo, "diagnostic", msg, false, !@rflag.quiet)
	    @o.forget_level("diag_details", "diag_ref", "diag_elt")

	    # Explanation
	    if xpl_lst
		if @rflag.quiet
		    lvl = "diag_elt"
		else
		    @o.add_node(Output::L_H1, "diag_details", 
				    "Explanation", false, false)
		    lvl = "diag_ref"
		end

		xpl_lst.each { |t, h, b|
		    l10n_tag = $mc.get("xpltag_#{t}")
		    b.each { |l| l.gsub!(/<URL:([^>]+)>/, '\1') }
		    @o.add_node(Output::L_Ref, lvl,
				    "#{l10n_tag}: #{h}", false, false)
		    b.each { |l|
			@o.add_node(Output::L_None, nil, l, true, false)
		    }
		}
	    end

	    # Elements
	    if ! lst.empty?
		if @rflag.quiet
		    lvl = "diag_elt"
		else
		    @o.add_node(Output::L_H1, "diag_details",
				"Affected host(s)", false, true)
		    lvl = nil
		end

		lst.each { |elt| 
		    @o.add_node(Output::L_Element, lvl, elt, true, false)
		}
	    end

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
	    @quit.child.text = $mc.get("w_quit")
	    @quit.signal_connect("clicked") { q.push("end") }

	    # Wait...
	    q.pop
	end

	#------------------------------------------------------------

	def h1(h)
	    @o.add_node(Output::L_H1, "h1", h.capitalize, false, true)
	end

	def h2(h)
	    @o.add_node(Output::L_H2, "h2", h.capitalize, false, true)
	    @o.forget_level("diagnostic")
	end
    end
end
