# $Id$

require 'diagnostic'
require 'formatter'

##
## Parameters of the ZoneCheck application
##
class Param
    attr_reader :configfile, :ipv4, :ipv6, :domainname, :ns
    attr_writer :configfile, :ipv4, :ipv6
    attr_reader :resolver

    attr_reader :diagnostic
    attr_reader :info, :warning, :fatal
    attr_reader :stop_on_fatal

    attr_reader :intro, :explanation, :testdesc, :counter
    attr_reader :client
    attr_reader :formatter

    attr_reader :cache
    attr_reader :primary

    DefaultConfigFile = "zc.conf"

    class ParamError < StandardError
    end



    #
    #
    #
    def initialize
	@dns			= NResolv::DNS::DefaultResolver
	@configfile		= DefaultConfigFile
	@ipv4			= nil
	@ipv6			= nil
	@client			= nil

	@stop_on_fatal		= true
	@diagnostic_class	= Diagnostic::Straight
	@formatter_class	= Formatter::Text
	@warning_methodname	= :warning
	@fatal_methodname	= :fatal
	@info_methodname	= :info
	@intro			= false
	@explanation		= false
	@testdesc		= false

	@diagnostic		= nil
	@info			= nil
	@warning		= nil
	@fatal			= nil
	@ns			= nil

	@cache			= true
    end

    #
    #
    #
    def self.cmdline_parse
	opts = GetoptLong.new(
		[ "--quiet",	"-q",	GetoptLong::NO_ARGUMENT       ],
		[ "--ipv4",	"-4",	GetoptLong::NO_ARGUMENT       ],
		[ "--ipv6",	"-6",	GetoptLong::NO_ARGUMENT       ],
        	[ "--ns",       "-n",   GetoptLong::REQUIRED_ARGUMENT ],
        	[ "--resolver", "-r",   GetoptLong::REQUIRED_ARGUMENT ],
		[ "--error",	"-e",	GetoptLong::REQUIRED_ARGUMENT ],
		[ "--transp",	"-t",	GetoptLong::REQUIRED_ARGUMENT ],
		[ "--verbose",  "-v",   GetoptLong::OPTIONAL_ARGUMENT ],
		[ "--output",   "-o",   GetoptLong::REQUIRED_ARGUMENT ],
        	[ "--version",	'-V',	GetoptLong::NO_ARGUMENT       ],
        	[ "--config",   "-c",   GetoptLong::REQUIRED_ARGUMENT ],
		[ "--help",	"-h",	GetoptLong::NO_ARGUMENT       ] )
	opts.quiet = true

	i = self.new

	begin
	    opts.each do |opt, arg|
		case opt
		when "--version"
		    puts "#{MYNAME}: RCS version #{RCS_REVISION}"
		    exit EXIT_OK
		when "--ipv6"      then i.ipv6          = true
		when "--ipv4"      then i.ipv4          = true
		when "--config"    then i.configfile    = arg
		when "--ns"        then i.ns            = arg
		when "--resolver"  then i.resolver      = arg
		when "--error"     then i.error         = arg
		when "--transp"    then i.transp        = arg
		when "--verbose"   then i.verbose	= arg
		when "--output"    then i.output        = arg
		when "--help"      then cmdline_usage(EXIT_USAGE, $stdout)
		end
	    end
	    raise "domainname expected" unless ARGV.length == 1
	    i.domainname = NResolv::DNS::Name::create(ARGV[0], true)

	rescue GetoptLong::InvalidOption
	    return nil
	end
	i
    end



    # 
    #
    #
    def self.cmdline_usage(errcode, io=$stderr)
	io.print <<EOT
usage: #{MYNAME}: [-hqV] [-etvo opt] [-46] [-n ns,..] [-c conf] domainname
    -q, --quiet         Quiet mode, doesn't print visual candy.
    -h, --help          Show this message
    -V, --version       Display RCS version and exit
    -e, --error         Behaviour in case of error (see error)
    -t, --transp        Transport/routing layer (see transp)
    -v, --verbose       Display extra information (see verbose)
    -o, --output        Output (see output)
    -c, --config        Specify location of the configuration file
    -4, --ipv4          Only check the zone with IPv4 connectivity
    -6, --ipv6          Only check the zone with IPv6 connectivity
    -n, --ns            List of nameservers for the domain

  verbose:              [intro/explanation] [testdesc|counter]
    intro          [i]  Print summary for domain and associated nameservers
    explanation    [x]  Print an explanation for failed tests
    testdesc       [t]  Print the test description before running it
    counter        [c]  Print a test counter

  output:               [straigh|consolidation] [text|html]
    straight      *[s]  Print output without processing
    consolidation  [c]  Try to merge some results before output
    text          *[t]  Output plain text
    html           [h]  Output HTML

  error:                [allfatal|allwarning] [stop|nostop]
    allfatal       [af] All error are considered fatal
    allwarning     [aw] All error are considered warning
    stop          *[s]  Stop on the first fatal error
    nostop         [ns] Never stop (even on fatal error)

  transp:               [ipv4/ipv6] [udp|tcp|std]
    ipv4          *[4]  Use IPv4 routing protocol (same as -4)
    ipv6          *[6]  Use IPv6 routing protocol (same as -6)
    udp            [u]  Use UDP transport layer
    tcp            [t]  Use TCP transport layer
    std           *[s]  Use UDP with fallback to TCP from truncated messages

EXAMPLES:
  #{MYNAME} -4 --verbose=x,i afnic.fr.
EOT
       exit errcode unless errcode.nil? #'
    end



    #
    # WRITER: domainanme
    #  ensure that the domain name is absolutely qualified
    #
    def domainname=(domainname)
	unless domainname.absolute?
	    raise ArgumentError, "Absolute domain name required" 
	end
	@domainname = domainname
    end



    #
    # WRITER: ns
    #  parse the 'ns' argument and ensure that the server name are 
    #  absolutely qualified
    #
    def ns=(ns)
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


    #
    # WRITER: error
    #
    def error=(string)
	string.split(/\s*,\s*/).each { |token|
	    case token
	    when "af", "allfatal"
		@warning_methodname = @fatal_methodname = :fatal
	    when "aw", "allwarning"
		@warning_methodname = @fatal_methodname = :warning
	    when "s",  "stop"
		@stop_on_fatal = true
	    when "ns", "nostop"
		@stop_on_fatal = false
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
		@explanation = true
	    when "i", "intro"
		@intro       = true
	    when "t", "testdesc"
		@testdesc     = true
		@counter      = false
	    when "c", "counter"
		@counter      = true
		@testdesc     = false
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
		@diagnostic_class = Diagnostic::Straight
	    when "c", "consolidation"
		@diagnostic_class = Diagnostic::Consolidation
	    when "t", "text"
		@formatter_class  = Formatter::Text
	    when "h", "html"
		@formatter_class  = Formatter::HTML
	    else
		raise ParamError, "unknown output modifier '#{token}'"
	    end
	}
    end

    #
    #
    #
    def resolver=(resolv)
	@resolver = resolv
	@dns = NResolv::DNS::Client::Classic::new(NResolv::DNS::Config::new(resolv))
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
    def autoconf
	# Select routing protocol
	@ipv4 = @ipv6 = true if @ipv4.nil? && @ipv6.nil?
	@ipv4 = false        if @ipv4.nil?
	@ipv6 = false        if @ipv6.nil?

	# Select transport layer
	@client = NResolv::DNS::Client::Classic if @client.nil?

	# Guess Nameservers and ensure primary is at first position
	if @ns.nil?
	    begin
		primary = @dns.primary(@domainname)
	    rescue NResolv::NResolvError
		raise ParamError, "Unable to find primary nameserver (SOA)"
	    end

	    begin
		@ns = [ nil ]
		@dns.nameservers(@domainname).each { |n|
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
	    domain_exists = begin
				@dns.primary(@domainname)
				true
			    rescue NResolv::NoDomainError
				false
			    end
	    @ns.each { |ns, ips|
		@cache &&= ips.empty? || (!domain_exists && 
					  ns.in_domain?(@domainname))
	    }
	end

	# Guess Nameservers IP addresses
	@ns.each { |ns, ips|
	    if ips.empty? then
		begin
		    ips.concat(@dns.addresses(ns, Address::OrderStrict))
		rescue NResolv::NResolvError
		end
	    end
	    if ips.empty? then
		raise ParamError, 
		    "Unable to find nameserver IP address(es) for #{n}"
	    end
	}

	# Set output formatter
	@formatter  = @formatter_class::new

	# Set diagnostic object
	@diagnostic = @diagnostic_class::new(@formatter)
	@info       = @diagnostic.method(@info_methodname).call
	@warning    = @diagnostic.method(@warning_methodname).call
	@fatal      = @diagnostic.method(@fatal_methodname).call
    end
end
