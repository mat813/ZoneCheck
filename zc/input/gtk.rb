# $Id$

# 
# CONTACT     : zonecheck@nic.fr
# AUTHOR      : Stephane D'Alu <sdalu@nic.fr>
#
# CREATED     : 2002/10/16 18:58:17
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

require 'getoptlong'
require 'thread'
require 'param'

require 'gtk2'
require 'ext/gtk'
require 'data/xpm'
require 'data/logo'

Gtk.init

# !! Bug in ruby or gtk2 => EBADF for nresolv
# Perhaps move Gtk.init elsewhere

#
# When busy: @window.window.cursor = Gdk::Cursor::new(Gdk::Cursor::WATCH)
# Notbook:   set_page_pixmaps(notebook, page_num, @book_open, @book_open_mask)
# Tooltips
#

##
## Processing parameters from GTK
##
module Input
    class GTK
	with_msgcat 'gtk.%s'

	MaxNS			= 8
	DefaultBatchFile	= 'batch.txt'

	def allow_preset ; true ; end



	##
	## Expert
	##
	class Expert < Gtk::VBox
	    def initialize(main)
		# Parent constructor
		super()
		
		# Localisation
		l10n_debug	= $mc.get("iface:label_debug")
		l10n_output	= $mc.get("iface:label_output")
		l10n_advanced	= $mc.get("iface:label_advanced")


		# Output
		output_f = Gtk::Frame::new($mc.get('iface:panel:output'))
		@o_tag   = main.mk_ckbtn('iface:param:reportflag:tagonly')


		menu = Gtk::Menu::new
		menu.append(Gtk::MenuItem::new('plain text'))
		menu.append(Gtk::MenuItem::new('HTML'))
		menu.append(Gtk::MenuItem::new('GTK'))
		@o_publisher = Gtk::OptionMenu::new
		@o_publisher.set_menu(menu)
		@o_publisher.set_history(2)

		menu = Gtk::Menu::new
		menu.append(Gtk::MenuItem::new("by severity"))
		menu.append(Gtk::MenuItem::new("by host"))
		@o_report = Gtk::OptionMenu::new
		@o_report.set_menu(menu)


		tbl = Gtk::Table::new(1, 3, true)
		tbl.attach(@o_publisher, 0, 1, 0, 1)
		tbl.attach(@o_tag,       2, 3, 0, 1)

		output_f.add(tbl)

		# Progression
		progress_f = Gtk::Frame::new($mc.get('iface:panel:progression'))
		
		@o_counter, @o_testdesc, @o_nothing = 
		    main.mk_rdbtns('iface:param:reportflag:counter',
				   'iface:param:reportflag:testdesc',
				   'iface:param:reportflag:noprogress')
		@o_counter.active = true

		tbl = Gtk::Table::new(1, 3, true)
		tbl.attach(@o_counter,   0, 1, 0, 1)
		tbl.attach(@o_testdesc,  1, 2, 0, 1)
		tbl.attach(@o_nothing,   2, 3, 0, 1)

		progress_f.add(tbl)

		
		# Advanced
		advanced_f = Gtk::Frame::new(l10n_advanced)

		@a_useresolver = main.mk_ckbtn('iface:param:resolver:local')
		@a_useresolver.signal_connect('clicked') { |w|
		    @a_resolver.set_sensitive(w.active?)
		    @a_resolver.set_text("")
		}
		@a_resolver = Gtk::Entry::new
		@a_resolver.set_sensitive(false)

		@a_usecategory = main.mk_ckbtn('iface:param:test:categories')
		@a_usecategory.signal_connect('clicked') { |w|
		    @a_category.set_sensitive(w.active?)
		    main.options.extra(!w.active?)		    
		    if !w.active?
			@a_category.set_text(main.options.categories)
		    end
		}
		@a_category = Gtk::Entry::new
		@a_category.set_text(main.options.categories)
		@a_category.set_sensitive(false)
		
		@a_test = main.mk_ckbtn('iface:param:test:tests')
		@a_test.signal_connect('clicked') { |w|
		    @a_testname.set_sensitive(w.active?)
		}
		@a_testname = Gtk::Combo::new
		@a_testname.entry.set_editable(false)
		@a_testname.set_popdown_strings(main.testmanager.list.sort)
		@a_testname.set_sensitive(false)
		
		tbl = Gtk::Table::new(3, 3, true)
		tbl.attach(@a_useresolver, 0, 1, 0, 1)
		tbl.attach(@a_resolver,    1, 3, 0, 1)
		tbl.attach(@a_usecategory, 0, 1, 1, 2)
		tbl.attach(@a_category,    1, 3, 1, 2)		
		tbl.attach(@a_test,        0, 1, 2, 3)
		tbl.attach(@a_testname,    1, 3, 2, 3)
		
		advanced_f.add(tbl)

		# Debug
		debug_f = Gtk::Frame::new(l10n_debug)

		i, j = 0, 0
		tbl = Gtk::Table::new(1, 3, true)
		[   [ 'init',		DBG::INIT	],
		    [ 'locale',		DBG::LOCALE	],
		    [ 'config',		DBG::CONFIG	],
		    [ 'autoconf',	DBG::AUTOCONF	],
		    [ 'loading',	DBG::LOADING	],
		    [ 'tests',		DBG::TESTS	],
		    [ 'testdbg',	DBG::TESTDBG	],
		    [ 'cache_info',	DBG::CACHE_INFO	],
		    [ 'dbg',		DBG::DBG	],
		    [ 'crazydebug',	DBG::CRAZYDEBUG	],
		    [ 'nresolv',	DBG::NRESOLV	],
		    [ 'nocache',	DBG::NOCACHE	],
		    [ 'dont_rescue',	DBG::DONT_RESCUE],
		].each { |id, lvl|
		    var		= "d_#{id}"
		    tag		= "iface:dbg:#{id}"
		    button	= instance_eval("@#{var}=main.mk_ckbtn(tag)")
		    button.active = $dbg.enabled?(lvl)
		    button.signal_connect('clicked') {|w| $dbg[lvl]=w.active?}
		    i, j = 0, j+1 if i > 2
		    tbl.attach(button, i, i += 1, j, j + 1)
		}

		debug_f.add(tbl)


		#
		pack_start(output_f)
		pack_start(progress_f)
		pack_start(advanced_f)
		pack_start(debug_f)

		# 
		show_all
	    end

	    def tagonly  ; @o_tag.active?                                 ; end
	    def resolver ; @a_useresolver.active? ? @a_resolver.text: nil ; end
            def testname ; @a_test.active? ? @a_testname.entry.text : nil ; end

	    def verbose
		verbose = []
		verbose << 'counter'	if @o_counter.active?
		verbose << 'testdesc'	if @o_testdesc.active?
		verbose.join(',')
	    end

	    def output 
		output = []
		output << case @o_publisher.history
			  when 0 then 'text'
			  when 1 then 'html'
			  when 2 then 'gtk'
			  end
		output.join(',')
	    end
	end



	##
	## Option
	##
	class Option < Gtk::VBox
	    def initialize(main)
		# Parent constructor
		super()
		ip_rflag  = 'iface:param:reportflag'
		ip_rpt = 'iface:param:report'
		ip_net = 'iface:param:network'


		# Localisation
		l10n_transport		= $mc.get('iface:panel:transport')
		l10n_error		= $mc.get('iface:panel:error')
		l10n_test		= $mc.get('iface:panel:extra_tests')
		l10n_output		= $mc.get('iface:label_output')
		l10n_output_zone	= $mc.get('iface:output_zone')
		l10n_output_testname	= $mc.get('iface:output_testname')
		l10n_output_explain	= $mc.get('iface:output_explain')
		l10n_output_details	= $mc.get('iface:output_details')


		# Output
		output_f = Gtk::Frame::new(l10n_output)

		@o_summary = main.mk_ckbtn('iface:param:reportflag:intro')
		@o_summary.active = true

		@o_testname= main.mk_ckbtn('iface:param:reportflag:testname')
		@o_explain = main.mk_ckbtn('iface:param:reportflag:explain')
		@o_details = main.mk_ckbtn('iface:param:reportflag:details')
		@o_explain.active = @o_details.active = true

		@o_one     = main.mk_ckbtn('iface:param:reportflag:one')
		@o_quiet   = main.mk_ckbtn('iface:param:reportflag:quiet')
		
		@o_reportok= main.mk_ckbtn('iface:param:reportflag:reportok')
		@o_fatalonly=main.mk_ckbtn('iface:param:reportflag:fatalonly')

		menu = Gtk::Menu::new
		menu.append(Gtk::MenuItem::new('sorted by severity'))
		menu.append(Gtk::MenuItem::new('sorted by host'))
		@o_report = Gtk::OptionMenu::new
		@o_report.set_menu(menu)

		menu = Gtk::Menu::new
		menu.append(Gtk::MenuItem::new('Francais'))
		menu.append(Gtk::MenuItem::new('English'))
		@o_lang = Gtk::OptionMenu::new
		@o_lang.set_menu(menu)
		@o_lang.set_history(1)


		tbl = Gtk::Table::new(3, 3, true)
		tbl.attach(@o_summary,   0, 1, 0, 1)
		tbl.attach(@o_report,    2, 3, 0, 1)
		tbl.attach(@o_testname,  0, 1, 1, 2)
		tbl.attach(@o_explain,   1, 2, 1, 2)
		tbl.attach(@o_details,   2, 3, 1, 2)
		tbl.attach(@o_reportok,  0, 1, 2, 3)
		tbl.attach(@o_fatalonly, 1, 2, 2, 3)
		tbl.attach(@o_quiet,     2, 3, 2, 3)
		tbl.attach(@o_one,       0, 1, 3, 4)
		output_f.add(tbl)


		# Error
		error_f = Gtk::Frame::new(l10n_error)

		@ed, @aw, @af =
		    main.mk_rdbtns('iface:param:report:dfltseverity',
				   'iface:param:report:allwarning',
				   'iface:param:report:allfatal')
		@sf = main.mk_ckbtn('iface:param:reportflag:stop_on_fatal')
		@sf.active = true

		menu = Gtk::Menu::new
		menu.append(Gtk::MenuItem::new('* automatic *'))
		main.config.profiles.each { |profile|
		    menu.append(Gtk::MenuItem::new(profile.name))
		}
		@o_profile = Gtk::OptionMenu::new
		@o_profile.set_menu(menu)

		tbl = Gtk::Table::new(2, 3, true)
		tbl.attach(@ed,		0, 1, 0, 1)
		tbl.attach(@aw,		1, 2, 0, 1)
		tbl.attach(@af,		2, 3, 0, 1)
		tbl.attach(@sf,		0, 1, 1, 2)
		tbl.attach(@o_profile,	2, 3, 1, 2)
		error_f.add(tbl)

		# Tests
		@test_f   = Gtk::Frame::new(l10n_test)

		@tst_mail = main.mk_ckbtn('iface:param:metatest:mail')
		@tst_axfr = main.mk_ckbtn('iface:param:metatest:zone')
		@tst_rir  = main.mk_ckbtn('iface:param:metatest:rir')
		@tst_mail.active = @tst_axfr.active = @tst_rir.active = true

		tbl = Gtk::Table::new(1, 3, true)
		tbl.attach(@tst_mail, 0, 1, 0, 1)
		tbl.attach(@tst_axfr, 1, 2, 0, 1)
		tbl.attach(@tst_rir,  2, 3, 0, 1)
		@test_f.add(tbl)

		# Transport		    
		transp_f = Gtk::Frame::new(l10n_transport)

		@ipv4 = main.mk_ckbtn('iface:param:network:ipv4')
		@ipv6 = main.mk_ckbtn('iface:param:network:ipv6')
		@ipv6.active = @ipv4.active = true
		unless $ipv6_stack
		    @ipv6.active = false
		    @ipv4.set_sensitive(false)
		    @ipv6.set_sensitive(false)
		end

		@ipv4.signal_connect('toggled') {
		    @ipv6.active = true if !@ipv4.active? && !@ipv6.active?
		}
		@ipv6.signal_connect('toggled') {
		    @ipv4.active = true if !@ipv4.active? && !@ipv6.active?
		}

		@std, @udp, @tcp = main.mk_rdbtns('iface:param:network:std',
						  'iface:param:network:udp',
						  'iface:param:network:tcp')

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
		pack_start(@test_f)
		pack_start(transp_f)
	    end


	    def extra(bool)
		@test_f.set_sensitive(bool)
	    end

	    def one   ; @o_one.active?   ; end
	    def quiet ; @o_quiet.active? ; end

	    def verbose
		verbose = []
		verbose << 'intro'		if @o_summary.active?
		verbose << 'testname'		if @o_testname.active?
		verbose << 'explain'		if @o_explain.active?
		verbose << 'details'		if @o_details.active?
		verbose << 'reportok'		if @o_reportok.active?
		verbose << 'fatalonly'		if @o_fatalonly.active?
		verbose.join(',')
	    end

	    def output
		output = []
		output << case @o_report.history
			  when 0 then 'byseverity'
			  when 1 then 'byhost'
			  end
		output.join(',')
	    end

	    def error
		error = []
		error << 'allfatal'		if @af.active?
		error << 'allwarning'		if @aw.active?
		error << 'stop'			if @sf.active?
		error.join(',')
	    end

	    def categories
		categories = []
		categories << '!rir'		unless @tst_rir.active?
		categories << '!mail'		unless @tst_mail.active?
		categories << '!dns:axfr'	unless @tst_axfr.active?
		categories << '+'		# accept by default
		categories.join(',')
	    end

	    def transp
		transp = []
		transp << 'ipv4'		if @ipv4.active?
		transp << 'ipv6'		if @ipv6.active?
		transp << 'std'			if @std.active?
		transp << 'udp'			if @udp.active?
		transp << 'tcp'			if @tcp.active?
		transp.join(',')
	    end
	end


	##
	## Single
	##
	class Single < Gtk::VBox
	    def initialize(main)
		# Parent constructor
		super()

		# Pixmaps
		winroot     = Gdk::Window::default_root_window
		make_pixmap = Proc::new { |pixmap_data|
		    Gdk::Pixmap::create_from_xpm_d(winroot, nil, pixmap_data) 
		}
		pix_zone = make_pixmap.call(ZCData::XPM::Zone)
		pix_prim = make_pixmap.call(ZCData::XPM::Primary)
		pix_sec  = make_pixmap.call(ZCData::XPM::Secondary)

		# Localisation
		l10n_check		= $mc.get('iface:btn:check')
		l10n_guess		= $mc.get('iface:btn:guess')
		l10n_clear		= $mc.get('iface:btn:clear')
		l10n_primary		= $mc.get('ns_primary')
		l10n_secondary		= $mc.get('ns_secondary')
		l10n_ips		= $mc.get('ns_ips')
		l10n_ns			= $mc.get('iface:panel:ns')
		l10n_zone		= $mc.get('iface:panel:zone').capitalize

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
		tbl.column_spacings = 5
		tbl.row_spacings = 2
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
		
		ns_f = Gtk::Frame::new(l10n_ns.capitalize)
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
		@check.signal_connect('clicked') { |w| 
		    @hbbox.set_sensitive(false)
		    begin
			main.set_expert
			main.set_options
			main.set_domain
			main.destroy
			Gtk::main_quit
		    rescue => e
			main.statusbar.push(1, e.message)
			puts e.message
			puts e.backtrace.join("\n")
			puts 'FUCK check'
		    end
		    @hbbox.set_sensitive(true)
		}

		@guess.signal_connect('clicked') { |w|
		    @hbbox.set_sensitive(false)
		    begin
			main.set_expert
			main.set_options
			main.set_domain
			main.statusbar.push(1, 'Name servers and/or addresses guessed')
		    rescue => e
			main.statusbar.push(1, e.message)
			puts e.message
			puts e.backtrace.join("\n")
			puts 'FUCK guess'
		    end
		    
		    @hbbox.set_sensitive(true)
		}

		@clear.signal_connect('clicked') {
		    @hbbox.set_sensitive(false)
		    (@ns + @ips + [ @zone ]).each  { |w| w.set_text('') } 
		    @hbbox.set_sensitive(true)
		    main.statusbar.push(1, 'Input cleared')
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
			then ips_str = ips.join(', ') ; "#{ns}=#{ips_str}" 
			else ns
			end
		    }.join(';')
		else
		    nil
		end
	    end
	    
	    def ns=(ns_list) 
		# Sanity check
		if ns_list.length > MaxNS
		    raise ArgumentError, 
			$mc.get('iface:xcp_toomany_nameservers')
		end
		
		# Set nameservers entries
		i = 0
		ns_list.each_index { |i|
		    @ns [i].set_text(ns_list[i][0].to_s)
		    @ips[i].set_text(ns_list[i][1].join(', '))
		}

		# Clear remaining entries
		(i+1..MaxNS-1).each { |i|
		    @ns [i].set_text('') ; @ips[i].set_text('')
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
		l10n_check		= $mc.get('iface:btn:check')
		l10n_clear		= $mc.get('iface:btn:clear')
		l10n_batch		= $mc.get('ns_batch').capitalize
		l10n_batch_open		= $mc.get('iface:batch_open')
		l10n_batch_save		= $mc.get('iface:batch_save')
		l10n_file_gotdirectory	= $mc.get('iface:file_gotdirectory')
		l10n_file_overwrite	= $mc.get('iface:file_overwrite')

		# Open/Save 
		open = Gtk::Button::new(Gtk::Stock::OPEN)
		save = Gtk::Button::new(Gtk::Stock::SAVE)
		file_hbbox = Gtk::HButtonBox::new
		file_hbbox.layout_style = Gtk::HButtonBox::START
		file_hbbox.pack_start(open)
		file_hbbox.pack_start(save)

		# Batch
		@batch = Gtk::TextView::new

		info = Gtk::Label::new($mc.get('iface:batch_example'))
		info.set_alignment(0,0.5)

		scroller = Gtk::ScrolledWindow::new
		scroller.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_ALWAYS)
		scroller.add_with_viewport(@batch)

		vbox = Gtk::VBox::new(false, 5)
		vbox.pack_start(file_hbbox, false, true)
		vbox.pack_start(scroller,   true,  true)
		vbox.pack_start(info,       false, true)
	    
		batch_f = Gtk::Frame::new(l10n_batch)
		batch_f.add(vbox)

		# Buttons
		@check = Gtk::Button::new(Gtk::Stock::EXECUTE, l10n_check)
		@clear = Gtk::Button::new(Gtk::Stock::CLEAR,   l10n_clear)


		hbbox = Gtk::HButtonBox::new
		hbbox.pack_start(@check)
		hbbox.pack_start(@clear)
		
		# Final packaging
		pack_start(batch_f, true,  true)
		pack_start(hbbox,   false, true)

		# Signal handler
		@check.signal_connect('clicked') { |w| 
		    hbbox.set_sensitive(false)
		    begin
			main.set_expert
			main.set_options
			main.set_batch
			main.release
		    rescue => e
			main.statusbar.push(1, e.message)
			puts e.message
			puts e.backtrace.join("\n")
			puts 'FUCK'
		    end
		    hbbox.set_sensitive(true)
		}

		@clear.signal_connect('clicked') {
		    hbbox.set_sensitive(false)
		    self.data = ''
		    hbbox.set_sensitive(true)
		    main.statusbar.push(1, 'Input cleared')
		}

		save.signal_connect('clicked') {
		    # Create file selection
		    fs = Gtk::FileSelection::new(l10n_batch_save)
		    fs.set_modal(true)
		    fs.set_transient_for(main.window)
		    fs.hide_fileop_buttons
		    fs.set_filename(DefaultBatchFile)
		    
		    # Cancel Button
		    fs.cancel_button.signal_connect('clicked') {
			fs.destroy 
		    }

		    # Ok Button
		    fs.ok_button.signal_connect('clicked') {
			doit = true
			doit &= fs.filename[-1] != File::SEPARATOR[0]
			if doit && File.file?(fs.filename)
			    txt = l10n_file_overwrite % fs.filename
			    overwrite = Gtk::MessageDialog::new(fs, 
				    Gtk::MessageDialog::MODAL,
				    Gtk::MessageDialog::WARNING,
				    Gtk::MessageDialog::BUTTONS_YES_NO, txt)
			    doit &= overwrite.run == 
				Gtk::MessageDialog::RESPONSE_YES
			    overwrite.destroy
			end
			if doit
			    begin
				File::open(fs.filename, 
					File::CREAT|File::WRONLY, 0644) { |io|
				    io.write(data)
				}
				fs.destroy
			    rescue SystemCallError => e
				fs.destroy
				error = Gtk::MessageDialog::new(main.window, 
				    Gtk::MessageDialog::MODAL,
				    Gtk::MessageDialog::ERROR,
				    Gtk::MessageDialog::BUTTONS_CLOSE,
				    e.message)
				error.run
				error.destroy
			    end
			end
		    }

		    # Display file selection
		    fs.show
		}

		open.signal_connect('clicked') {
		    # Create file selection
		    fs = Gtk::FileSelection::new(l10n_batch_open)
		    fs.set_modal(true)
		    fs.set_transient_for(main.window)
		    fs.hide_fileop_buttons
		    
		    # Cancel Button
		    fs.cancel_button.signal_connect('clicked') {
			fs.destroy
		    }

		    # Ok Button
		    fs.ok_button.signal_connect('clicked') {
			if fs.filename[-1] != File::SEPARATOR[0]
			    if File.directory?(fs.filename)
				main.statusbar.push(1, l10n_file_gotdirectory)
			    else
				begin
				    txt = ''
				    File::open(fs.filename) { |io|
					while not io.eof?
					    txt << io.read(4096) ; end
				    }
				    self.data = txt
				rescue SystemCallError => e
				    main.statusbar.push(1, e.message)
				end
			    end
			    fs.destroy
			end
		    }

		    # Display file selection
		    fs.show
		}
	    end

	    def data=(txt)
		@batch.buffer.set_text(txt)
	    end

	    def data
		buffer = @batch.buffer
		buffer.get_text(buffer.start_iter, buffer.end_iter, false)
	    end
	end

	class Main
	    attr_reader :config, :statusbar, :testmanager, :window
	    attr_reader :aborted
	    
	    attr_reader :options

	    def initialize(param, config, testmanager)
		@p		= param
		@config		= config
		@testmanager	= testmanager
		@window		= nil
		@aborted	= false
	    end
	    
	    def mk_btn(tag, type, sibling=nil)
		widget = if sibling.nil? 
			 then type.new($mc.get(tag))
			 else type.new(sibling, $mc.get(tag))
			 end
		begin
		    @tooltips.set_tip(widget, $mc.get(tag + '/tip'), tag)
		rescue MsgCat::EntryNotFound
		end
		widget
	    end

	    def mk_ckbtn(tag, sibling=nil)
		mk_btn(tag, Gtk::CheckButton, sibling)
	    end
	    def mk_rdbtn(tag, sibling=nil)
		mk_btn(tag, Gtk::RadioButton, sibling)
	    end
	    def mk_rdbtns(*tags)
		rdbtns = [ ]
		tags.each { |tag| rdbtns << mk_rdbtn(tag, rdbtns[0]) }
		rdbtns
	    end


	    def self.mk_mitem(tag)
		Gtk::MenuItem::new($mc.get(tag))
	    end

	    def create
		@window = Gtk::Window::new
		@window.set_title('ZoneCheck')
		@window.signal_connect('delete_event') { 
		    @aborted = true ; destroy ; Gtk::main_quit }
		@window.border_width = 0

		@tooltips = Gtk::Tooltips.new
		@tooltips.disable

		menubar   = Gtk::MenuBar::new
		@statusbar = Gtk::Statusbar::new
		@statusbar.push(1, "Welcome to ZoneCheck #{ZC_VERSION}")
		
		
		@single    = Single::new(self)
		@batch     = Batch::new(self)
		@options   = Option::new(self)
		@expert    = Expert::new(self)
		@info_note = Gtk::Frame::new
		
		
		#
		# +----------+-----------+------------+-----------+---------+
		# | File     |  Mode     | Preference |           | Help    |
		# ++--------+++---------+++----------++-----------+--------++
		#  | Quit   | | Single  | | Tooltips |             | About |
		#  +--------+ | Batch   | +----------+             +-------+
		#             | ------- |
		#             | Expert  |
		#             +---------+
		
		# [File]
		mitem = Gtk::MenuItem::new('File')
		menu  = Gtk::Menu::new
		mitem.set_submenu(menu)
		menubar.append(mitem)

		quit_mitem   = Gtk::ImageMenuItem::new(Gtk::Stock::QUIT)
		menu.append(quit_mitem)

		# [Mode]
		mitem = Gtk::MenuItem::new('Mode')
		menu  = Gtk::Menu::new
		mitem.set_submenu(menu)
		menubar.append(mitem)

		single_mitem = Gtk::RadioMenuItem::new(nil, 'Single')
		grp = single_mitem.group
		menu.append(single_mitem)
		batch_mitem  = Gtk::RadioMenuItem::new(grp, 'Batch')
		menu.append(batch_mitem)
#		menu.append(Gtk::SeparatorMenuItem::new)
#		exp_mitem    = Gtk::CheckMenuItem::new('Expert')
#		menu.append(exp_mitem)

		# [Preference]
		mitem = Gtk::MenuItem::new('Preference')
		menu  = Gtk::Menu::new
		mitem.set_submenu(menu)
		menubar.append(mitem)

		tooltips_mitem = Gtk::CheckMenuItem::new('Tooltips')
		menu.append(tooltips_mitem)

		# [Help]
		mitem = Gtk::MenuItem::new('Help')
		menu  = Gtk::Menu::new
		mitem.set_submenu(menu)
		mitem.set_right_justified(true)
		menubar.append(mitem)

		about_mitem = Gtk::MenuItem::new('About')
		menu.append(about_mitem)


		# Notebook
		notebook = Gtk::Notebook::new
		notebook.set_tab_pos(Gtk::POS_TOP)
		notebook.append_page @single,  Gtk::Label::new('Input')
		notebook.append_page @batch,   Gtk::Label::new('Input')
		notebook.append_page @options, Gtk::Label::new('Options')
#		notebook.set_tab_label_packing(@options, 
#					       false, false, Gtk::PACK_END)
		notebook.append_page @expert,  Gtk::Label::new('Expert')
#		notebook.set_tab_label_packing(@expert, 
#					       false, false, Gtk::PACK_END)
		
		vbox = Gtk::VBox::new(false)
		vbox.pack_start(menubar,    false, true)
		vbox.pack_start(notebook,   true,  true)
		vbox.pack_start(@statusbar, false, true)
		

		# Signal
		about_mitem.signal_connect('activate') {
		    logo = Gdk::Pixmap::create_from_xpm_d(Gdk::Window::default_root_window, nil, ZCData::XPM::Logo)
		    
		    txt  = "Version\t: #{$zc_version}\n"
		    txt += "Contact\t: #{ZC_CONTACT}\n"
		    txt += "Maintainer\t: #{ZC_MAINTAINER}\n"
		    txt += "Copyright\t: #{ZC_COPYRIGHT}\n"

		    about = Gtk::Dialog::new('About', @window,
                         Gtk::Dialog::MODAL | Gtk::Dialog::DESTROY_WITH_PARENT,
                         [Gtk::Stock::OK, Gtk::Dialog::RESPONSE_ACCEPT])


		    about.vbox.pack_start(Gtk::Image::new(*logo), false, true)
		    about.vbox.pack_start(Gtk::Label::new(txt), false, true)
		    about.vbox.show_all
		    about.run
		    about.destroy
		}
		
		batch_mitem.signal_connect('toggled') { |w|
		    if w.active? then @batch.show else @batch.hide end
		}

		single_mitem.signal_connect('toggled') { |w|
		    if w.active? then @single.show else @single.hide end
		}

#		exp_mitem.signal_connect('toggled') { |w|
#		    if w.active?
#			notebook.append_page(@expert, Gtk::Label::new('Expert'))
##			@expert.set_sensitive(false)
##			notebook.set_current_page(notebook.page_num(@expert))
#		    else
#			notebook.remove_page(notebook.page_num(@expert))
#		    end
#		}
		
		quit_mitem.signal_connect('activate') {
		    @aborted = true ; destroy ; Gtk::main_quit }

		tooltips_mitem.signal_connect('toggled') { |w|
		    if w.active?
		    then @tooltips.enable
		    else @tooltips.disable
		    end
		}
		

		#
		@window.add(vbox)
		@window.show_all
		@batch.hide
		notebook.set_page(notebook.page_num(@single))

	    end

	    def destroy
		@window.destroy
	    end

	    def set_expert
		@p.rflag.tagonly	= @expert.tagonly
		@p.output		= @expert.output
		@p.verbose		= @expert.verbose
		@p.test.tests		= @expert.testname
		@p.resolver.local	= @expert.resolver
		@p.resolver.autoconf
	    end

	    def set_options
		@p.test.categories	= @options.categories
		@p.transp		= @options.transp
		@p.verbose		= @options.verbose
		@p.output		= @options.output
		@p.error		= @options.error
		@p.rflag.one		= @options.one
		@p.rflag.quiet		= @options.quiet
	    end

	    def set_batch
		@p.batch = Param::BatchData::new(@batch.data)
	    end

	    def set_domain
		@p.domain.clear
		@p.domain.name = @single.domain
		@p.domain.ns   = @single.ns
		if @config.profile(@p.domain.name).nil?
		    raise "#{@single.domain} is not in our TLD map"
		end
		@p.domain.autoconf(@p.resolver.local)
		@single.ns = @p.domain.ns
	    end
	end

	def opts_definition
	    [   [ '--help',	'-h',	GetoptLong::NO_ARGUMENT       ],
		[ '--version',	'-V',	GetoptLong::NO_ARGUMENT       ],
		[ '--lang',		GetoptLong::REQUIRED_ARGUMENT ],
		[ '--debug',	'-d',   GetoptLong::REQUIRED_ARGUMENT ],
		[ '--config',	'-c',   GetoptLong::REQUIRED_ARGUMENT ],
		[ '--testdir',	        GetoptLong::REQUIRED_ARGUMENT ],
		[ '--resolver',	'-r',   GetoptLong::REQUIRED_ARGUMENT ] ]
        end

	def opts_analyse(p)
	    @opts.each do |opt, arg|
		case opt
		when '--help'      then usage(EXIT_USAGE, $stdout)
		when '--version'
		    puts $mc.get('input:version').gsub('PROGNAME', PROGNAME) % 
			[ $zc_version ]
		    exit EXIT_OK
		when '--lang'     then $locale.lang         = arg
		when '--debug'     then $dbg.level	    = arg
		when '--config'    then p.preconf.cfgfile   = arg
		when '--testdir'   then p.preconf.testdir   = arg
		when '--resolver'  then p.resolver.local    = arg
		end
	    end
	end

	
	def initialize
	    @opts = GetoptLong.new(* opts_definition)
	    @opts.quiet = true
	end
	
	def restart
	    @opts = GetoptLong.new(* opts_definition)
	    @opts.quiet = true
	end

	attr_reader :config, :statusbar, :testmanager

	def interact(p, c, tm, io = $console.stdout)
	    @config = c
	    @testmanager = tm

	    p.resolver.autoconf
	    p.domain.clear
	    p.domain.name = 'nic.fr'
	    p.domain.autoconf(p.resolver.local)

	    Gtk::RC.parse_string(<<EOT
style 'package_label'
{
#  font = '-adobe-helvetica-medium-o-*-*-*-120-*-*-*-*-*-*'
font = '-adobe-helvetica-bold-r-normal-*-*-120-*-*-*-*-*-*'
}
widget '*package_label' style 'package_label'
EOT
)


	    main = Main::new(p, c, tm)
	    main.create
	    Gtk::main()
	    return ! main.aborted
	end

	def parse(p)
	    begin
		opts_analyse(p)
		return false unless ARGV.empty?
	    rescue GetoptLong::Error
		return false
	    end
	    p.preconf.autoconf
	    p.resolver.autoconf
	    true
	end

	def usage(errcode, io=$console.stderr)
	    io.print $mc.get('input:gtk:usage').gsub('PROGNAME', PROGNAME)
	    exit errcode unless errcode.nil?
	end

	def error(str, errcode=nil, io=$console.stderr)
	    l10n_error = $mc.get('word:error').upcase
	    io.puts "#{l10n_error}: #{str}"
	    exit errcode unless errcode.nil?
	end
    end
end

