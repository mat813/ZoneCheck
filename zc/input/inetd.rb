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

require 'getoptlong'
require 'param'

##
## Processing parameters from INETD
##
## WARN: don't forget to update locale/inetd.*
##
## ----------------------------------------------------------------------
##
##

module Input
    class INETD
	with_msgcat "cgi.%s"

	def initialize
	end

	def parse(p)
	    true
	end

	def interact(p, c, tm)
	    puts "Welcome to Zonecheck #{$zc_version}"
	    puts "http://www.zonecheck.fr/"
	    puts
	    $stdout.flush

	    p.transp = "ipv4"
	    while line = $stdin.gets do
		line.strip!
		case line
	        # Set option
		when /^set\s+(\w+)\s+(.*)$/
		    case $1
		    when 'verbose'	then p.verbose		= $2
		    when 'output'	then p.output		= $2
		    when 'error'	then p.error		= $2
		    when 'transp'	then p.transp		= $2
		    when 'option'	then p.option		= $2
		    when 'category'	then p.category		= $2
		    when 'quiet'	then p.rflag.quiet	= true
		    when 'one'		then p.rflag.one	= true
		    when 'lang'
			begin
			    if $mc.available?(ZC_LANG_FILE, $2)
				$mc.lang = $2
				$mc.reload
			    end
			rescue ArgumentError
			end
		    end
		# Unset option
		when /^unset\s+(\w+)$/
		    case $1
		    when 'quiet'	then p.rflag.quiet	= false
		    when 'one'		then p.rflag.one	= false
		    end
		#
		when /DOM=(.*)/ then p.domain.name = $1
		when /NS=(.*)/  then p.domain.ns   = $1
		# Quit
		when /^(?:quit|q|exit)$/	then return false
		end
	    end

	    true
	end

	def usage(errcode, io=$stdout)
	    io.puts $mc.get('input_cgi_usage')
	    exit errcode unless errcode.nil?
	end

	def error(str, errcode=nil, io=$stdout)
	    l10n_error = $mc.get('w_error').upcase
	    io.puts "#{l10n_error}: #{str}"
	    exit errcode unless errcode.nil?
	end
    end
end
