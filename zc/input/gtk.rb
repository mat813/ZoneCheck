# $Id$

# 
# AUTHOR : Stephane D'Alu <sdalu@nic.fr>
# CREATED: 2002/10/16 18:58:17
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS:
#
#

require 'getoptlong'
require 'thread'

require 'gtk2'
require 'ext/gtk'
require 'data/xpm'

Gtk.init

module Input
    ##
    ## Processing parameters from GTK
    ##
    class GTK
	MaxNS = 8

	##
	## Expert
	##
	class Expert < Gtk::VBox
	    def initialize(main)
		# Parent constructor
		super()
		
		# Localisation
		l10n_debug	= $mc.get("iface_label_debug")
		l10n_output	= $mc.get("iface_label_output")
		l10n_advanced	= $mc.get("iface_label_advanced")

		# Debug
		debug_f = Gtk::Frame::new(l10n_debug)

		i, j = 0, 0
		tbl = Gtk::Table::new(1, 3, true)
		[   [ :d_loading,    "iface_dbg_loading",    DBG::LOADING    ],
		    [ :d_locale,     "iface_dbg_locale",     DBG::LOCALE     ],
		    [ :d_config,     "iface_dbg_config",     DBG::CONFIG     ],
		    [ :d_parser,     "iface_dbg_parser",     DBG::PARSER     ],
		    [ :d_tests,      "iface_dbg_tests",      DBG::TESTS      ],
		    [ :d_autoconf,   "iface_dbg_autoconf",   DBG::AUTOCONF   ],
		    [ :d_dbg,        "iface_dbg_dbg",        DBG::DBG        ],
		    [ :d_cache_info, "iface_dbg_cache_info", DBG::CACHE_INFO ],
		    [ :d_nocache,    "iface_dbg_nocache",    DBG::NOCACHE    ],
		    [ :d_dont_rescue,"iface_dbg_dont_rescue",DBG::DONT_RESCUE],
		    [ :d_crazydebug, "iface_dbg_crazydebug", DBG::CRAZYDEBUG ]
		].each { |var, tag, lvl|
		    l10n  = $mc.get(tag)
		    button=instance_eval("@#{var}=Gtk::CheckButton::new(l10n)")
		    button.active = $dbg.enabled?(lvl)
		    button.signal_connect("clicked") { |w|
			$dbg[lvl] = w.active?
		    }

		    i, j = 0, j+1 if i > 2
		    tbl.attach(button, i, i += 1, j, j + 1)
		}

		debug_f.add(tbl)


		# Output
		output_f = Gtk::Frame::new(l10n_output)
		@o_one   = Gtk::CheckButton::new("one line")
		@o_quiet = Gtk::CheckButton::new("quiet")
		@o_tag   = Gtk::CheckButton::new("tag only")

		menu = Gtk::Menu::new
		menu.append(Gtk::MenuItem::new("plain text"))
		menu.append(Gtk::MenuItem::new("HTML"))
		menu.append(Gtk::MenuItem::new("GTK"))
		@o_type = Gtk::OptionMenu::new
		@o_type.set_menu(menu)
		@o_type.set_history(2)

		menu = Gtk::Menu::new
		menu.append(Gtk::MenuItem::new("straight"))
		menu.append(Gtk::MenuItem::new("consolidation"))
		@o_process = Gtk::OptionMenu::new
		@o_process.set_menu(menu)

		tbl = Gtk::Table::new(2, 3, true)
		tbl.attach(@o_one,       0, 1, 0, 1)
		tbl.attach(@o_tag,       1, 2, 0, 1)
		tbl.attach(@o_quiet,     2, 3, 0, 1)
		tbl.attach(@o_type,      0, 1, 1, 2)
		tbl.attach(@o_process,   1, 2, 1, 2)

		output_f.add(tbl)

		# Advanced
		advanced_f = Gtk::Frame::new(l10n_advanced)

		@a_useresolver = Gtk::CheckButton::new("local resolver")
		@a_useresolver.signal_connect("clicked") { |w|
		    @a_resolver.set_sensitive(w.active?)
		    @a_resolver.set_text("")
		}
		@a_resolver = Gtk::Entry::new
		@a_resolver.set_sensitive(false)
		
		@a_test = Gtk::CheckButton::new("test only")
		@a_test.signal_connect("clicked") { |w|
		    @a_testname.set_sensitive(w.active?)
		}
		@a_testname = Gtk::Combo::new
		@a_testname.entry.set_editable(false)
		@a_testname.set_popdown_strings(main.testmanager.list.sort)
		@a_testname.set_sensitive(false)
		
		tbl = Gtk::Table::new(1, 3, true)
		tbl.attach(@a_useresolver, 0, 1, 0, 1)
		tbl.attach(@a_resolver,    1, 3, 0, 1)
		tbl.attach(@a_test,        0, 1, 1, 2)
		tbl.attach(@a_testname,    1, 3, 1, 2)
		
		advanced_f.add(tbl)

		#
		pack_start(output_f)
		pack_start(advanced_f)
		pack_start(debug_f)

		# 
		show_all
	    end

	    def one      ; @o_one.active?                                 ; end
	    def quiet    ; @o_quiet.active?                               ; end
	    def tagonly  ; @o_tag.active?                                 ; end
	    def testname ; @a_test.active? ? @a_testname.entry.text : nil ; end
	    def resolver ; @a_useresolver.active? ? @a_resolver.text: nil ; end

	    def output 
		output = []
		output << case @o_type.history
			  when 0 then "text"
			  when 1 then "html"
			  when 2 then "gtk"
			  end
		output << case @o_process.history
			  when 0 then "straight"
			  when 1 then "consolidation"
			  end
		output.join(",")
	    end
	end



	##
	## Option
	##
	class Option < Gtk::VBox
	    def initialize(main)
		# Parent constructor
		super()

		# Localisation
		l10n_transport		= $mc.get("iface_label_transport")
		l10n_error		= $mc.get("iface_label_error")
		l10n_test		= $mc.get("iface_label_extra_tests")
		l10n_output		= $mc.get("iface_label_output")
		l10n_output_zone	= $mc.get("iface_output_zone")
		l10n_output_explain	= $mc.get("iface_output_explain")
		l10n_output_details	= $mc.get("iface_output_details")
		l10n_output_progbar	= $mc.get("iface_output_progressbar")
		l10n_output_desc	= $mc.get("iface_output_description")
		l10n_output_nothing	= $mc.get("iface_output_nothing")
		l10n_error_default	= $mc.get("iface_error_default")
		l10n_error_allwarning	= $mc.get("iface_error_allwarnings")
		l10n_error_allfatal	= $mc.get("iface_error_allfatals")
		l10n_error_on_first	= $mc.get("iface_stop_on_first")

		# Output
		output_f = Gtk::Frame::new(l10n_output)

		@o_zone    = Gtk::CheckButton::new(l10n_output_zone)
		@o_explain = Gtk::CheckButton::new(l10n_output_explain)
		@o_details = Gtk::CheckButton::new(l10n_output_details)
		@o_zone.active = @o_explain.active = @o_details.active = true
		
		@o_prog    = Gtk::RadioButton::new(        l10n_output_progbar)
		@o_desc    = Gtk::RadioButton::new(@o_prog,l10n_output_desc)
		@o_nothing = Gtk::RadioButton::new(@o_prog,l10n_output_nothing)
		@o_prog.active = true

		tbl = Gtk::Table::new(2, 3, true)
		tbl.attach(@o_zone,    0, 1, 0, 1)
		tbl.attach(@o_explain, 1, 2, 0, 1)
		tbl.attach(@o_details, 2, 3, 0, 1)
		tbl.attach(@o_prog,    0, 1, 1, 2)
		tbl.attach(@o_desc,    1, 2, 1, 2)
		tbl.attach(@o_nothing, 2, 3, 1, 2)
		output_f.add(tbl)

		# Error
		error_f = Gtk::Frame::new(l10n_error)

		@ed = Gtk::RadioButton::new(     l10n_error_default)
		@aw = Gtk::RadioButton::new(@ed, l10n_error_allwarning)
		@af = Gtk::RadioButton::new(@ed, l10n_error_allfatal)
		@sf = Gtk::CheckButton::new(l10n_error_on_first)
		@sf.active = true

		tbl = Gtk::Table::new(2, 3, true)
		tbl.attach(@ed, 0, 1, 0, 1)
		tbl.attach(@aw, 1, 2, 0, 1)
		tbl.attach(@af, 2, 3, 0, 1)
		tbl.attach(@sf, 0, 1, 1, 2)
		error_f.add(tbl)
		
		# Tests
		test_f   = Gtk::Frame::new(l10n_test)

		@tst_mail = Gtk::CheckButton::new($mc.get("iface_test_mail"))
		@tst_zcnt = Gtk::CheckButton::new($mc.get("iface_test_zone"))
		@tst_ripe = Gtk::CheckButton::new($mc.get("iface_test_ripe"))
		@tst_mail.active = @tst_zcnt.active = @tst_ripe.active = true

		tbl = Gtk::Table::new(1, 3, true)
		tbl.attach(@tst_mail, 0, 1, 0, 1)
		tbl.attach(@tst_zcnt, 1, 2, 0, 1)
		tbl.attach(@tst_ripe, 2, 3, 0, 1)
		test_f.add(tbl)

		# Transport
		transp_f = Gtk::Frame::new(l10n_transport)

		@ipv4 = Gtk::CheckButton::new("IPv4")
		@ipv6 = Gtk::CheckButton::new("IPv6")
		@ipv6.active = @ipv4.active = true
		unless $ipv6_stack
		    @ipv6.active = false
		    @ipv4.set_sensitive(false)
		    @ipv6.set_sensitive(false)
		end

		@ipv4.signal_connect("toggled") {
		    @ipv6.active = true if !@ipv4.active? && !@ipv6.active?
		}
		@ipv6.signal_connect("toggled") {
		    @ipv4.active = true if !@ipv4.active? && !@ipv6.active?
		}

		@std = Gtk::RadioButton::new(      "STD")
		@udp = Gtk::RadioButton::new(@std, "UDP")
		@tcp = Gtk::RadioButton::new(@std, "TCP")

		tbl = Gtk::Table::new(2, 3, true)
		tbl.attach(@ipv4, 0, 1, 0, 1)
		tbl.attach(@ipv6, 1, 2, 0, 1)
		tbl.attach(@std,  0, 1, 1, 2)
		tbl.attach(@udp,  1, 2, 1, 2)
		tbl.attach(@tcp,  2, 3, 1, 2)
		transp_f.add(tbl)

		# Final packaging
		pack_start(output_f)
		pack_start(error_f)
		pack_start(test_f)
		pack_start(transp_f)
	    end

	    def transp
		transp = []
		transp << "ipv4"	if @ipv4.active?
		transp << "ipv6"	if @ipv6.active?
		transp << "std"		if @std.active?
		transp << "udp"		if @udp.active?
		transp << "tcp"		if @tcp.active?
		transp.join(",")
	    end

	    def verbose
		verbose = []
		verbose << "intro"	if @o_zone.active?
		verbose << "details"	if @o_details.active?
		verbose << "explain"	if @o_explain.active?
		verbose << "testdesc"	if @o_desc.active?
		verbose << "counter"	if @o_prog.active?
		verbose.join(",")
	    end

	    def error
		error = []
		error << "allfatal"	if @af.active?
		error << "allwarning"	if @aw.active?
		error << "stop"		if @sf.active?
		error.join(",")
	    end
	end


	##
	## Input
	##
	class Input < Gtk::VBox
	    def initialize(main)
		# Parent constructor
		super()

		# Pixmaps
		winroot     = Gdk::Window::default_root_window
		make_pixmap = Proc::new { |pixmap_data|
		    Gdk::Pixmap::create_from_xpm_d(winroot, nil, pixmap_data) 
		}
		pix_zone = make_pixmap.call(Publisher::XPM::Zone)
		pix_prim = make_pixmap.call(Publisher::XPM::Primary)
		pix_sec  = make_pixmap.call(Publisher::XPM::Secondary)

		# Localisation
		l10n_check		= $mc.get("iface_label_check")
		l10n_guess		= $mc.get("iface_label_guess")
		l10n_clear		= $mc.get("iface_label_clear")
		l10n_primary		= $mc.get("ns_primary")
		l10n_secondary		= $mc.get("ns_secondary")
		l10n_ips		= $mc.get("ns_ips")
		l10n_ns			= $mc.get("ns_ns")
		l10n_zone		= $mc.get("ns_zone").capitalize

		# 
		@ns	= []
		@ips	= []

		# Zone
		@zone = Gtk::Entry::new

		hbox = Gtk::HBox::new(false, 5)
		hbox.pack_start(Gtk::Image::new(*pix_zone), false, true)
		hbox.pack_start(Gtk::Label::new(l10n_zone), false, true)
		hbox.pack_start(@zone, true, true)
	    
		zone_f = Gtk::Frame::new(l10n_zone)
		zone_f.add(hbox)

		# NS
		tbl  = Gtk::Table::new(MaxNS, 5, false)
		tbl.set_col_spacings(5)
		tbl.set_row_spacings(2)
		(0..MaxNS-1).each { |i|
		    l10n_ns_t = (i == 0 ? l10n_primary			\
				        : l10n_secondary).capitalize
		    logo      = Gtk::Image::new(*(i == 0 ? pix_prim : pix_sec))
		    lbl_ns    = Gtk::Label::new(l10n_ns_t).set_alignment(0,0.5)
		    lbl_ips   = Gtk::Label::new(l10n_ips ).set_alignment(0,0.5)
		    @ns[i]    = Gtk::Entry::new.set_size_request(120, -1)
		    @ips[i]   = Gtk::Entry::new.set_size_request(320, -1)
		    tbl.attach(logo,    0, 1, i, i+1, Gtk::SHRINK)
		    tbl.attach(lbl_ns,  1, 2, i, i+1, Gtk::SHRINK | Gtk::FILL)
		    tbl.attach(@ns[i],  2, 3, i, i+1)
		    tbl.attach(lbl_ips, 3, 4, i, i+1, Gtk::SHRINK | Gtk::FILL)
		    tbl.attach(@ips[i], 4, 5, i, i+1)
		}
		
		ns_f = Gtk::Frame::new(l10n_ns.upcase)
		ns_f.add(tbl)
		
		# Buttons
		@check = Gtk::Button::new(Gtk::Stock::EXECUTE, l10n_check)
		@guess = Gtk::Button::new(Gtk::Stock::REFRESH, l10n_guess)
		@clear = Gtk::Button::new(Gtk::Stock::CLEAR,   l10n_clear)

		@hbbox  = Gtk::HButtonBox::new
		@hbbox.pack_start(@check)
		@hbbox.pack_start(@guess)
		@hbbox.pack_start(@clear)
		
		# Final packaging
		pack_start(zone_f, true,  true)
		pack_start(ns_f,   true,  true)
		pack_start(@hbbox, false, true)

		# Signal handler
		@check.signal_connect("clicked") { |w| 
		    @hbbox.set_sensitive(false)
		    begin
			main.set_expert
			main.set_options
			main.set_domain
			main.release
		    rescue => e
			main.statusbar.push(1, e.message)
			puts e.message
			puts e.backtrace.join("\n")
			puts "FUCK"
		    end
		    @hbbox.set_sensitive(true)
		}

		@guess.signal_connect("clicked") { |w|
		    @hbbox.set_sensitive(false)
		    begin
			main.set_expert
			main.set_options
			main.set_domain
			main.statusbar.push(1, "Name servers and/or addresses guessed")
		    rescue => e
			main.statusbar.push(1, e.message)
			puts e.message
			puts e.backtrace.join("\n")
			puts "FUCK"
		    end
		    
		    @hbbox.set_sensitive(true)
		}

		@clear.signal_connect("clicked") {
		    @hbbox.set_sensitive(false)
		    (@ns + @ips + [ @zone ]).each  { |w| w.set_text("") } 
		    @hbbox.set_sensitive(true)
		}
	    end

	    def domain
		@zone.text
	    end
	    
	    def ns
		ns_list = [ ]
		(0..MaxNS-1).each { |i|
		    ns  = @ns [i].text.strip
		    ips = @ips[i].text.strip.split(/\s*,\s*|\s+/)
		    next if ns.empty?
		    
		    if ips.empty?
		    then ns_list << [ ns ]
		    else ns_list << [ ns, ips ]
		    end
		}
		if ! ns_list.empty?
		    ns_list.collect { |ns, ips|
			if ips
			then ips_str = ips.join(", ") ; "#{ns}=#{ips_str}" 
			else ns
			end
		    }.join(";")
		else
		    nil
		end
	    end
	    
	    def ns=(ns_list) 
		# Sanity check
		if ns_list.length > MaxNS
		    raise ArgumentError, 
			$mc.get("iface_xcp_toomany_nameservers")
		end
		
		# Set nameservers entries
		i = 0
		ns_list.each_index { |i|
		    @ns [i].set_text(ns_list[i][0].to_s)
		    @ips[i].set_text(ns_list[i][1].join(", "))
		}

		# Clear remaining entries
		(i+1..MaxNS-1).each { |i|
		    @ns [i].set_text("") ; @ips[i].set_text("")
		}
	    end
	end



	##
	## Batch
	##
	class Batch < Gtk::VBox
	    def initialize(main)
		# Parent constructor
		super()

		# Localisation
		l10n_check		= $mc.get("iface_label_check")
		l10n_clear		= $mc.get("iface_label_clear")
		l10n_batch		= $mc.get("ns_batch").capitalize

		# Batch
		@batch = Gtk::TextView::new

		info = Gtk::Label::new($mc.get("iface_batch_example"))
		info.set_alignment(0,0.5)

		scroller = Gtk::ScrolledWindow::new
		scroller.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_ALWAYS)
		scroller.add_with_viewport(@batch)

		vbox = Gtk::VBox::new(false, 5)
		vbox.pack_start(scroller, true,  true)
		vbox.pack_start(info,     false, true)
	    
		batch_f = Gtk::Frame::new(l10n_batch)
		batch_f.add(vbox)

		# Buttons
		@check = Gtk::Button::new(Gtk::Stock::EXECUTE, l10n_check)
		@clear = Gtk::Button::new(Gtk::Stock::CLEAR,   l10n_clear)

		@hbbox  = Gtk::HButtonBox::new
		@hbbox.pack_start(@check)
		@hbbox.pack_start(@clear)
		
		# Final packaging
		pack_start(batch_f, true,  true)
		pack_start(@hbbox,  false, true)

		# Signal handler
		@check.signal_connect("clicked") { |w| 
		    @hbbox.set_sensitive(false)
		    begin
			main.set_expert
			main.set_options
			main.set_batch
			main.release
		    rescue => e
			main.statusbar.push(1, e.message)
			puts e.message
			puts e.backtrace.join("\n")
			puts "FUCK"
		    end
		    @hbbox.set_sensitive(true)
		}

		@clear.signal_connect("clicked") {
		    @hbbox.set_sensitive(false)
		    @batch.buffer.set_text("")
		    @hbbox.set_sensitive(true)
		}
	    end

	    def data
		buffer = @batch.buffer
		buffer.get_text(buffer.start_iter, buffer.end_iter, false)
	    end
	end

	class Main
	    attr_reader :config, :statusbar, :testmanager

	    

	    def initialize(param, config, testmanager)
		@p		= param
		@config		= config
		@testmanager	= testmanager
		@window		= nil
		@q		= Queue::new
	    end
	    
	    def create
		@window = Gtk::Window::new
		@window.set_title("ZoneCheck")
		@window.signal_connect("delete_event") {|*args| delete_event(*args) }
		@window.signal_connect("destroy") {|*args| Gtk::main_quit }
		@window.border_width = 0
		
		
		menubar   = Gtk::MenuBar::new
		@statusbar = Gtk::Statusbar::new
		@statusbar.push(1, "Welcome to ZoneCheck #{ZC_VERSION}")
		
		
		@input   = Input::new(self)
		@batch   = Batch::new(self)
		@options = Option::new(self)
		@expert  = Expert::new(self)
		@info_note = Gtk::Frame::new
		
		

		
		# Mode menu
		menu = Gtk::Menu::new
		mode_mitem   = Gtk::MenuItem::new("Mode")
		mode_mitem.set_submenu(menu)
		single_mitem = Gtk::RadioMenuItem::new(nil, "Single")
		grp = single_mitem.group
		menu.append(single_mitem)
		batch_mitem  = Gtk::RadioMenuItem::new(grp, "Batch")
		menu.append(batch_mitem)
		exp_mitem    = Gtk::CheckMenuItem::new("Expert")
		menu.append(exp_mitem)
#		sep = Gtk::SeparatorMenuItem::new
#		menu.append(sep)
		quit_mitem   = Gtk::ImageMenuItem::new(Gtk::Stock::QUIT)
		menu.append(quit_mitem)
		menubar.append(mode_mitem)
		
		# Help menu
		menu       = Gtk::Menu::new
		help_mitem = Gtk::MenuItem::new("Help")
		help_mitem.set_right_justified(true)
		help_mitem.set_submenu(menu)
		about_mitem = Gtk::MenuItem::new("About")
		menu.append(about_mitem)
		menubar.append(help_mitem)


		# Notebook
		notebook = Gtk::Notebook::new
		notebook.set_tab_pos(Gtk::POS_TOP)
		notebook.append_page @input,   Gtk::Label::new("Input")
		notebook.append_page @batch,   Gtk::Label::new("Input")
		notebook.append_page @options, Gtk::Label::new("Options")
#		notebook.append_page @expert,  Gtk::Label::new("Expert")
		
		
		vbox = Gtk::VBox::new(false)
		vbox.pack_start(menubar,    false, true)
		vbox.pack_start(notebook,   true,  true)
		vbox.pack_start(@statusbar, false, true)
		

		# Signal
		about_mitem.signal_connect("activate") {
		    txt  = "Version: #{$zc_version}\n"
		    txt += "Maintainer: #{ZC_MAINTAINER}"

		    about = Gtk::MessageDialog::new(@window, 
					 Gtk::MessageDialog::MODAL,
					 Gtk::MessageDialog::INFO,
					 Gtk::MessageDialog::BUTTONS_OK, txt)
		    about.set_title("About")
		    about.run
		    about.destroy
		}
		
		batch_mitem.signal_connect("toggled") { |w|
		    if w.active? then @batch.show else @batch.hide end
		}

		single_mitem.signal_connect("toggled") { |w|
		    if w.active? then @input.show else @input.hide end
		}

		exp_mitem.signal_connect("toggled") { |w|
		    if w.active?
			notebook.append_page(@expert, Gtk::Label::new("Expert"))
#			notebook.set_current_page(notebook.page_num(@expert))
		    else
			notebook.remove_page(notebook.page_num(@expert))
		    end
		}


		#
		@window.add(vbox)
		@window.show_all
		@batch.hide
	    end
	    
	    def release
		@q.push nil
	    end

	    def wait
		@q.pop
	    end

	    def destroy
		@window.destroy
	    end

	    def set_expert
		@p.rflag.one	= @expert.one
		@p.rflag.tagonly= @expert.tagonly
		@p.rflag.quiet	= @expert.quiet
		@p.output	= @expert.output
		@p.test.tests	= @expert.testname
		@p.resolver.local = @expert.resolver
		@p.resolver.autoconf
	    end

	    def set_options
		@p.transp	= @options.transp
		@p.verbose	= @options.verbose
		@p.error	= @options.error
	    end

	    def set_batch
		@p.batch = Param::BatchData::new(@batch.data)
	    end

	    def set_domain
		@p.domain.clear
		@p.domain.name = @input.domain
		@p.domain.ns   = @input.ns
		if @config[@p.domain.name].nil?
		    raise "#{@input.domain} is not in our TLD map"
		end
		@p.domain.autoconf(@p.resolver.local)
		@input.ns = @p.domain.ns
	    end
	end

	def opts_definition
	    [   [ "--help",	"-h",	GetoptLong::NO_ARGUMENT       ],
		[ "--version",	'-V',	GetoptLong::NO_ARGUMENT       ],
		[ "--debug",	"-d",   GetoptLong::REQUIRED_ARGUMENT ],
		[ "--config",	"-c",   GetoptLong::REQUIRED_ARGUMENT ],
		[ "--testdir",	        GetoptLong::REQUIRED_ARGUMENT ],
		[ "--resolver",	"-r",   GetoptLong::REQUIRED_ARGUMENT ] ]
        end

	def opts_analyse(p)
	    @opts.each do |opt, arg|
		case opt
		when "--help"      then usage(EXIT_USAGE, $stdout)
		when "--version"
		    puts $mc.get("param_version").gsub("PROGNAME", PROGNAME) % 
			[ $zc_version ]
		    exit EXIT_OK
		when "--debug"     then $dbg.level	    = arg
		when "--config"    then p.fs.cfgfile        = arg
		when "--testdir"   then p.fs.testdir        = arg
		when "--resolver"  then p.resolver.local    = arg
		end
	    end
	end

	
	def initialize
	    @opts = GetoptLong.new(* opts_definition)
	    @opts.quiet = true
	    Thread::new { Gtk::main() }
	end
	
	attr_reader :config, :statusbar, :testmanager

	def interact(p, c, tm)
	    @config = c
	    @testmanager = tm

	    Gtk::RC.parse_string(<<EOT
style "package_label"
{
#  font = '-adobe-helvetica-medium-o-*-*-*-120-*-*-*-*-*-*'
font = '-adobe-helvetica-bold-r-normal-*-*-120-*-*-*-*-*-*'
}
widget "*package_label" style "package_label"
EOT
)
	    main = Main::new(p, c, tm)
	    main.create
	    main.wait
	    main.destroy
	end

	def parse(p)
	    begin
		opts_analyse(p)
	    rescue GetoptLong::InvalidOption, GetoptLong::MissingArgument
		return nil
	    end
	    p.fs.autoconf
	    p.resolver.autoconf
	    p

	end
	def usage(errcode, io=$stderr)
	    io.print $mc.get("param_cli_usage").gsub("PROGNAME", PROGNAME)
	    exit errcode unless errcode.nil?
	end
    end
end
