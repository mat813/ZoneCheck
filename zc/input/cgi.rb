# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/08/02 13:58:17
#
# COPYRIGHT: AFNIC (c) 2003
# CONTACT  : zonecheck@nic.fr
# LICENSE  : GPL v2.0 (or MIT/X11-like after agreement)
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS: (see also CREDITS file)
#
#

require 'cgi'


module Input
    ##
    ## Processing parameters from CGI (Common Gateway Interface)
    ##
    ## WARN: don't forget to update locale/cgi.*
    ##
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
    ##  - verbose  = [ i|intro, n|testname, x|explain, d|details, 
    ##                 t|testdesc, c|counter ]
    ##      - intro
    ##      - testname
    ##      - explain
    ##      - details
    ##      - progress = [ testdesc | counter ]
    ##  - output   = [ straight, consolidation, text, html ]
    ##      - format   = html|text
    ##  - error    = [ af|allfatal, aw|allwarning, std|standard,
    ##                s|stop, ns|nostop ]
    ##      - errorlvl  = [ af|allfatal | aw|allwarning | std|standard ]
    ##      - dontstop 
    ##  - transp   = [ ipv4, ipv6, udp, tcp, std ]
    ##      - transp3   = [ ipv4, ipv6 ]
    ##      - transp4   = [ udp | tcp | std ]
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
    class CGI
	with_msgcat "cgi.%s"

	MaxNS = 8	# Maximum number of NS taken into account

	def initialize
	    @cgi  = ::CGI::new
	end

	def parse(p)
	    # Lang
	    # => The message catalogue need to be replaced
	    if @cgi.has_key?("lang")
		begin
		    lang = @cgi["lang"]
		    if $mc.available?(ZC_LANG_FILE, lang)
			$mc.lang = lang
			$mc.reload
		    end
		rescue ArgumentError
		end
	    end

	    # Batch
	    if @cgi.has_key?("batchdata")
		p.batch = Param::BatchData::new(@cgi["batchdata"])
	    end

	    # Quiet, One
	    p.rflag.quiet = true if @cgi.has_key?("quiet")
	    p.rflag.one   = true if @cgi.has_key?("one")

	    # Verbose
	    if @cgi.has_key?("verbose")
		p.verbose = @cgi.params["verbose"].join(",")
	    else
		p.verbose = "testname"		if @cgi.has_key?("testname")
		p.verbose = "intro"             if @cgi.has_key?("intro")
		p.verbose = "explain"           if @cgi.has_key?("explain")
		p.verbose = "details"		if @cgi.has_key?("details")
		p.verbose = @cgi["progress"]    if @cgi.has_key?("progress")
	    end

	    # Output
	    if @cgi.has_key?("output")
		p.output = @cgi.params["output"].join(",")
	    else
		p.output = if @cgi.has_key?("format")
			   then @cgi["format"]
			   else "html"
			   end
	    end

	    # Error
	    if @cgi.has_key?("error")
		p.error  = @cgi.params["error"].join(",")
	    else
		errorlvl  = if @cgi.has_key?("errorlvl")
			    then @cgi.params["errorlvl"].delete_if { |e| 
			           e =~ /^\s*$/ }
			    else []
			    end
		errorstop = @cgi.has_key?("dontstop") ? "nostop" : "stop"
		p.error   = (errorlvl + [ errorstop ]).join(",")
	    end

	    # Transp
	    if @cgi.has_key?("transp")
		p.transp = @cgi.params["transp"].join(",")
	    else
		p.transp = ((@cgi.params["transp3"] || []) + 
			    (@cgi.params["transp4"] || [])).join(",")
	    end

	    # Category
	    if @cgi.has_key?("category")
		p.category = @cgi.params["category"].join(",")
	    else
		cat = [ ]
		cat << "!mail"		unless @cgi.has_key?("chkmail")
		cat << "!rir"		unless @cgi.has_key?("chkrir")
		cat << "!dns:axfr"	unless @cgi.has_key?("chkzone")
		if ! cat.empty?
		    cat << "+"
		    p.test.categories = cat.join(",")
		end
	    end

	    # NS and IPs
	    if @cgi.has_key?("ns")
		p.domain.ns = @cgi.params["ns"].join(";")
	    else
		ns_list = [ ]
		(0..MaxNS-1).each { |i|
		    next unless cgi_ns = @cgi.params["ns#{i}"] || ""
		    next unless cgi_ns.length > 0
		    next if     (ns = cgi_ns[0]).empty?
		    
		    cgi_ips = @cgi.params["ips#{i}"] || ""
		    if cgi_ips.nil? || cgi_ips.length == 0 
			ns_list << [ ns ]
		    else
			# XXX: cgi_ips[x].empty?
			ips = cgi_ips.collect { |a| 
			    a.split(/\s*,\s*|\s+/) }.flatten.compact
			ns_list << [ ns, ips ]
		    end
		}
		if ! ns_list.empty?
		    p.domain.ns   = ns_list.collect { |ns, ips|
			if ips
			    ips_str = ips.join(",")
			    "#{ns}=#{ips_str}" 
			else
			    ns
			end
		    }.join(";")
		end
	    end

	    # Zone/Domain
	    zone = @cgi["zone"]
	    zone.strip! if zone
	    return false if zone.nil? || zone.empty?
	    p.domain.name = zone

	    # Ok
	    true
	end

	def interact(p, c, tm)
	    # XXX: not good place
	    p.rflag.autoconf
	    p.publisher.autoconf(p.rflag)
	    puts @cgi.header({ "type"    => p.publisher.engine.class::Mime,
			       "charset" => "UTF-8" })
	    true
	end

	def usage(errcode, io=$stdout)
	    io.puts @cgi.header({ "type"    => "text/plain",
				  "charset" => "UTF-8" })
	    io.puts $mc.get("input_cgi_usage")
	    exit errcode unless errcode.nil?
	end

	def error(str, errcode=nil, io=$stdout)
	    l10n_error = $mc.get("w_error").upcase
	    io.puts @cgi.header({ "type"    => "text/plain",
				  "charset" => "UTF-8" })
	    io.puts "#{l10n_error}: #{str}"
	    exit errcode unless errcode.nil?
	end
    end
end
