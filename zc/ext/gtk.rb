# $Id$

# 
# CONTACT     : zonecheck@nic.fr
# AUTHOR      : Stephane D'Alu <sdalu@nic.fr>
#
# CREATED     : 2003/01/06 15:18:23
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
