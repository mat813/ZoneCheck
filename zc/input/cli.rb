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
## Processing parameters from CLI (Command Line Interface)
##
## WARN: don't forget to update locale/cli.*
##
## ----------------------------------------------------------------------
##
## usage: PROGNAME: [-hqV] [-etvo opt] [-46] [-n ns,..] [-c conf] domainname
##     -q, --quiet         Don't display extra titles
##         --lang          Select another language (en, fr, ...)
##     -h, --help          Show this message
##     -V, --version       Display version and exit
##     -B, --batch         Batch mode (read from file or stdin '-')
##     -c, --config        Specify location of the configuration file
##         --testdir       Location of the directory holding tests
##     -C, --category      Only perform test for the specified category
##     -T, --test          Name of the test to perform
##         --testlist      List all the available tests
##         --testdesc      Give a description (name,expl,error) of the test
##     -r, --resolver      Resolver to use for guessing 'ns' information
##     -n, --ns            List of nameservers for the domain
##     -1, --one           Only display the most relevant message
##     -g, --tagonly       Display only tag (suitable for scripting)
##     -e, --error         Behaviour in case of error (see error)
##     -t, --transp        Transport/routing layer (see transp)
##     -v, --verbose       Display extra information (see verbose)
##     -o, --output        Output (see output)
##     -4, --ipv4          Only check the zone with IPv4 connectivity
##     -6, --ipv6          Only check the zone with IPv6 connectivity
## 
##   verbose:              [intro/explain/details] [testdesc|counter]
##     intro          [i]  Print summary for domain and associated nameservers
##     testname       [n]  Print the test name
##     explain        [x]  Print an explanation for failed tests
##     details        [d]  Print a detailed description of the failure
##     reportok       [o]  Still report passed test
##     testdesc       [t]  Print the test description before running it
##     counter        [c]  Print a test counter
## 
##   output:               [byseverity|byhost] [text|html]
##     byseverity    *[bs] Output is sorted/merged by severity
##     byhost         [bh] Output is sorted/merged by host
##     text          *[t]  Output plain text
##     html           [h]  Output HTML
## 
##   error:                [allfatal|allwarning] [stop|nostop]
##     allfatal       [af] All error are considered fatal
##     allwarning     [aw] All error are considered warning
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
module Input
    class CLI
	with_msgcat "cli.%s"

	def initialize
	    @opts = GetoptLong.new(* opts_definition)
	    @opts.quiet = true
	end

	def opts_definition
	    [   [ "--help",	"-h",	GetoptLong::NO_ARGUMENT       ],
		[ "--version",	'-V',	GetoptLong::NO_ARGUMENT       ],
		[ "--quiet",	"-q",	GetoptLong::NO_ARGUMENT       ],
		[ "--lang",		GetoptLong::REQUIRED_ARGUMENT ],
		[ "--debug",	"-d",   GetoptLong::REQUIRED_ARGUMENT ],
		[ "--batch",	"-B",   GetoptLong::REQUIRED_ARGUMENT ],
		[ "--config",	"-c",   GetoptLong::REQUIRED_ARGUMENT ],
		[ "--testdir",	        GetoptLong::REQUIRED_ARGUMENT ],
		[ "--category", "-C",   GetoptLong::REQUIRED_ARGUMENT ],
		[ "--test",     "-T",   GetoptLong::REQUIRED_ARGUMENT ],
		[ "--testlist",         GetoptLong::NO_ARGUMENT       ],
		[ "--testdesc",         GetoptLong::REQUIRED_ARGUMENT ],
		[ "--resolver",	"-r",   GetoptLong::REQUIRED_ARGUMENT ],
		[ "--ns",	"-n",   GetoptLong::REQUIRED_ARGUMENT ],
		[ "--ipv4",	"-4",	GetoptLong::NO_ARGUMENT       ],
		[ "--ipv6",	"-6",	GetoptLong::NO_ARGUMENT       ],
		[ "--one",	"-1",	GetoptLong::NO_ARGUMENT       ],
		[ "--tagonly",	"-g",   GetoptLong::NO_ARGUMENT       ],
		[ "--error",	"-e",	GetoptLong::REQUIRED_ARGUMENT ],
		[ "--transp",	"-t",	GetoptLong::REQUIRED_ARGUMENT ],
		[ "--verbose",	"-v",   GetoptLong::OPTIONAL_ARGUMENT ],
		[ "--output",	"-o",   GetoptLong::REQUIRED_ARGUMENT ],
		[ "--option",           GetoptLong::REQUIRED_ARGUMENT ],
		#
		# Let's have some fun
		[ "--makecoffee",       GetoptLong::NO_ARGUMENT       ],
		[ "--coffee",           GetoptLong::NO_ARGUMENT       ] ]
        end

	def opts_analyse(p)
	    @opts.each do |opt, arg|
		case opt
		when "--help"      then usage(EXIT_USAGE, $stdout)
		when "--version"
		    l10n_version = $mc.get("input_version") % $zc_version
		    l10n_version.gsub!(/PROGNAME/, PROGNAME)
		    $console.stdout.puts l10n_version
		    exit EXIT_OK
		when "--quiet"     then p.rflag.quiet		= true
		when "--debug"     then $dbg.level		= arg
		when "--lang"
		    if $mc.available?(ZC_LANG_FILE, arg)
			$mc.lang = arg
			$mc.reload
		    end
		when "--batch"     then p.batch			= arg
		when "--config"    then p.fs.cfgfile		= arg.untaint
		when "--testdir"   then p.fs.testdir		= arg.untaint
		when "--category"  then p.test.categories	= arg
		when "--test"      then p.test.tests		= arg
		when "--testlist"  then p.test.list		= true
		when "--testdesc"  then p.test.desctype		= arg
		when "--resolver"  then p.resolver.local	= arg
		when "--ns"        then p.domain.ns		= arg
		when "--ipv6"      then p.network.ipv6		= true
		when "--ipv4"      then p.network.ipv4		= true
		when "--one"       then p.rflag.one		= true
		when "--tagonly"   then p.rflag.tagonly		= true
		when "--error"     then p.error			= arg
		when "--transp"    then p.transp		= arg
		when "--verbose"   then p.verbose		= arg
		when "--output"    then p.output		= arg
		when "--option"    then p.option	       << arg
		#
		# Let's have some fun
		when "--makecoffee"
		    $console.stdout.print <<EOT
#{PROGNAME}: I'm not currently designed for that task.
\tBut if you really want this option added in future release, 
\tyou should see with the maintainer: \"#{ZC_MAINTAINER}\".
EOT
		    exit EXIT_OK
		when "--coffee"
		    $console.stdout.puts "#{PROGNAME}: No thank you, I prefer tea."
		    exit EXIT_OK
		end
	    end
	end
	
	def args_analyse(p)
	    if p.batch
		if !ARGV.empty?
		    raise Param::ParamError, 
			$mc.get("xcp_param_batch_nodomain")
		end
	    else
		if !(ARGV.length == 1)
		    raise Param::ParamError, 
			$mc.get("xcp_param_domain_expected") 
		end
		p.domain.name = ARGV[0]
	    end
	end

	def parse(p)
	    begin
		opts_analyse(p)
		args_analyse(p) unless p.test.list || p.test.desctype
	    rescue GetoptLong::InvalidOption, GetoptLong::MissingArgument
		return false
	    end
	    true
	end

	def interact(p, c, tm)
	    true
	end

	def usage(errcode, io=$console.stderr)
	    io.print $mc.get("input_cli_usage").gsub("PROGNAME", PROGNAME)
	    exit errcode unless errcode.nil?
	end

	def error(str, errcode=nil, io=$console.stderr)
	    l10n_error = $mc.get("w_error").upcase
	    io.puts "#{l10n_error}: #{str}"
	    exit errcode unless errcode.nil?
	end
    end
end
