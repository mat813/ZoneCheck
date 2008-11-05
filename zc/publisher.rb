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

    def self.to_bind_duration(src)
	sec  = src % 60 ; src /= 60
        min  = src % 60 ; src /= 60
	hour = src % 24 ; src /= 24
        day  = src % 7  ; src /= 7
	week = src

	str  = ''
	str += "#{week}W" if week > 0
	str += "#{day}D"  if day  > 0
	str += "#{hour}H" if hour > 0
	str += "#{min}M"  if min  > 0
	str += "#{sec}S"  if sec  > 0
	
	str
    end

    ##
    ##
    ##
    class Template # --> ABSTRACT <--
	attr_reader :progress, :xmltrans
	attr_reader :info, :rflag, :option
	attr_writer :info

	def initialize(rflag, option, ostream=$stdout)
	    @rflag	= rflag
	    @option	= option
	    @o		= ostream
	    @mutex	= Mutex::new
	    @info	= nil
	end

	def constants=(const)
	    @xmltrans.const = const
	end

	def output ; @o ; end

	def synchronize(&block)
	    @mutex.synchronize(&block)
	end

	def setup(domain_name)
	end

	def status(domainname, i_count, w_count, f_count)
	    if f_count == 0
		tag = (w_count > 0) ? "res_success_but" : "res_success"
	    else
		tag = (w_count > 0) ? "res_failure_and" : "res_failure"
	    end
	    $mc.get(tag) % [ w_count ]
	end

	def begin ; end
	def end   ; end


	#-- [protected] ---------------------------------------------
	protected

	def severity_description(i_unexp, w_unexp, f_unexp)
	    if @rflag.tagonly
		i_tag = ZC_Config::Info
		w_tag = ZC_Config::Warning
		f_tag = ZC_Config::Fatal
	    else
		i_tag = $mc.get('word:info_id')
		w_tag = $mc.get('word:warning_id')
		f_tag = $mc.get('word:fatal_id')
	    end
	    
	    i_tag = i_tag.upcase if i_unexp
	    w_tag = w_tag.upcase if w_unexp
	    f_tag = f_tag.upcase if f_unexp

	    [ i_tag, w_tag, f_tag ]
	end

	def status_message(checkname, desc, severity)
	    # WARN: MsgCat::TEST only defines MsgCat::NAME but
	    #       it is only generated on error
	    type = desc.check ? MsgCat::CHECK : MsgCat::TEST

	    if severity.nil?
		@xmltrans.apply($mc.get(checkname, type, MsgCat::SUCCESS))
	    elsif desc.error
		l10n_name = @xmltrans.apply($mc.get(checkname, 
						   type, MsgCat::NAME))
		"[TEST #{l10n_name}]: #{desc.error}"
	    else
		@xmltrans.apply($mc.get(checkname, type, MsgCat::FAILURE))
	    end
	end
    end
end
