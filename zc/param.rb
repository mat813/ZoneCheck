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

require 'report'
require 'publisher'

##
## Parameters of the ZoneCheck application
##
class Param
    ##
    ##
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
		[ "--dnsonly",  "-D",   GetoptLong::NO_ARGUMENT       ],
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
		    puts "#{PROGNAME}: version #{$zc_version}"
		    exit EXIT_OK
		when "--debug"     then $dbg.level	 = arg
		when "--batch"     then @p.batch	 = arg
		when "--config"    then @p.configfile    = arg
		when "--testdir"   then @p.testdir       = arg
		when "--dnsonly"   then @p.dnsonly	 = true
		when "--test"      then @p.test          = arg
		when "--testlist"  then @p
		when "--testdesc"  then @p
		when "--resolver"  then @p.resolver      = arg
		when "--ns"        then @p.domain.ns     = arg
		when "--ipv6"      then @p.ipv6          = true
		when "--ipv4"      then @p.ipv4          = true
		when "--one"       then @p.rflag.one	 = true
		when "--tagonly"   then @p.rflag.tagonly = true
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
		    raise ParamError, 
			"no domainname expected for batch mode"
		end
	    else
		raise ParamError, 
		    "one domainname expected" unless ARGV.length == 1
		@p.domain.name = ARGV[0]
	    end
	end

	def parse
	    begin
		opts_analyse
		args_analyse
	    rescue GetoptLong::InvalidOption, GetoptLong::MissingArgument
		return nil
	    end
	    @p
	end

	def usage(errcode, io=$stderr)
	    io.print <<EOT
usage: #{PROGNAME}: [-hqV] [-etvo opt] [-46] [-n ns,..] [-c conf] domainname
    -q, --quiet         Quiet mode, doesn't print visual candy.
    -h, --help          Show this message
    -V, --version       Display version and exit
    -B, --batch         Batch mode (read from file or stdin '-')
    -c, --config        Specify location of the configuration file
        --testdir       Location of the directory holding tests
    -D, --dnsonly       Only perform DNS related tests
    -T, --test          Name of the test to perform
        --testlist      List all the available tests
        --testdesc      Give a description of the test
    -r, --resolver      Resolver to use for guessing 'ns' information
    -n, --ns            List of nameservers for the domain
    -1, --one           Only primite the most relevant message
    -g, --tagonly       Display only tag (suitable for scripting)
    -e, --error         Behaviour in case of error (see error)
    -t, --transp        Transport/routing layer (see transp)
    -v, --verbose       Display extra information (see verbose)
    -o, --output        Output (see output)
    -4, --ipv4          Only check the zone with IPv4 connectivity
    -6, --ipv6          Only check the zone with IPv6 connectivity

  verbose:              [intro/explanation] [testdesc|counter]
    intro          [i]  Print summary for domain and associated nameservers
    explanation    [x]  Print an explanation for failed tests
    testdesc       [t]  Print the test description before running it
    counter        [c]  Print a test counter

  output:               [straigh|consolidation] [text|html]
    straight      *[s]  Print output without processing (or very few)
    consolidation  [c]  Try to merge some results before output
    text          *[t]  Output plain text
    html           [h]  Output HTML

  error:                [allfatal|allwarning] [stop|nostop]
    allfatal       [af] All error are considered fatal
    allwarning     [aw] All error are considered warning
    stop          *[s]  Stop on the first fatal error
    nostop         [ns] Never stop (even on fatal error)

  transp:               [ipv4/ipv6] [udp|tcp|std]
    ipv4          *[4]  Use IPv4 routing protocol
    ipv6          *[6]  Use IPv6 routing protocol
    udp            [u]  Use UDP transport layer
    tcp            [t]  Use TCP transport layer
    std           *[s]  Use UDP with fallback to TCP for truncated messages

  Batch Mode: 
    - process domain from stdin, with 1 per line. The syntax is:
      DOM=domainname
   or DOM=domainname NS=ns1;ns2=ip1,ip2
    

EXAMPLES:
  #{PROGNAME} -6 --verbose=x,i afnic.fr.
    Test the 'afnic.fr.' domain with IPv6 only connectivity, print
    a summary information about the tested domain and explanation of
    failed tests

  #{PROGNAME} -v c -1 -B -
    Work in batch mode, where domain are read from stdin, a progress bar
    indicates how many tests remains, and only short report is written

  #{PROGNAME} -T error chk_soa
    Ask for the 'error' message associated with the test 'chk_soa'
EOT
       exit errcode unless errcode.nil? #'
	end
    end



    ##
    ## Hold the flags used to describe report output behaviour
    ##
    ## tagonly      : only print tag or information suitable for parsing
    ## one          : only print 1 message
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
    ##
    class ReportFlag
	attr_reader :tagonly, :one
	attr_reader :intro,   :explain, :testdesc, :counter
	attr_reader :stop_on_fatal

	attr_writer :one, :intro, :stop_on_fatal

	def initialize
	    @tagonly = @one                           	= false
	    @intro   = @explain = @testdesc = @counter	= false
	    @stop_on_fatal				= true
	end

	def tagonly=(val)
	    if @tagonly = val
		@explain = false
	    end
	end

	def explain=(val)
	    @explain = val unless @tagonly
	end

	def testdesc=(val)
	    if @testdesc = val
		@counter = false
	    end
	end
	
	def counter=(val)
	    if @counter = val
		@testdesc = false
	    end
	end
    end


    ##
    ## Hold information about the domain to check 
    ##
    ## name : a fully qualified domain name
    ## ns   : list of nameservers attached to the domain (name)
    ##        output format : [ [ ns1, [ ip1, ip2 ] ],
    ##                          [ ns2, [ ip3 ] ],
    ##                          [ ns3 ] ]
    ##        input  format : ns1=ip1,ip2;ns2=ip3;ns3
    ##        if element aren't specified they will be 'guessed' when
    ##        calling 'autoconf'
    ##
    class Domain
	def initialize(name=nil, ns=nil)
	    @name	= nil
	    @ns		= nil
	    @cache	= true

	    self.name = name unless name.nil?
	    self.ns   = ns   unless ns.nil?
	end

	attr_reader :name, :ns, :cache

	def can_cache? ; true ; end

	def name=(domain)
	    domain = NResolv::DNS::Name::create(domain, true)
	    unless domain.absolute?
		raise ArgumentError, "Absolute domain name required" 
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
		$dbg.msg(DBG::AUTOCONF, "Retrieving #{@name} NS")
		begin
		    primary = dns.primary(@name)
		rescue NResolv::NResolvError
		    raise ParamError, "Unable to find primary nameserver (SOA)"
		end
		
		begin
		    @ns = [ nil ]
		    dns.nameservers(@name).each { |n|
			if n == primary
			    @ns[0] = [ n, [] ]
			else
			    @ns  <<  [ n, [] ]
			end
		    }
		rescue NResolv::NResolvError
		    raise ParamError, "Unable to find nameservers (NS)"
		end
		
		if @ns[0].nil?
		    raise ParamError, 
			"Unable to identify primary nameserver (NS vs SOA)"
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
		    $dbg.msg(DBG::AUTOCONF, "Retrieving IP for NS:#{ns}")
		    begin
			ips.concat(dns.addresses(ns, Address::OrderStrict))
		    rescue NResolv::NResolvError
		    end
		end
		if ips.empty? then
		    raise ParamError, 
			"Unable to find nameserver IP address(es) for #{ns}"
		end
	    }
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

	def autoconf(domain, rflag, publisher)
	    @report	= @report_class::new(domain, rflag, publisher)
	    @info       = @report.method(@info_attrname).call
	    @warning    = @report.method(@warning_attrname).call
	    @fatal      = @report.method(@fatal_attrname).call

	    # Sanity check
	    if rflag.tagonly && !@report.tagonly_supported?
		raise ParamError, 
		    "selected output class doesn't support 'tagonly'"
	    end
	    if rflag.one     && !@report.one_supported?
		raise ParamError, 
		    "selected output class doesn't support 'one'"
	    end
	end

	def finish
	    @report.finish
	end
    end


    attr_reader :configfile, :ipv4, :ipv6
    attr_writer :configfile, :ipv4, :ipv6

    attr_reader :resolver, :dns



    attr_reader :client

    attr_reader :rflag, :report, :publisher


    attr_reader :batch
    attr_writer :batch
    
    attr_reader :dnsonly
    attr_writer :dnsonly

    attr_reader :test
    attr_writer :test

    attr_reader :domain
    attr_writer :domain

    attr_writer :debug

    attr_reader :testdir
    attr_writer :testdir


    DefaultConfigFile = "zc.conf"
    DefaultTestDir    = "./test"

    class ParamError < StandardError
    end




    #
    #
    #
    def initialize
	@dns			= NResolv::DNS::DefaultResolver
	@configfile		= DefaultConfigFile
	@testdir		= DefaultTestDir
	@ipv4			= nil
	@ipv6			= nil

	@client			= NResolv::DNS::Client::Classic


	@publisher_class	= Publisher::Text
	@report			= ProxyReport::new(Report::Straight)
	@domain			= Domain::new
	@rflag			= ReportFlag::new
    end

    #
    #
    #



    #
    # WRITER: error
    #
    def error=(string)
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
		raise ParamError, "unknown error modifier '#{token}'"
	    end
	}
    end

    #
    # WRITER: verbose
    #
    def verbose=(string)
	string.split(/\s*,\s*/).each { |token|
	    case token
	    when "x", "explanation"
		@rflag.explain	= true
	    when "i", "intro"
		@rflag.intro	= true
	    when "t", "testdesc"
		@rflag.testdesc	= true
	    when "c", "counter"
		@rflag.counter	= true
	    else
		raise ParamError, "unknown verbose modifier '#{token}'"
	    end
	}
    end

    #
    # WRITER: verbose
    #
    def transp=(string)
	string.split(/\s*,\s*/).each { |token|
	    case token
	    when "4", "ipv4"
		@ipv4 = true
	    when "6", "ipv6"
		@ipv6 = true
	    when "u", "udp"
		@client = NResolv::DNS::Client::UDP
	    when "t", "tcp"
		@client = NResolv::DNS::Client::TCP
	    when "s", "std"
		@client = NResolv::DNS::Client::Classic
	    else
		raise ParamError, "unknown verbose modifier '#{token}'"
	    end
	}
    end

    #
    # WRITER: output
    #
    def output=(string)
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
		raise ParamError, "unknown output modifier '#{token}'"
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
	@ipv6 = false        if @ipv6.nil?

	# Set output publisher
	@publisher = @publisher_class::new(@rflag)

	# Set report object
	@report.autoconf(@domain, @rflag, @publisher)
    end
end
