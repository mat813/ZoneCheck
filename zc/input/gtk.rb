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

require 'thread'
require 'gtk'

class Param
    class GTK
	MaxNS = 8
	##
	##
	##
	class Option < Gtk::VBox
	    def initialize
		super()
		l10n_transport = "Transport"
		l10n_error = "Error"
		l10n_test = "Extra tests"



		transp_f = Gtk::Frame::new(l10n_transport)
		error_f  = Gtk::Frame::new(l10n_error)
		test_f   = Gtk::Frame::new(l10n_test)

		# Error
		@ed = Gtk::RadioButton::new(nil, 
					    $mc.get("iface_error_default"))
		@aw = Gtk::RadioButton::new(@ed, 
					    $mc.get("iface_error_allwarnings"))
		@af = Gtk::RadioButton::new(@ed,
					    $mc.get("iface_error_allfatals"))
		@sf = Gtk::CheckButton::new($mc.get("iface_stop_on_first"))
		@sf.active = true

		tbl = Gtk::Table::new(2, 3, true)
		tbl.attach(@ed, 0, 1, 0, 1)
		tbl.attach(@aw, 1, 2, 0, 1)
		tbl.attach(@af, 2, 3, 0, 1)
		tbl.attach(@sf, 0, 3, 1, 2)
		error_f.add(tbl)
		

		# Tests
		@tst_mail = Gtk::CheckButton::new($mc.get("iface_test_mail"))
		@tst_zcnt = Gtk::CheckButton::new($mc.get("iface_test_zone"))
		@tst_ripe = Gtk::CheckButton::new($mc.get("iface_test_ripe"))
		@db_ripe  = Gtk::Entry::new
		@db_ripe.set_text("whois.ripe.net")
		@tst_mail.active = @tst_zcnt.active = @tst_ripe.active = true

		tbl = Gtk::Table::new(2, 3, true)
		tbl.attach(@tst_mail, 0, 1, 0, 1)
		tbl.attach(@tst_zcnt, 1, 2, 0, 1)
		tbl.attach(Gtk::Label::new(""), 2, 3, 0, 1)
		tbl.attach(@tst_ripe, 0, 1, 1, 2)
		tbl.attach(@db_ripe , 1, 2, 1, 2)
		test_f.add(tbl)

		# Transport
		@ipv4 = Gtk::CheckButton::new("IPv4")
		@ipv6 = Gtk::CheckButton::new("IPv6")
		@ipv6.active = @ipv4.active = true
		unless $ipv6_stack
		    @ipv6.active = false
		    @ipv4.set_sensitive(false)
		    @ipv6.set_sensitive(false)
		end

		@std = Gtk::RadioButton::new(nil,  "STD")
		@udp = Gtk::RadioButton::new(@std, "UDP")
		@tcp = Gtk::RadioButton::new(@std, "TCP")

		tbl = Gtk::Table::new(2, 3, true)
		tbl.attach(@ipv4, 0, 1, 0, 1)
		tbl.attach(@ipv6, 1, 2, 0, 1)
		tbl.attach(@std,  0, 1, 1, 2)
		tbl.attach(@udp,  1, 2, 1, 2)
		tbl.attach(@tcp,  2, 3, 1, 2)
		transp_f.add(tbl)

		#
		pack_start(error_f)
		pack_start(test_f)
		pack_start(transp_f)


		#
		@tst_ripe.signal_connect("toggled") { |w|
		    @db_ripe.set_sensitive(@tst_ripe.active)
		}

		proc = Proc::new { 
		    if !@ipv4.active && !@ipv6.active
			@ipv4.active = @ipv6.active = true
		    end
		}
		@ipv4.signal_connect("toggled", &proc)
		@ipv6.signal_connect("toggled", &proc)

	    end
	end

	##
	##
	##
	class Input < Gtk::VBox
	    def initialize(param, sb)
		super()
		
		# 
		@p	= param
		@sb	= sb
		@ns	= []
		@ips	= []

		# Zone
		l10n_zone = $mc.get("ns_zone").capitalize
		@zone = Gtk::Entry::new

		hbox = Gtk::HBox::new(false, 5)
		hbox.pack_start(Gtk::Label::new(l10n_zone), false, true)
		hbox.pack_start(@zone, true, true)
	    
		zone_f = Gtk::Frame::new(l10n_zone)
		zone_f.add(hbox)

		# NS
		tbl  = Gtk::Table::new(MaxNS, 4, false)
		tbl.set_col_spacings(5)
		tbl.set_row_spacings(2)
		(0..MaxNS-1).each { |i|
		    l10n_ns  = $mc.get(i == 0 ? "ns_primary" \
				              : "ns_secondary").capitalize
		    l10n_ips = $mc.get("ns_ips")
		    lbl_ns   = Gtk::Label::new(l10n_ns ).set_alignment(0, 1)
		    lbl_ips  = Gtk::Label::new(l10n_ips).set_alignment(0, 1)
		    @ns[i]   = Gtk::Entry::new.set_usize(100, -1)
		    @ips[i]  = Gtk::Entry::new.set_usize(250, -1)
		    tbl.attach(lbl_ns,  0, 1, i, i+1, Gtk::SHRINK | Gtk::FILL)
		    tbl.attach(@ns[i],  1, 2, i, i+1)
		    tbl.attach(lbl_ips, 2, 3, i, i+1, Gtk::SHRINK | Gtk::FILL)
		    tbl.attach(@ips[i], 3, 4, i, i+1)
		}
		
		ns_f = Gtk::Frame::new($mc.get("ns_ns").upcase)
		ns_f.add(tbl)
		
		# Buttons
		@check = Gtk::Button::new("Check")
		@guess = Gtk::Button::new("Guess")
		@clear = Gtk::Button::new("Clear")

		@hbbox  = Gtk::HButtonBox::new
		@hbbox.pack_start(@check)
		@hbbox.pack_start(@guess)
		@hbbox.pack_start(@clear)

		
		#
		pack_start(zone_f)
		pack_start(ns_f)
		pack_start(@hbbox)


		#

		@check.signal_connect("clicked") { |w| 
		    @p.domain.name = input_dom.domain
		    @p.ipv4 = true
		    @p.verbose = "intro"
		    @q.push @p
		}

		@guess.signal_connect("clicked") { |w|
		    @hbbox.set_sensitive(false)
		    begin
			@p.domain.clear
			@p.domain.name = domain
			@p.domain.ns   = self.ns
			@p.domain.autoconf(@p.dns)
			self.ns = @p.domain.ns
			sb.push(1, "Name servers and/or addresses guessed")
		    rescue => e
			sb.push(1, e.to_s)
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
		@zone.get_text
	    end

	    def ns
		ns_list = [ ]
		(0..MaxNS-1).each { |i|
		    ns  = @ns [i].get_text.strip
		    ips = @ips[i].get_text.strip.split(/\s*,\s*|\s+/)
		    next if ns.empty?

		    if ips.empty?
			ns_list << [ ns ]
		    else
			ns_list << [ ns, ips ]
		    end
		}
		if ! ns_list.empty?
		    ns_list.collect { |ns, ips|
			if ips
			then ips_str = ips.join(",") ; "#{ns}=#{ips_str}" 
			else ns
			end
		    }.join(";")
		else
		    nil
		end
	    end

	    def ns=(ns_list) 
		if ns_list.length > MaxNS
		    raise ArgumentError, "Too many nameservers to display them"
		end

		i = 0
		ns_list.each_index { |i|
		    @ns [i].set_text(ns_list[i][0].to_s)
		    @ips[i].set_text(ns_list[i][1].join(", "))
		}

		(i+1..MaxNS-1).each { |i|
		    @ns [i].set_text("") ; @ips[i].set_text("")
		}
	    end
	end



	
	def initialize
	    @p    = Param::new
	    Thread::new { Gtk::main() }
	    @q = Queue::new
	end
	
	def parse
	    window = Gtk::Window::new
	    window.signal_connect("delete_event") {|*args| delete_event(*args) }
	    window.signal_connect("destroy") {|*args| destroy(*args) }
	    window.border_width = 10
	    
	    window.set_title("ZoneCheck")
	    
	    menubar   = Gtk::MenuBar::new
	    statusbar = Gtk::Statusbar::new
	    statusbar.push(1, "Toto")


	    input_dom = Input::new(@p, statusbar)
	    options_note = Option::new
	    info_note = Gtk::Frame::new
	    






	    notebook = Gtk::Notebook::new()
	    notebook.set_tab_pos(Gtk::POS_TOP)
	    notebook.append_page input_dom, Gtk::Label::new("Input")
	    notebook.append_page options_note, Gtk::Label::new("Options")


	    vbox = Gtk::VBox::new
	    vbox.pack_start(menubar)
	    vbox.pack_start(notebook)
	    vbox.pack_start(statusbar)

	    button = Gtk::Button::new("Hello World")
	    button.signal_connect("clicked") {|*args| hello(*args) }
	    button.signal_connect("clicked") {|*args| window.destroy }
	
	    window.add(vbox)

	    input_dom.show()
	    notebook.show()
	    statusbar.show()
	    menubar.show()
	    vbox.show()

	    window.show_all
	    @q.pop
	end
    end
end
