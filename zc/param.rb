# $Id$

require 'diagnostic'

class Param
    attr_reader :configfile, :ipv4, :ipv6, :domainname, :ns
    attr_writer :configfile, :ipv4, :ipv6

    attr_reader :info, :warning, :fatal
    attr_reader :all_fatal


    DefaultConfigFile = "zc.conf"

    class ParamError < StandardError
    end


    def initialize(dns=NResolv::DNS::DefaultDNS, configfile=DefaultConfigFile)
	@dns        = dns
	@configfile = configfile
	@ipv4       = true
	@ipv6       = true
	@all_fatal  = false
	@info       = Diagnostic::Info::new
	@warning    = Diagnostic::Warning::new
	@fatal      = Diagnostic::Fatal::new
	@ns	    = nil
    end

    # WRITER: domainanme
    #  ensure that the domain name is absolutely qualified
    def domainname=(domainname)
	@domainname = domainname.make_absolute
    end

    # WRITER: ns
    #  parse the 'ns' argument and ensure that the server name are 
    #  absolutely qualified
    def ns=(ns)
	@ns = [ ]
	ns.split(/\s*;\s*/).each { |entry|
	    ips  = []
	    if entry =~ /^(.*)=(.*)$/
		host_str, ips_str = $1, $2
		host = NResolv::DNS::Name::create(host_str).make_absolute
		ips_str.split(",").each { |str|
		    ips << Address::create(str)
		}
	    else
		host = NResolv::DNS::Name::create(entry).make_absolute
	    end
	    @ns << [ host, ips ]
	}
    end

    def all_fatal=(action)
	@warning.fatal = @all_fatal = action
    end


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

    # Try to fill the blank for the unspecified parameters
    def autoconf
	# Guess Nameservers
	begin
	    if ns.nil?
		@ns = [ ]
		@dns.each_resource(@domainname, 
				   NResolv::DNS::Resource::IN::NS) { |r|
			@ns << [ r.name, [] ]
		}
	    end
	rescue NResolv::ResolvError
	    raise ParamError, "Unable to find nameservers"
	end
	
	# Guess Nameservers IP addressses
	@ns.each { |n|
	    ns, ns_ip = n
	    if ns_ip.length == 0 then
		begin
		    ns_ip.concat(@dns.getaddresses(ns, Address::OrderStrict))
		rescue NResolv::ResolvError
		end
	    end
	    if ns_ip.length == 0 then
		raise ParamError, "Unable to find nameserver IP address(es)"
	    end
	}
    end
end
