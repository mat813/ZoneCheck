# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2003/01/06 15:18:23
#
# COPYRIGHT: AFNIC (c) 2003
# CONTACT  : zonecheck@nic.fr
# LICENSE  : GPL v2.0
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS:
#
#

module Gtk
    class Button
	alias _initialize initialize
	def initialize(*args)
	    if (args.length > 1)
		lhs = case args[0]
		      when Symbol     then Gtk::Image::new(args[0])
		      when Gtk::Image then args[0]
		      else return _initialize(*args) 
		      end
		rhs = case args[1]
		      when String     then Gtk::Label::new(args[1])
		      else return _initialize(*args) 
		      end

		hbox  = Gtk::HBox::new(false)
		hbox.pack_start(lhs, false, false, 2)
		hbox.pack_start(rhs, false, false, 0)
		align = Gtk::Alignment::new(0.5, 0.5, 0, 0)
		align.child = hbox
		_initialize()
		self.child = align
		return self
	    else
		return  _initialize(*args)
	    end
	end
    end
end
