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
    ## Corrections are silently made to respect the following constaints:
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
	    @explain  = false if @tagonly = val
	end

	def explain=(val)
	    @explain  = val   if !@tagonly
	end

	def testdesc=(val)
	    @counter  = false if @testdesc = val
	end
	
	def counter=(val)
	    @testdesc = false if @counter = val
	end

	def autoconf
	    flags = []
	    flags << "tagonly"  if @tagonly
	    flags << "one"      if @one
	    flags << "quiet"    if @quiet
	    flags << "intro"    if @intro
	    flags << "explain"  if @explain
	    flags << "testdesc" if @testdesc
	    flags << "counter"  if @counter
	    flags << "stop"     if @stop_on_fatal
	    $dbg.msg(DBG::AUTOCONF, "Report flags: " + flags.join("/"))
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
	    clear
	    self.name = name unless name.nil?
	    self.ns   = ns   unless ns.nil?
	end

	attr_reader :name, :ns, :addresses, :cache

	def clear
	    @name	= nil
	    @ns		= nil
	    @addresses	= nil
	    @cache	= true
	end

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
    ## As the Report class, but allow severity override
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

	def finish
	    @report.finish
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

	    $dbg.msg(DBG::AUTOCONF, "Report using #{reporter}")
	end
    end



    ##
    ## Hold information about file system
    ##
    ## cfgfile: configuration file to use (zc.conf)
    ## testdir: directory where tests are located
    ##
    class FSData
	attr_reader :cfgfile, :testdir
	attr_writer :cfgfile, :testdir
	
	def initialize
	    @cfgfile	= ZC_CONFIG_FILE
	    @testdir	= ZC_TEST_DIR
	end

	def autoconf
	    $dbg.msg(DBG::AUTOCONF, "configuration file: #{@cfgfile}")
	    $dbg.msg(DBG::AUTOCONF, "tests directory: #{@testdir}")
	end
    end



    ##
    ## Hold information about the resolver behaviour
    ## 
    ## ipv4    : use IPv4 routing protocol
    ## ipv6    : use IPv6 routing protocol
    ## mode    : use the following mode for new resolvers: Classic / UDP / TCP 
    ##
    class Network
	attr_reader :ipv4, :ipv6, :query_mode
	attr_writer :ipv4, :query_mode

	def initialize
	    @ipv6		= nil
	    @ipv4		= nil
	    @query_mode		= nil
	end

	def ipv6=(bool)
	    if bool && ! $ipv6_stack
		raise ParamError, $mc.get("xcp_param_ipv6_no_stack")
	    end
	    @ipv6 = bool
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

	def autoconf
	    # Select routing protocol
	    @ipv4 = @ipv6 = true if @ipv4.nil? && @ipv6.nil?
	    @ipv4 = false        if @ipv4.nil?
	    @ipv6 = false        if @ipv6.nil? || !$ipv6_stack
	    $dbg.msg(DBG::AUTOCONF, 
		     "Routing protocol set to: " +
		     [ @ipv4 ? "IPv4" : nil, 
		       @ipv6 ? "IPv6" : nil].compact.join("/"))

	    # Select mode
	    @query_mode = NResolv::DNS::Client::Classic if @query_mode.nil?
	    @query_mode.to_s =~ /([^:]+)$/
	    $dbg.msg(DBG::AUTOCONF, "Query mode set to: #{$1}")
	end
    end



    ##
    ## Hold information about local resolver
    ##
    ## resolver: local resolver to use
    ##
    ## WARN: the 'resolver' doesn't follow the Network constraints
    ##       as it is local and should be able to correctly operate in its
    ##       own environment
    ##
    class Resolver
	attr_reader :local

	def initialize
	    @local	= nil
	    @local_name	= nil
	end

	def local=(resolv)
	    case resolv
	    when String
		@local_name = resolv
	    else
		raise ArgumentError, "Wrong type for resolver object"
	    end
	end

	def autoconf
	    # Select local resolver
	    if @local.nil?
		@local = if @local_name.nil?
				NResolv::DNS::DefaultResolver
			    else 
				cfg = NResolv::DNS::Config::new(@local_name)
				NResolv::DNS::Client::Classic::new(cfg)
			    end
	    end

	    $dbg.msg(DBG::AUTOCONF, "Resolver " + 
		     (@local_name.nil? ? "<default>" : @local_name))
	end
    end


    ##
    ## Hold information about the test
    ## 
    ## list      : limiting tests to this list
    ## catagories: limiting tests to these categories
    ## desctype  : description type (name, xpl, error, ...)
    ##
    class Test
	attr_reader :list, :tests, :categories, :desctype
	attr_writer :list

	def initialize
	    @list	= false
	    @tests	= nil
	    @categories	= nil
	    @desctype   = nil
	end

	def desctype=(string)
	    suf = case string
		  when "name"  then "testname"
		  when "expl"  then "explain"
		  when "error" then "error"
		  else raise ParamError, 
			  $mc.get("xcp_param_unknown_modopt") % [ string, "testdesc" ]
		  end
	    
	    @desctype = suf
	end

	
	def tests=(string)
	    return if string =~ /^\s*$/
	    @tests = string.split(/\s*,\s*/)
	end

	def categories=(string)
	    return if string =~ /^\s*$/
	    @categories = string.split(/\s*,\s*/)
	end

	def autoconf
	end
    end


    ##
    ## Exception: Parameter errors (ie: usage)
    ##
    class ParamError < StandardError
    end



    attr_reader :rflag, :report, :test, :network, :fs, :resolver, :publisher

    attr_reader :batch
    attr_writer :batch
    
    attr_reader :domain
    attr_writer :domain

    attr_writer :debug



    ##
    ##
    ##
    class Publisher
	def initialize
	    @publisher_class	= ::Publisher::Text
	    @publisher		= nil
	end
	
	def engine=(klass)
	    @publisher_class = klass
	end
	def engine
	    @publisher
	end

	def autoconf(rflag)
	    # Set output publisher
	    @publisher = @publisher_class::new(rflag)

	    $dbg.msg(DBG::AUTOCONF, "Publish using #{@publisher_class}")
	end
    end




    #
    #
    #
    def initialize
	@publisher		= Publisher::new
	@fs			= FSData::new
	@network		= Network::new
	@resolver		= Resolver::new
	@test			= Test::new
	@report			= ProxyReport::new(Report::Straight)
	@domain			= Domain::new
	@rflag			= ReportFlag::new
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
		    $mc.get("xcp_param_unknown_modopt") % [ token, "error" ]
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
		    $mc.get("xcp_param_unknown_modopt") % [ token, "verbose" ]
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
		@report.reporter  = Report::Straight
	    when "c", "consolidation"
		@report.reporter  = Report::Consolidation
	    when "t", "text"
		@publisher.engine = ::Publisher::Text
	    when "h", "html"
		@publisher.engine = ::Publisher::HTML
	    when "g", "gtk"
		@publisher.engine = ::Publisher::GTK
	    else
		raise ParamError,
		    $mc.get("xcp_param_unknown_modopt") % [ token, "output" ]
	    end
	}
    end

    #
    # WRITER: transp
    #
    def transp=(string)
	return if string =~ /^\s*$/
	string.split(/\s*,\s*/).each { |token|
	    case token
	    when "4", "ipv4"
		@network.ipv4 = true
	    when "6", "ipv6"
		@network.ipv6 = true
	    when "u", "udp"
		@network.query_mode = NResolv::DNS::Client::UDP
	    when "t", "tcp"
		@network.query_mode = NResolv::DNS::Client::TCP
	    when "s", "std"
		@network.query_mode = NResolv::DNS::Client::Classic
	    else
		raise ParamError,
		    $mc.get("xcp_param_unknown_modopt") % [token, "transp"]
	    end
	}
    end
end
