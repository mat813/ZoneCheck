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

require 'cgi'

require 'report'
require 'publisher'



##
## Parameters of the ZoneCheck application
##
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
	end

	def parse
	    # CGI interpreter
	    cgi = ::CGI::new
	    
	    # Lang
#	    if cgi["lang"].length == 1
#		lang = cgi["lang"][0]
#		if lang =~ /^\w+$/ # Security
#		    localefile = ZC_LOCALIZATION_FILE % [ lang ]
#		    if File.readable?(localefile)
#			$mc = MessageCatalog::new(localefile)
#		    end
#		end
#	    end

	    # Batch
	    if cgi.has_key?("batchdata")
		@p.batch = BatchData::new(cgi["batchdata"][0])
	    end

	    # Quiet, One
	    @p.rflag.quiet = true if cgi.has_key?("quiet")
	    @p.rflag.one   = true if cgi.has_key?("one")


	    # Verbose
	    if cgi.has_key?("verbose")
		@p.verbose = cgi["verbose"].join(",")
	    else
		@p.verbose = "intro"            if cgi.has_key?("intro")
		@p.verbose = "explain"          if cgi.has_key?("explain")
		@p.verbose = cgi["progress"][0] if cgi.has_key?("progress")
	    end

	    # Output
	    if cgi.has_key?("output")
		@p.output = cgi["output"].join(",")
	    else
		@p.output = cgi["format"].join(",")
	    end

	    # Error
	    if cgi.has_key?("error")
		@p.error = cgi["error"].join(",")
	    else
		errorlvl  = cgi["errorlvl"].delete_if { |e| e =~ /^\s*$/ }
		errorstop = cgi.has_key?("errorstop") ? "stop" : "nostop"
		@p.error = (errorlvl + [ errorstop ]).join(",")
	    end

	    # Transp
	    if cgi.has_key?("transp")
		@p.transp = cgi["transp"].join(",")
	    else
		@p.transp = (cgi["transp3"] + cgi["transp4"]).join(",")
	    end

	    # Category
	    if cgi.has_key?("category")
		@p.category = cgi["category"].join(",")
	    else
		cat = [ ]
		cat << "mail"  if cgi.has_key?("chkmail")
		cat << "whois" if cgi.has_key?("chkwhois")
		cat << "zone"  if cgi.has_key?("chkzone")
		if ! cat.empty?
		    cat << "connectivity" << "dns"
		    @p.category = cat.join(",")
		end
	    end
	    
	    # NS and IPs
	    if cgi.has_key?("ns")
		@p.domain.ns = cgi["ns"].join(";")
	    else
		ns_list = [ ]
		(0..7).each { |i|
		    next unless cgi_ns = cgi["ns#{i}"]
		    next unless cgi_ns.length > 0
		    next if     (ns = cgi_ns[0]).empty?
		    
		    cgi_ips = cgi["ips#{i}"]
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
	    @p.domain.name = cgi["zone"]

	    # XXX: not good place
	    puts cgi.header(@p.publisher_class::Mime)

	    # Ok
	    @p
	end

	def usage
	end
    end



    ##
    ## Processing parameters from CLI (Command Line Interface)
    ##
    class CLI
	def initialize
	    @p    = Param::new
	    @opts = GetoptLong.new(* opts_definition)
	    @opts.quiet = true
	end

	def opts_definition
	    [   [ "--help",	"-h",	GetoptLong::NO_ARGUMENT       ],
		[ "--version",	'-V',	GetoptLong::NO_ARGUMENT       ],
		[ "--quiet",	"-q",	GetoptLong::NO_ARGUMENT       ],
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
		[ "--makecoffee",       GetoptLong::NO_ARGUMENT       ],
		[ "--coffee",           GetoptLong::NO_ARGUMENT       ] ]
        end

	def opts_analyse
	    @opts.each do |opt, arg|
		case opt
		when "--help"      then usage(EXIT_USAGE, $stdout)
		when "--version"
		    puts $mc.get("param_version").gsub("PROGNAME", PROGNAME) % 
			[ $zc_version ]
		    exit EXIT_OK
		when "--debug"     then $dbg.level	 = arg
		when "--batch"     then @p.batch	 = arg
		when "--config"    then @p.configfile    = arg
		when "--testdir"   then @p.testdir       = arg
		when "--category"  then @p.category	 = arg
		when "--test"      then @p.test          = arg
		when "--testlist"  then @p.give_testlist = true
		when "--testdesc"  then @p.give_testdesc = arg
		when "--resolver"  then @p.resolver      = arg
		when "--ns"        then @p.domain.ns     = arg
		when "--ipv6"      then @p.ipv6          = true
		when "--ipv4"      then @p.ipv4          = true
		when "--one"       then @p.rflag.one	 = true
		when "--tagonly"   then @p.rflag.tagonly = true
		when "--quiet"     then @p.rflag.quiet   = true
		when "--error"     then @p.error         = arg
		when "--transp"    then @p.transp        = arg
		when "--verbose"   then @p.verbose	 = arg
		when "--output"    then @p.output        = arg
		when "--makecoffee"
		    print <<EOT
#{PROGNAME}: I'm not currently designed for that task.
\tBut if you really want this option added in future version, 
\tyou should see with the maintainer: \"#{ZC_MAINTAINER}\".
EOT
		    exit EXIT_OK
		when "--coffee"
		    puts "#{PROGNAME}: I'll take one too. thank you."
		    exit EXIT_OK
		end
	    end
	end
	
	def args_analyse
	    if @p.batch
		if !ARGV.empty?
		    raise ParamError, $mc.get("xcp_param_batch_nodomain")
		end
	    else
		if !(ARGV.length == 1)
		    raise ParamError, $mc.get("xcp_param_domain_expected") 
		end
		@p.domain.name = ARGV[0]
	    end
	end

	def parse
	    begin
		opts_analyse
		args_analyse unless @p.give_testlist || @p.give_testdesc
	    rescue GetoptLong::InvalidOption, GetoptLong::MissingArgument
		return nil
	    end
	    @p
	end

	def usage(errcode, io=$stderr)
	    io.print $mc.get("param_usage").gsub("PROGNAME", PROGNAME)
	    exit errcode unless errcode.nil?
	end
    end



    ##
    ## Hold the flags used to describe report output behaviour
    ##
    ## tagonly      : only print tag or information suitable for parsing
    ## one          : only print 1 message
    ## quiet        : don't print extra titles
    ## intro        : display summary about checked domain
    ## explain      : explain the reason behind the test (if test failed)
    ## testdesc     : print a short description of the test being performed
    ## counter      : display a progress bar
    ## stop_on_fatal: stop on the first fatal error
    ##
    ## Correction are silently made to respect the following constaints:
    ##  - 'tagonly' doesn't support 'explain' (as displaying a tag
    ##     for an explanation is meaningless)
    ##  - 'testdesc' and 'counter' are exclusive
    ##  - 'counter' can be ignored if the display doesn't suppport 
    ##     progress bar animation
    ##
    class ReportFlag
	attr_reader :tagonly, :one,     :quiet
	attr_reader :intro,   :explain, :testdesc, :counter
	attr_reader :stop_on_fatal

	attr_writer :one, :quiet, :intro, :stop_on_fatal


	def initialize
	    @tagonly = @one                           	= false
	    @intro   = @explain = @testdesc = @counter	= false
	    @stop_on_fatal				= true
	end

	def tagonly=(val)
	    @explain = false if @tagonly = val
	end

	def explain=(val)
	    @explain = val unless @tagonly
	end

	def testdesc=(val)
	    @counter = false if @testdesc = val
	end
	
	def counter=(val)
	    @testdesc = false if @counter = val
	end
    end


    ##
    ## Hold information about the domain to check 
    ##
    ## name      : a fully qualified domain name
    ## ns        : list of nameservers attached to the domain (name)
    ##              output format : [ [ ns1, [ ip1, ip2 ] ],
    ##                                [ ns2, [ ip3 ] ],
    ##                                [ ns3 ] ]
    ##              input  format : ns1=ip1,ip2;ns2=ip3;ns3
    ##              if element aren't specified they will be 'guessed'
    ##              when calling 'autoconf'
    ## addresses : list of ns addresses
    ##
    class Domain
	def initialize(name=nil, ns=nil)
	    @name	= nil
	    @ns		= nil
	    @addresses	= nil
	    @cache	= true

	    self.name = name unless name.nil?
	    self.ns   = ns   unless ns.nil?
	end

	attr_reader :name, :ns, :addresses, :cache

	def can_cache? ; true ; end

	def name=(domain)
	    domain = NResolv::DNS::Name::create(domain, true)
	    unless domain.absolute?
		raise ArgumentError, $mc.get("xcp_param_fqdn_required")
	    end
	    @name = domain
	end
	
	def ns=(ns)
	    return @ns = nil if ns.nil?

	    @ns = [ ]
	    ns.split(/\s*;\s*/).each { |entry|
		ips  = []
		if entry =~ /^(.*)=(.*)$/
		    host_str, ips_str = $1, $2
		    host = NResolv::DNS::Name::create(host_str, true)
		    ips_str.split(",").each { |str|
			ips << Address::create(str)
		    }
		else
		    host = NResolv::DNS::Name::create(entry, true)
		end
		@ns << [ host, ips ]
	    }
	end

	def autoconf(dns)
	    # Guess Nameservers and ensure primary is at first position
	    if @ns.nil?
		$dbg.msg(DBG::AUTOCONF, "Retrieving NS for #{@name}")
		begin
		    primary = dns.primary(@name)
		rescue NResolv::NResolvError
		    raise ParamError, $mc.get("xcp_param_primary_soa")
		end
		
		begin
		    @ns = [ nil ]
		    dns.nameservers(@name).each { |n|
			if n == primary
			then @ns[0] = [ n, [] ]
			else @ns  <<  [ n, [] ]
			end
		    }
		rescue NResolv::NResolvError
		    raise ParamError, $mc.get("xcp_param_nameservers_ns")
		end
		
		if @ns[0].nil?
		    raise ParamError, $mc.get("xcp_param_prim_ns_soa")
		end
	    end
	
	    # Set cache status
	    if @cache
		$dbg.msg(DBG::AUTOCONF, "Setting cache status")
		@cache &&= can_cache?
	    end
	    
	    # Guess Nameservers IP addresses
	    @ns.each { |ns, ips|
		if ips.empty? then
		    $dbg.msg(DBG::AUTOCONF, "Retrieving IP for NS: #{ns}")
		    begin
			ips.concat(dns.addresses(ns, Address::OrderStrict))
		    rescue NResolv::NResolvError
		    end
		end
		if ips.empty? then
		    raise ParamError, 
			$mc.get("xcp_param_nameserver_ips") % [ ns ]
		end
	    }

	    # Build addresses set
	    @addresses = []
	    @ns.each { |ns, ips| @addresses.concat(ips) }
	end

	def get_resolver_ips(name)
	    if name.nil? || !((name == @name) || (name.in_domain?(@name)))
		nil
	    elsif (name.depth - @name.depth) > 1
		puts name
		raise RuntimeError, "XXX: correct behaviour not decided"
	    else
		@addresses
	    end
	end
    end


    ##
    ##
    ##
    class ProxyReport
	attr_reader :info, :warning, :fatal
	
	def initialize(report_class)
	    @report_class	= report_class
	    @info_attrname	= :info
	    @warning_attrname	= :warning
	    @fatal_attrname	= :fatal
	    @report		= nil
	    @info		= nil
	    @warning		= nil
	    @fatal		= nil
	end

	def allfatal
	    @warning_attrname = @fatal_attrname = :fatal
	end
	
	def allwarning
	    @warning_attrname = @fatal_attrname = :warning
	end

	def reporter=(report_class)
	    @report_class = report_class
	end
	def reporter
	    @report_class
	end

	def autoconf(domain, rflag, publisher)
	    @report	= @report_class::new(domain, rflag, publisher)
	    @info       = @report.method(@info_attrname).call
	    @warning    = @report.method(@warning_attrname).call
	    @fatal      = @report.method(@fatal_attrname).call

	    # Sanity check
	    if rflag.tagonly && !@report.tagonly_supported?
		raise ParamError, 
		    $mc.get("xcp_param_output_support") % [ "tagonly" ]
	    end
	    if rflag.one     && !@report.one_supported?
		raise ParamError, 
		    $mc.get("xcp_param_output_support") % [ "one"     ]
	    end
	end

	def finish
	    @report.finish
	end
    end


    attr_reader :configfile, :ipv4, :ipv6
    attr_writer :configfile, :ipv4

    attr_reader :resolver, :dns



    attr_reader :client

    attr_reader :rflag, :report, :publisher, :publisher_class


    attr_reader :batch
    attr_writer :batch
    
    attr_reader :category

    attr_reader :test
    attr_writer :test

    attr_reader :domain
    attr_writer :domain

    attr_writer :debug

    attr_reader :give_testlist
    attr_writer :give_testlist

    attr_reader :give_testdesc
    
    attr_reader :testdir
    attr_writer :testdir


    ##
    ## Parameter errors (ie: usage)
    ##
    class ParamError < StandardError
    end




    #
    #
    #
    def initialize
	@dns			= NResolv::DNS::DefaultResolver
	@configfile		= ZC_CONFIG_FILE
	@testdir		= ZC_TEST_DIR
	@ipv4			= nil
	@ipv6			= nil

	@testlist		= nil
	@testdesc		= nil

	@client			= NResolv::DNS::Client::Classic


	@publisher_class	= Publisher::Text
	@report			= ProxyReport::new(Report::Straight)
	@domain			= Domain::new
	@rflag			= ReportFlag::new
    end


    #
    #
    #
    def give_testdesc=(string)
	suf = case string
	      when "name"  then "testname"
	      when "expl"  then "explain"
	      when "error" then "error"
	      else raise ParamError, 
		      $mc.gt("xcp_param_unknown_modopt") % [ type, "testdesc" ]
	      end
	
	@give_testdesc = suf
    end


    #
    # WRITER: ipv6
    #
    def ipv6=(bool)
	if bool && ! $ipv6_stack
	    raise ParamError, $mc.get("xcp_param_ipv6_no_stack")
	end
	@ipv6 = bool
    end

    #
    # WRITER: category
    #
    def category=(string)
	return if string =~ /^\s*$/
	@category = [] if @category.nil?
	@category.concat(string.split(/\s*,\s*/))
    end

    
    #
    # WRITER: error
    #
    def error=(string)
	return if string =~ /^\s*$/
	string.split(/\s*,\s*/).each { |token|
	    case token
	    when "af", "allfatal"
		@report.allfatal
	    when "aw", "allwarning"
		@report.allwarning
	    when "s",  "stop"
		@rflag.stop_on_fatal = true
	    when "ns", "nostop"
		@rflag.stop_on_fatal = false
	    else
		raise ParamError,
		    $mc.gt("xcp_param_unknown_modopt") % [ token, "error" ]
	    end
	}
    end

    #
    # WRITER: verbose
    #
    def verbose=(string)
	return if string =~ /^\s*$/
	string.split(/\s*,\s*/).each { |token|
	    case token
	    when "x", "explain"
		@rflag.explain	= true
	    when "i", "intro"
		@rflag.intro	= true
	    when "t", "testdesc"
		@rflag.testdesc	= true
	    when "c", "counter"
		@rflag.counter	= true
	    else
		raise ParamError,
		    $mc.gt("xcp_param_unknown_modopt") % [ token, "verbose" ]
	    end
	}
    end

    #
    # WRITER: verbose
    #
    def transp=(string)
	return if string =~ /^\s*$/
	string.split(/\s*,\s*/).each { |token|
	    case token
	    when "4", "ipv4"
		ipv4 = true
	    when "6", "ipv6"
		ipv6 = true
	    when "u", "udp"
		@client = NResolv::DNS::Client::UDP
	    when "t", "tcp"
		@client = NResolv::DNS::Client::TCP
	    when "s", "std"
		@client = NResolv::DNS::Client::Classic
	    else
		raise ParamError,
		    $mc.gt("xcp_param_unknown_modopt") % [ token, "transp" ]
	    end
	}
    end

    #
    # WRITER: output
    #
    def output=(string)
	return if string =~ /^\s*$/
	string.split(/\s*,\s*/).each { |token|
	    case token
	    when "s", "straight"
		@report.reporter = Report::Straight
	    when "c", "consolidation"
		@report.reporter = Report::Consolidation
	    when "t", "text"
		@publisher_class = Publisher::Text
	    when "h", "html"
		@publisher_class = Publisher::HTML
	    else
		raise ParamError,
		    $mc.gt("xcp_param_unknown_modopt") % [ token, "output" ]
	    end
	}
    end

    #
    #
    #
    def resolver=(resolv)
	dns_config = NResolv::DNS::Config::new(resolv)
	@resolver  = resolv
	@dns       = NResolv::DNS::Client::Classic::new(dns_config)
    end


    #
    #
    #
    def address_wanted?(address)
	case address
	when String
	    case address
	    when Address::IPv4::Regex then address if ipv4
	    when Address::IPv6::Regex then address if ipv6
	    else nil
	    end
	when Address::IPv4 then address if ipv4
	when Address::IPv6 then address if ipv6
	when Array
	    address.collect { |addr| address_wanted?(addr) }.compact
	else nil
	end
    end



    #
    # Try to fill the blank for the ouput parameters
    #
    def output_autoconf
	# Set output publisher
	@publisher = @publisher_class::new(@rflag)
	$dbg.msg(DBG::AUTOCONF, "Publish using #{@publisher_class}")
    end

    #
    # Try to fill the blank for the unspecified parameters
    #
    # WARN: parameters that are used before the call to 'zc'
    #       should not be part of autoconf
    #
    def autoconf
	# Autoconf of domain information
	@domain.autoconf(@dns)

	# Select routing protocol
	@ipv4 = @ipv6 = true if @ipv4.nil? && @ipv6.nil?
	@ipv4 = false        if @ipv4.nil?
	@ipv6 = false        if @ipv6.nil? || !$ipv6_stack
	$dbg.msg(DBG::AUTOCONF, 
		 "Routing protocol set to: " +
		   [ @ipv4 ? "ipv4" : nil, 
		     @ipv6 ? "ipv6" : nil].compact.join("/"))

	# Set report object
	@report.autoconf(@domain, @rflag, @publisher)
	$dbg.msg(DBG::AUTOCONF, "Report using #{@report.reporter}")
    end
end
