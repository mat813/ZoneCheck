# $Id$

require 'diagnostic'


##
## Parameters of the ZoneCheck application
##
class Param
    #
    # configfile
    # ipv4
    # ipv6
    # domainname
    # ns
    # info
    # warning
    # fatal

    attr_reader :configfile, :ipv4, :ipv6, :domainname, :ns
    attr_writer :configfile, :ipv4, :ipv6
    attr_reader :resolver

    attr_reader :info, :warning, :fatal
    attr_reader :stop_on_fatal


    DefaultConfigFile = "zc.conf"

    class ParamError < StandardError
    end



    #
    #
    #
    def initialize
	@dns			= NResolv::DNS::DefaultResolver
	@configfile		= DefaultConfigFile
	@ipv4			= true
	@ipv6			= true
	@stop_on_fatal		= true
	@diag_class		= Diagnostic::Straight
	@warning_methodname	= "warning"
	@fatal_methodname	= "fatal"
	@info_methodname	= "info"
	@intro			= false
	@explanation		= false
	@testing		= false

	@diag			= nil
	@info			= nil
	@warning		= nil
	@fatal			= nil
	@ns			= nil
    end


    def intro?
	@intro
    end

    def explanation?
	@explanation
    end
    
    def testing?
	@testing
    end

    #
    #
    #
    def self.cmdline_parse
	opts = GetoptLong.new(
		[ "--quiet",	"-q",	GetoptLong::NO_ARGUMENT       ],
		[ "--error",	"-e",	GetoptLong::REQUIRED_ARGUMENT ],
		[ "--ipv4",	"-4",	GetoptLong::NO_ARGUMENT       ],
		[ "--ipv6",	"-6",	GetoptLong::NO_ARGUMENT       ],
        	[ "--ns",       "-n",   GetoptLong::REQUIRED_ARGUMENT ],
        	[ "--resolver", "-r",   GetoptLong::REQUIRED_ARGUMENT ],
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
		when "--error"     then i.error         = arg
		when "--ipv6"      then i.ipv4          = false
		when "--ipv4"      then i.ipv6          = false
		when "--config"    then i.configfile    = arg
		when "--ns"        then i.ns            = arg
		when "--resolver"  then i.resolver      = arg
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
usage: #{MYNAME}: [-hqv] [-46] [-f] [-n ns1,ns2,..] [-c configfile] domainname
    -q, --quiet        Quiet mode, doesn't print visual candy.
    -h, --help         Show this message
    -V, --version      Display RCS version
    -e, --error        Behaviour in case of error (allfatal,allwarning,nostop)
    -v, --verbose      Display extra information (intro,explanation)
    -o, --output       Output (straight, consolidation)
    -c, --config       Specify location of the configuration file
    -4, --ipv4         Only check the zone with IPv4 connectivity
    -6, --ipv6         Only check the zone with IPv6 connectivity
    -n, --ns           List of nameservers of the domain

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
		@warning_methodname = @fatal_methodname = "fatal"
	    when "aw", "allwarning"
		@warning_methodname = @fatal_methodname = "warning"
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
	    when "t", "testing"
		@testing     = true
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
		@diag_class = Diagnostic::Straight
	    when "c", "consolidation"
		@diag_class = Diagnostic::Consolidation
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
	@dns = NResolv::DNS::new(NResolv::DNS::Config(resolv))
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
	# Guess Nameservers and ensure primary is at first position
	if ns.nil?
	    begin
		primary = @dns.primary(@domainname)
	    rescue NResolv
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
	    
	    if ns[0].nil?
		raise ParamError, 
		    "Unable to identify primary nameserver (NS vs SOA)"
	    end
	end
	
	# Guess Nameservers IP addressses
	@ns.each { |n|
	    ns, ns_ip = n
	    if ns_ip.empty? then
		begin
		    ns_ip.concat(@dns.addresses(ns, Address::OrderStrict))
		rescue NResolv::NResolvError
		end
	    end
	    if ns_ip.empty? then
		raise ParamError, 
		    "Unable to find nameserver IP address(es) for #{n}"
	    end
	}

	# Set diagnostic object
	@diag    = @diag_class::new
	@info    = @diag.method(@info_methodname).call
	@warning = @diag.method(@warning_methodname).call
	@fatal   = @diag.method(@fatal_methodname).call
    end
end
