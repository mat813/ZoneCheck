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

require 'cgi'
require 'param'

##
## Processing parameters from CGI (Common Gateway Interface)
##
## WARN: don't forget to update locale/cgi.*
##
## ----------------------------------------------------------------------
##
## For obvious security reasons the following parameters shouldn't
## be set through the CGI:
##  - configfile
##  - testdir
##  - debug
##  - resolver
##
## parameters:
##  - lang     = [ fr | en | ... ]
##  - quiet
##  - one
##  - option
##  - verbose  = [ i|intro, n|testname, x|explain, d|details, 
##                 t|testdesc, c|counter, o|reportok ]
##      - intro
##      - testname
##      - explain
##      - details
##      - progress = [ t|testdesc | c|counter ]
##      - reportok
##      - fatalonly
##  - output   = [ bs|byseverity, bh|byhost, text, html ]
##      - report   = bs|byseverity | bh|byhost
##      - format   = h|html | t|text
##  - error    = [ af|allfatal, aw|allwarning, ds|dfltseverity,
##                s|stop, ns|nostop ]
##      - errorlvl  = [ af|allfatal | aw|allwarning | ds|dfltseverity ]
##      - dontstop 
##  - transp   = [ ipv4, ipv6, udp, tcp, std ]
##      - transp3   = [ ipv4, ipv6 ]
##      - transp4   = [ udp | tcp | std ]
##  - profile  = profilename
##  - category = cat1,!cat2:subcat1,cat2,!cat3,+
##      - chkmail (!mail)
##      - chkrir  (!rir)
##      - chkzone (!dns:axfr)
##  - ns       = ns1=ip1,ip2;ns2=ip3;ns3
##      - ns0  .. nsX   = nameserver name
##      - ips0 .. ipsX  = coma separated ip addresses
##  - zone     = zone to test
##
## exemple:
##  zone=afnic.fr&intro&progress=testdesc&transp=ipv4,ipv6,std
##  zone=afnic.fr&verbose=i,t&ns=ns1.nic.fr%3bns2.nic.fr%3bns3.nic.fr
##  zone=afnic.fr&verbose=i,t&ns=ns1.nic.fr=192.93.0.1&ns=ns2.nic.fr&ns=bns3.nic.fr
##
module Input
    class CGI
	with_msgcat "cgi.%s"

	MaxNS = 20       # Maximum number of NS taken into account

	def allow_preset ; false ; end

	def initialize
	    @cgi  = ::CGI::new
	end

	def restart
	    @cgi  = ::CGI::new
	end

	def parse(p)
	    # Direct script invocation is not authorized
	    return false if @cgi.params.empty?

	    # Parse zone data and options
	    parse_zonedata(p) && parse_options(p)
	end

	def redirect(url, errcode, data=nil, io=$console.stdout)
	    io.puts @cgi.header({ 'status'   => 'REDIRECT',
				  'location' => url,
				  'type'     => 'text/plain',
				  'charset'  => $console.encoding })
	    io.puts data if data
	    exit errcode unless errcode.nil?
	end

	def interact(p, c, tm, io=$console.stdout)
	    # XXX: not good place
	    p.rflag.autoconf
	    p.publisher.autoconf(p.rflag, p.option)
	    puts @cgi.header({ 'type'    => p.publisher.engine.class::Mime,
			       'charset' => $console.encoding })
	    true
	end

	def usage(errcode, io=$console.stdout)
	    io.puts @cgi.header({ 'type'    => 'text/plain',
				  'charset' => $console.encoding })
	    io.puts $mc.get('input:cgi:usage')
	    exit errcode unless errcode.nil?
	end

	def error(str, errcode=nil, io=$console.stdout)
	    l10n_error = $mc.get('word:error').upcase
	    io.puts @cgi.header({ 'type'    => 'text/plain',
				  'charset' => $console.encoding })
	    io.puts "#{l10n_error}: #{str}"
	    exit errcode unless errcode.nil?
	end


	#-- PRIVATE -------------------------------------------------
	private

	def parse_options(p)
	    # Lang
	    # => The message catalogue need to be replaced
	    if @cgi.has_key?('lang')
		$locale.lang = @cgi['lang']
	    end

	    # Quiet, One
	    p.rflag.quiet = true if @cgi.has_key?('quiet')
	    p.rflag.one   = true if @cgi.has_key?('one')

	    # Verbose
	    if @cgi.has_key?('verbose')
		p.verbose = @cgi.params['verbose'].join(',')
	    else
		p.verbose = 'testname'		if @cgi.has_key?('testname')
		p.verbose = 'intro'             if @cgi.has_key?('intro')
		p.verbose = 'explain'           if @cgi.has_key?('explain')
		p.verbose = 'details'		if @cgi.has_key?('details')
		p.verbose = 'reportok'		if @cgi.has_key?('reportok')
		p.verbose = 'fatalonly'         if @cgi.has_key?('fatalonly')
		p.verbose = @cgi['progress']    if @cgi.has_key?('progress')
	    end

	    # Output
	    if @cgi.has_key?('output')
		p.output = @cgi.params['output'].join(',')
	    else
		p.output = if @cgi.has_key?('format')
			   then @cgi['format']
			   else 'html'
			   end
		p.output = if @cgi.has_key?('report')
			   then @cgi['report']
			   else 'byseverity'
			   end
	    end

	    # Error
	    if @cgi.has_key?('error')
		p.error  = @cgi.params['error'].join(',')
	    else
		errorlvl  = if @cgi.has_key?('errorlvl')
			    then @cgi.params['errorlvl'].delete_if { |e| 
			           e =~ /^\s*$/ }
			    else []
			    end
		errorstop = @cgi.has_key?('dontstop') ? 'nostop' : 'stop'
		p.error   = (errorlvl + [ errorstop ]).join(',')
	    end

	    # Transp
	    if @cgi.has_key?('transp')
		p.transp = @cgi.params['transp'].join(',')
	    else
		p.transp = ((@cgi.params['transp3'] || []) + 
			    (@cgi.params['transp4'] || [])).join(',')
	    end

	    # Profile
	    if @cgi.has_key?('profile')
		p.preconf.profile = @cgi['profile']
	    end

	    # Category
	    if @cgi.has_key?('category')
		p.test.categories = @cgi.params['category'].join(',')
	    else
		cat = [ ]
		cat << '!mail'		unless @cgi.has_key?('chkmail')
		cat << '!rir'		unless @cgi.has_key?('chkrir')
		cat << '!dns:axfr'	unless @cgi.has_key?('chkzone')
		if ! cat.empty?
		    cat << '+'
		    p.test.categories = cat.join(',')
		end
	    end

	    # Option
	    if @cgi.has_key?('option')
		p.option << @cgi.params['option'].join(',')
	    end

	    # Ok
	    true
	end

	def parse_zonedata(p)
	    # Batch
	    if @cgi.has_key?('batchdata')
		p.batch = Param::BatchData::new(@cgi['batchdata'])
	    end

	    # NS and IPs
	    if @cgi.has_key?('ns')
		p.domain.ns = @cgi.params['ns'].join(';')
	    else
		ns_list = [ ]
		(0..MaxNS-1).each { |i|
		    next unless cgi_ns = @cgi.params["ns#{i}"]
		    next unless !cgi_ns.empty?
		    next unless ns = cgi_ns[0]
		    next unless !ns.empty?
                   
		    cgi_ips = @cgi.params["ips#{i}"] || ''
		    if cgi_ips.nil? || cgi_ips.length == 0 
			ns_list << [ ns ]
		    else
			ips = cgi_ips.collect { |a| 
			    a.split(/\s*,\s*|\s+/) }.flatten.compact
			ns_list << [ ns, ips ]
		    end
		}

#		i       = 0
#		while ((cgi_ns = @cgi.params["ns#{i}"])			&&
#		       !cgi_ns.empty?					&&
#		       (ns = cgi_ns[0])					&&
#		       !ns.empty?) do
#		    cgi_ips = @cgi.params["ips#{i}"] || []
#		    if cgi_ips.nil? || cgi_ips.length == 0 
#			ns_list << [ ns ]
#		    else
#			ips = cgi_ips.collect { |a| 
#			    a.split(/\s*,\s*|\s+/) }.flatten.compact
#			ns_list << [ ns, ips ]
#		    end
#		    i += 1
#		end

		if ! ns_list.empty?
		    p.domain.ns   = ns_list.collect { |ns, ips|
			ips ? "#{ns}=#{ips.join(',')}" : ns }.join(';')
		end
	    end

	    # Zone/Domain
	    if p.batch.nil?
		zone = @cgi['zone']
		zone.strip! if zone
		if zone.nil? || zone.empty?
		    # If we got a referer send him back to this page,
		    # otherwise assume it was an attempt of a direct
		    # script invocation (and send a usage page)
		    if ENV.has_key?('HTTP_REFERER')
		    then redirect(ENV['HTTP_REFERER'], EXIT_USAGE)
		    else return false
		    end
		end
		p.domain.name = zone
	    end

	    # Ok
	    true
	end
    end
end
