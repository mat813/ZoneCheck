# $Id$

# 
# AUTHOR : Stephane D'Alu <sdalu@nic.fr>
# CREATED: 2002/08/02 13:58:17
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS:
#
#

#
# WARN: this file is LOADED by param
#

require 'cgi'

class Param
    ##
    ## Processing parameters from CGI (Common Gateway Interface)
    ##
    ## For obvious security reason the following parameters shouldn't
    ## be set through the CGI:
    ##  - configfile
    ##  - testdir
    ##  - debug
    ##  - resolver
    ##
    class CGI
	class BatchData
	    def initialize(data)
		@data = data.split(/\n/)
	    end

	    def each_line(&block)
		@data.each &block
	    end

	    def close
		@data = nil
	    end
	end


	def initialize
	    @p    = Param::new
	    @cgi  = ::CGI::new
	end

	def parse
	    # Lang
	    # => The message catalogue need to be replaced
	    if @cgi["lang"].length == 1
		begin
		    lang = @cgi["lang"][0]
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
		@p.batch = BatchData::new(@cgi["batchdata"][0])
	    end

	    # Quiet, One
	    @p.rflag.quiet = true if @cgi.has_key?("quiet")
	    @p.rflag.one   = true if @cgi.has_key?("one")


	    # Verbose
	    if @cgi.has_key?("verbose")
		@p.verbose = @cgi["verbose"].join(",")
	    else
		@p.verbose = "intro"             if @cgi.has_key?("intro")
		@p.verbose = "explain"           if @cgi.has_key?("explain")
		@p.verbose = @cgi["progress"][0] if @cgi.has_key?("progress")
	    end

	    # Output
	    if @cgi.has_key?("output")
		@p.output = @cgi["output"].join(",")
	    else
		@p.output = @cgi["format"].join(",")
	    end

	    # Error
	    if @cgi.has_key?("error")
		@p.error  = @cgi["error"].join(",")
	    else
		errorlvl  = @cgi["errorlvl"].delete_if { |e| e =~ /^\s*$/ }
		errorstop = @cgi.has_key?("errorstop") ? "stop" : "nostop"
		@p.error  = (errorlvl + [ errorstop ]).join(",")
	    end

	    # Transp
	    if @cgi.has_key?("transp")
		@p.transp = @cgi["transp"].join(",")
	    else
		@p.transp = (@cgi["transp3"] + @cgi["transp4"]).join(",")
	    end

	    # Category
	    if @cgi.has_key?("category")
		@p.category = @cgi["category"].join(",")
	    else
		cat = [ ]
		cat << "mail"  if @cgi.has_key?("chkmail")
		cat << "whois" if @cgi.has_key?("chkwhois")
		cat << "zone"  if @cgi.has_key?("chkzone")
		if ! cat.empty?
		    cat << "connectivity" << "dns"	# XXX: VERY BAD
		    @p.test.categories = cat.join(",")
		end
	    end
	    
	    # NS and IPs
	    if @cgi.has_key?("ns")
		@p.domain.ns = @cgi["ns"].join(";")
	    else
		ns_list = [ ]
		(0..7).each { |i|
		    next unless cgi_ns = @cgi["ns#{i}"]
		    next unless cgi_ns.length > 0
		    next if     (ns = cgi_ns[0]).empty?
		    
		    cgi_ips = @cgi["ips#{i}"]
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
		    @p.domain.ns   = ns_list.collect { |ns, ips|
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
	    @p.domain.name = @cgi["zone"]

	    # Ok
	    @p
	end

	def interact(config)
	    # XXX: not good place
	    @p.rflag.autoconf
	    @p.publisher.autoconf(@p.rflag)
	    puts @cgi.header(@p.publisher.engine.class::Mime)
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
