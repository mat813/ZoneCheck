# $Id$

# 
# CONTACT     : zonecheck@nic.fr
# AUTHOR      : Stephane D'Alu <sdalu@nic.fr>
#
# CREATED     : 2002/08/02 13:58:17
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


require 'thread'


module Publisher
    ##
    ##
    ##
    class Template # --> ABSTRACT <--
	attr_reader :progress
	attr_reader :rflag
	attr_reader :info

	def initialize(rflag, info, ostream=$stdout)
	    @rflag	= rflag
	    @info	= info
	    @o		= ostream
	    @mutex	= Mutex::new
	end

	def output ; @o ; end

	def synchronize(&block)
	    @mutex.synchronize(&block)
	end

	def setup(domain_name)
	end

	def status(domainname, i_count, w_count, f_count)
	    if f_count == 0
		tag = (w_count > 0) ? "res_succeed_but" : "res_succeed"
	    else
		tag = (w_count > 0) ? "res_failed_and" : "res_failed"
	    end
	    $mc.get(tag) % [ w_count ]
	end

	def begin ; end
	def end   ; end
    end
end
