# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/08/02 13:58:17
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

require 'cgi'


module Input
    ##
    ## Processing parameters from CGI (Common Gateway Interface)
    ##
    ## For obvious security reasons the following parameters shouldn't
    ## be set through the CGI:
    ##  - configfile
    ##  - testdir
    ##  - debug
    ##  - resolver
    ##
    ## parameters:
    ##  - lang
    ##  - quiet
    ##  - one
    ##  - verbose [ intro, explain, details, testdesc, counter ]
    ##      - intro    = true|false
    ##      - explain  = true|false
    ##      - details  = true|false
    ##      - progress = testdesc|counter
    ##
    class CGI
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
			$mc.clear
			$mc.lang = lang
			$mc.read(ZC_LANG_FILE)
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
		p.verbose = "intro"             if @cgi.has_key?("intro")
		p.verbose = "explain"           if @cgi.has_key?("explain")
		p.verbose = "details"		if @cgi.has_key?("details")
		p.verbose = @cgi["progress"]    if @cgi.has_key?("progress")
	    end

	    # Output
	    if @cgi.has_key?("output")
		p.output = @cgi.params["output"].join(",")
	    else
		p.output = @cgi["format"]
	    end

	    # Error
	    if @cgi.has_key?("error")
		p.error  = @cgi.params["error"].join(",")
	    else
		errorlvl  = @cgi.params["errorlvl"].delete_if { |e| 
		    e =~ /^\s*$/ }
		errorstop = @cgi.has_key?("errorstop") ? "stop" : "nostop"
		p.error   = (errorlvl + [ errorstop ]).join(",")
	    end

	    # Transp
	    if @cgi.has_key?("transp")
		p.transp = @cgi.params["transp"].join(",")
	    else
		p.transp = (@cgi.params["transp3"] + 
			    @cgi.params["transp4"]).join(",")
	    end

	    # Category
	    if @cgi.has_key?("category")
		p.category = @cgi.params["category"].join(",")
	    else
		cat = [ ]
		cat << "!mail"		unless @cgi.has_key?("chkmail")
		cat << "!ripe"		unless @cgi.has_key?("chkripe")
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
		    next unless cgi_ns = @cgi.params["ns#{i}"]
		    next unless cgi_ns.length > 0
		    next if     (ns = cgi_ns[0]).empty?
		    
		    cgi_ips = @cgi.params["ips#{i}"]
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
	    # XXX: todo check!!!
	    p.domain.name = @cgi.params["zone"]

	    # Ok
	    p
	end

	def interact(p, c, tm)
	    # XXX: not good place
	    p.rflag.autoconf
	    p.publisher.autoconf(p.rflag)
	    puts @cgi.header(p.publisher.engine.class::Mime)
	    true
	end

	def usage(errcode, io=$stderr)
	    io.print $mc.get("param_usage").gsub("PROGNAME", PROGNAME)
	    exit errcode unless errcode.nil?
	end

	def error(str, errcode=nil, io=$stderr)
	    exit errcode unless errcode.nil?
	end
    end
end
