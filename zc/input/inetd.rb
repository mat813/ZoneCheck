# $Id$

# 
# CONTACT     : zonecheck@nic.fr
# AUTHOR      : Stephane D'Alu <sdalu@nic.fr>
#
# CREATED     : 2003/08/27 12:02:17
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
## usage: PROGNAME: [-hV] [-46] [-c conf]
##         --lang          Select another language (en, fr, ...)
##     -h, --help          Show this message
##     -V, --version       Display version and exit
##     -c, --config        Specify location of the configuration file
##         --testdir       Location of the directory holding tests
##     -r, --resolver      Resolver to use for guessing 'ns' information
##     -4, --ipv4          Only allow to check the zone with IPv4 connectivity
##     -6, --ipv6          Only allow to check the zone with IPv6 connectivity
##
##
## Command           Args
##   ?|help           0     This message
##   q|quit|exit      0     Leave ZoneCheck
##   check            0     Launch the zone checking process
##   zone|domain      1     Zone to test
##   nslist           0+    Set the list of the zone nameservers
##   set              1-2   Option to set (see options)
##   unset            1     Option to unset (see options)
##   preset           1     Preset configuration (supported: classic)
## 
## Options           Args
##   lang             1     Select another language (en, fr, ...)
##   one              0     Only display the most relevant message
##   quiet            0     Don't display extra titles
##   tagonly          0     Display only tag (suitable for scripting)
##   category         1+    Only perform test for the specified category
##   verbose          1+    Display extra information (see verbose)
##   output           1+    Output (see output)
##   error            1+    Behaviour in case of error (see error)
##   transp           1+    Transport/routing layer (see transp)
##   option           1+    Set extra options (-,-opt,opt,opt=foo)
## 
## Arguments for Options
##   verbose:             [intro/testname/explain/details]
##                        [reportok|fatalonly] [testdesc|counter]
##     intro          [i]  Print summary for domain and associated nameservers
##     testname       [n]  Print the test name
##     explain        [x]  Print an explanation for failed tests
##     details        [d]  Print a detailed description of the failure
##     reportok       [o]  Still report passed test
##     fatalonly      [f]  Print fatal errors only
##     testdesc       [t]  Print the test description before running it
##     counter        [c]  Print a test counter
## 
##   output:               [byseverity|byhost] [text|html]
##     byseverity    *[bs] Output is sorted/merged by severity
##     byhost         [bh] Output is sorted/merged by host
##     text          *[t]  Output plain text
##     html           [h]  Output HTML
## 
##   error:                [allfatal|allwarning|dfltseverity] [stop|nostop]
##     allfatal       [af] All error are considered fatal
##     allwarning     [aw] All error are considered warning
##     dfltseverity  *[ds] Use the severity associated with the test
##     stop          *[s]  Stop on the first fatal error
##     nostop         [ns] Never stop (even on fatal error)
## 
##   transp:               [ipv4/ipv6] [udp|tcp|std]
##     ipv4          *[4]  Use IPv4 routing protocol
##     ipv6          *[6]  Use IPv6 routing protocol
##     udp            [u]  Use UDP transport layer
##     tcp            [t]  Use TCP transport layer
##     std           *[s]  Use UDP with fallback to TCP for truncated messages
## 
## Example
##   preset classic
##   zone foorbar.com
##   check
## 
module Input
    class INETD
	with_msgcat "inetd.%s"

	def initialize
	    @prompt = "zonecheck> "
	end

	def parse(p)
	    begin
		ipv6, ipv4 = false, false

		opts = GetoptLong::new(
		[ '--help',	'-h',	GetoptLong::NO_ARGUMENT       ],
		[ '--version',	'-V',	GetoptLong::NO_ARGUMENT       ],
		[ '--lang',		GetoptLong::REQUIRED_ARGUMENT ],
		[ '--debug',	'-d',   GetoptLong::REQUIRED_ARGUMENT ],
		[ '--config',	'-c',   GetoptLong::REQUIRED_ARGUMENT ],
		[ '--testdir',	        GetoptLong::REQUIRED_ARGUMENT ],
		[ '--resolver',	'-r',   GetoptLong::REQUIRED_ARGUMENT ],
		[ '--ipv4',	'-4',	GetoptLong::NO_ARGUMENT       ],
		[ '--ipv6',	'-6',	GetoptLong::NO_ARGUMENT       ] )

		opts.each { |opt, arg|
		    case opt
		    when '--help'      then usage(EXIT_USAGE, $console.stdout)
		    when '--version'
			l10n_version = $mc.get('input_version') % $zc_version
			l10n_version.gsub!(/PROGNAME/, PROGNAME)
			$console.stdout.puts l10n_version
			exit EXIT_OK
		    when '--quiet'     then p.rflag.quiet	= true
		    when '--debug'     then $dbg.level		= arg
		    when '--lang'      then $locale.lang	= arg
		    when '--config'    then p.fs.cfgfile	= arg.untaint
		    when '--testdir'   then p.fs.testdir	= arg.untaint
		    when '--resolver'  then p.resolver.local	= arg
		    when '--ipv6'      then ipv6		= true
		    when '--ipv4'      then ipv4		= true
		    end
		}
	    rescue GetoptLong::Error
		return false
	    end

	    ipv6 = ipv4 = true if !ipv6 && !ipv4
	    $ipv4_stack &&= ipv4
	    $ipv6_stack &&= ipv6

	    true
	end

	def interact(p, c, tm, io=$console.stdout)
	    io.puts $mc.get('input_inetd_welcome').gsub('VERSION', ZC_VERSION)

	    io.print @prompt
	    io.flush
	    
	    while true do
		# Check if ^D otherwise read a full line
		char = $stdin.getc
		break if char.nil? || char == 4
		$stdin.ungetc(char)
		line = $stdin.gets
		break if line.nil?

		line.strip!
		begin
		    case line
		    when ''
		    # Set
		    when /^preset\s+(\w+)$/
			case $1
			when 'classic'
			    p.verbose		= 'i,x,d,c'
			    io.puts '+ set verbose i,x,d,c'
			when 'fatal'
			    p.verbose		= 'x,d,f'
			    p.rflag.quiet	= true
			    io.puts '+ set verbose x,d,f'
			    io.puts '+ set quiet'
			else
			    error($mc.get('input_inetd_unknown_preset') % $1)
			end
		    when /^set\s+(\w+)\s+(.*)$/
			case $1
			when 'verbose'	then p.verbose		= $2
			when 'output'	then p.output		= $2
			when 'error'	then p.error		= $2
			when 'transp'	then p.transp		= $2
			when 'option'	then p.option		= $2
			when 'category'	then p.category		= $2
			when 'quiet'	then p.rflag.quiet	= true
			when 'one'	then p.rflag.one	= true
			when 'tagonly'	then p.rflag.tagonly	= true
			when 'lang'	then $locale.lang	= $2
			end
		    when /^nslist\s+(.*)/	   then p.domain.ns	= $1
		    when /^(?:zone|domain)\s+(.*)/ then p.domain.name	= $1
		    # Unset
		    when /^unset\s+(\w+)$/
			case $1
			when 'quiet'	then p.rflag.quiet	= false
			when 'one'	then p.rflag.one	= false
			end
		    #
		    when '?', 'help'
			io.puts $mc.get('input_inetd_help')
		    # Leave interaction loop
		    when 'check'		then return true
		    when 'quit', 'q', 'exit'	then return false
			
		    # What did he said?!
		    else
			error($mc.get('input_inetd_what'))
		    end
		rescue Param::ParamError => e
		    error(e.to_s)
		end

		io.print @prompt
		io.flush
	    end

	    io.puts # Skip a line
	    return false
	end

	def usage(errcode, io=$console.stdout)
	    io.puts $mc.get('input_inetd_usage').gsub('PROGNAME', PROGNAME)
	    io.flush
	    exit errcode unless errcode.nil?
	end

	def error(str, errcode=nil, io=$console.stdout)
	    l10n_error = $mc.get('word:error').upcase
	    io.puts "#{l10n_error}: #{str}"
	    io.flush
	    exit errcode unless errcode.nil?
	end
    end
end
