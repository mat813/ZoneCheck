# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/08/02 13:58:17
#
# COPYRIGHT: AFNIC (c) 2003
# LICENSE  : GPL v2 (or MIT/X11-like after agreement)
# CONTACT  : zonecheck@nic.fr
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS: (see also CREDITS file)
#
#

require 'dbg'
require 'report'
require 'publisher'



##
## Parameters of the ZoneCheck application
## 
## All the subclasses have an 'autoconf' method, which should be
## used to finish configuring the class.
##
class Param
    ##
    ## Hold the flags used to describe report output behaviour
    ##
    ## tagonly      : only print tag or information suitable for parsing
    ## one          : only print 1 message
    ## quiet        : don't print extra titles
    ## intro        : display summary about checked domain
    ## testname     : print the name of the test in the report
    ## explain      : explain the reason behind the test (if test failed)
    ## details      : give details about the test failure
    ## testdesc     : print a short description of the test being performed
    ## counter      : display a progress bar
    ## stop_on_fatal: stop on the first fatal error
    ## reportok     : also report test that have passed
    ##
    ## Corrections are silently made to respect the following constraints:
    ##  - 'tagonly' doesn't support 'explain', 'details' (as displaying
    ##     a tag for an explanation is meaningless)
    ##  - 'testdesc' and 'counter' are exclusive
    ##  - 'counter' can be ignored if the display doesn't suppport 
    ##     progress bar animation
    ##  - 'one' ignore 'testname', 'explain', 'details'
    ##
    class ReportFlag
	attr_reader :tagonly,  :one,   :quiet
	attr_reader :testname, :intro, :explain, :details
	attr_reader :testdesc, :counter
	attr_reader :stop_on_fatal, :reportok

	attr_writer :one, :quiet, :intro
	attr_writer :stop_on_fatal, :reportok
	attr_writer :testname

	def initialize
	    @tagonly  = @one                           	= false
	    @intro    = @testname = @details = @explain	= false
	    @testdesc = @counter			= false
	    @stop_on_fatal				= true
	    @reportok					= false
	end

	def tagonly=(val)
	    @details = @explain  = false if @tagonly = val
	end

	def explain=(val)
	    @explain  = val   if !@tagonly
	end
	
	def details=(val)
	    @details  = val   if !@tagonly
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
	    flags << "testname" if @testname
	    flags << "explain"  if @explain
	    flags << "details"  if @details
	    flags << "testdesc" if @testdesc
	    flags << "counter"  if @counter
	    flags << "stop"     if @stop_on_fatal
	    flags << "reportok" if @reportok
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
    ## cache     : should result be stored in external database (for hooks)
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
	    @ns_input	= nil
	    @addresses	= nil
	    @cache	= true
	end

	# 
	# The policy for caching is (stop on first match):
	#   - the NS have been guessed           => false
	#   - a necessary glue is missing        => false
	#   - an unecessary glue has been given  => false
	#   - everything else                    => true
	#
	def can_cache?
	    # purely guessed information
	    return false if @ns_input.nil?
	    # glue misused
	    @ns_input.each { |ns, ips|
		return false unless ns.in_domain?(@name) ^ !ips.empty? }
	    # ok
	    true
	end

	def name=(domain)
	    domain = NResolv::DNS::Name::create(domain, true)
	    unless domain.absolute?
		raise ArgumentError, $mc.get("xcp_param_fqdn_required")
	    end
	    @name = domain
	end
	
	def ns=(ns)
	    return @ns = @ns_input = nil if ns.nil?

	    # Parse inputed NS (and IPs)
	    @ns_input = [ ]
	    ns.split(/\s*;\s*/).each { |entry|
		ips  = []
		if entry =~ /^(.*)=(.*)$/
		    host_str, ips_str = $1, $2
		    host = NResolv::DNS::Name::create(host_str, true)
		    ips_str.split(/\s*,\s*|\s+/).each { |str|
			ips << Address::create(str) }
		else
		    host = NResolv::DNS::Name::create(entry, true)
		end
		@ns_input << [ host, ips ]
	    }

	    # Do a deep copy
	    @ns = [ ]
	    @ns_input.each { |host, ips| @ns << [ host, ips.dup ] }

	    # 
	    @ns
	end

	def autoconf(dns)
	    # Guess Nameservers and ensure primary is at first position
	    if @ns.nil?
		$dbg.msg(DBG::AUTOCONF, "Retrieving NS for #{@name}")
		begin
		    primary = dns.primary(@name)
		    $dbg.msg(DBG::AUTOCONF,
			     "Identified NS primary as #{primary}")
		rescue NResolv::NResolvError
		    raise ParamError, $mc.get("xcp_param_primary_soa")
		end

		# Retrieve NS and put ensure the primary at first place
		#  (based on SOA)
		begin
		    @ns = [ ]
		    dns.nameservers(@name).each { |n|
			if n == primary
			then @ns.unshift([ n, [] ])
			else @ns <<  [ n, [] ]
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
		@cache &&= can_cache?
		$dbg.msg(DBG::AUTOCONF, "Cache status set to #{@cache}")
	    end
	    
	    # Guess Nameservers IP addresses
	    @ns.each { |ns, ips|
		if ips.empty? then
		    $dbg.msg(DBG::AUTOCONF, "Retrieving IP for NS: #{ns}")
		    begin
			ips.concat(dns.getaddresses(ns, Address::OrderStrict))
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

	def get_resolver_ips(name, prim=false)
	    if name.nil? || !((name == @name) || (name.in_domain?(@name)))
		nil
#	    elsif (name.depth - @name.depth) > 1
#		raise RuntimeError, "XXX: correct behaviour not decided (#{name})"
	    else
		if prim
		then ns[0][1]
		else @addresses
		end
	    end
	end
    end



    ##
    ## As the Report class, but allow severity override
    ##
    class ProxyReport
	attr_reader :info, :warning, :fatal
	
	def initialize
	    @report_class	= nil
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

	def standard
	    @warning_attrname	= :warning
	    @fatal_attrname	= :fatal
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
	    # Set publisher class (if not already done)
	    if @report_class.nil?
		require 'report/byseverity'
		@report_class = ::Report::BySeverity
	    end

	    # Instanciate report engine
	    @report	= @report_class::new(domain, rflag, publisher)
	    # Define dealing of info/warning/fatal severity
	    @info       = @report.method(@info_attrname).call
	    @warning    = @report.method(@warning_attrname).call
	    @fatal      = @report.method(@fatal_attrname).call

	    # Check for 'tagonly' support
	    if rflag.tagonly && !@report.tagonly_supported?
		raise ParamError, 
		    $mc.get("xcp_param_output_support") % [ "tagonly" ]
	    end
	    # Check for 'one' support
	    if rflag.one     && !@report.one_supported?
		raise ParamError, 
		    $mc.get("xcp_param_output_support") % [ "one"     ]
	    end

	    # Debug
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
	    # Debug
	    $dbg.msg(DBG::AUTOCONF, "configuration file: #{@cfgfile}")
	    $dbg.msg(DBG::AUTOCONF, "tests directory: #{@testdir}")
	end
    end



    ##
    ## Hold information about the resolver behaviour
    ## 
    ## ipv4    : use IPv4 routing protocol
    ## ipv6    : use IPv6 routing protocol
    ## mode    : use the following mode for new resolvers: STD / UDP / TCP 
    ##
    class Network
	attr_reader :ipv4, :ipv6, :query_mode
	attr_writer :query_mode

	def initialize
	    @ipv6		= nil
	    @ipv4		= nil
	    @query_mode		= nil
	end

	def ipv6=(bool)
	    if bool && ! $ipv6_stack
		raise ParamError, $mc.get("xcp_param_ip_no_stack") % "IPv6"
	    end
	    @ipv6 = bool
	end

	def ipv4=(bool)
	    if bool && ! $ipv4_stack
		raise ParamError, $mc.get("xcp_param_ip_no_stack") % "IPv4"
	    end
	    @ipv4 = bool
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
	    # Select routing protocol (IPv4/IPv6)
	    @ipv4 = @ipv6 = true if @ipv4.nil? && @ipv6.nil?
	    @ipv4 = false        if @ipv4.nil? || !$ipv4_stack
	    @ipv6 = false        if @ipv6.nil? || !$ipv6_stack
	    raise "Why are you using this program!" if !@ipv4 && !@ipv6
	    # Debug
	    $dbg.msg(DBG::AUTOCONF, 
		     "Routing protocol set to: " +
		     [ @ipv4 ? "IPv4" : nil, 
		       @ipv6 ? "IPv6" : nil].compact.join("/"))

	    # Select mode
	    @query_mode = NResolv::DNS::Client::STD if @query_mode.nil?
	    # Debug
	    @query_mode.to_s =~ /([^:]+)$/
	    $dbg.msg(DBG::AUTOCONF, "Query mode set to: #{$1}")
	end
    end



    ##
    ## Hold information about local resolver
    ##
    ## local: local resolver to use
    ##
    class Resolver
	attr_reader :local

	def initialize
	    @local	= nil
	    @local_name	= nil
	end

	def local=(resolv)
	    resolv = resolv.clone.untaint if resolv.tainted?
	    @local_name = if resolv.nil? || resolv =~ /^\s*$/
			  then nil
			  else resolv
			  end
	    @local = nil
	end

	def autoconf
	    # Select local resolver
	    if @local.nil?
		@local = if @local_name.nil?
			     # Use default resolver
			     NResolv::DNS::DefaultResolver
			 else 
			     # Check that we can resolv the resolver
			     unless Address.is_valid(@local_name)
				 dft = NResolv::DNS::DefaultResolver
				 if dft.getaddresses(@local_name).empty?
				     raise ParamError, 
					 $mc.get("xcp_param_local_resolver") % @local_name
				 end
			     end
			     # Build new resolver
			     cfg = NResolv::DNS::Config::new(@local_name)
			     NResolv::DNS::Client::STD::new(cfg)
			 end
	    end

	    # Debug
	    $dbg.msg(DBG::AUTOCONF, "Resolver " + 
		     (@local_name.nil? ? "<default>" : @local_name))
	end
    end


    ##
    ## Hold information about the test
    ## 
    ## list      : has listing of test name been requested
    ## test      : limiting tests to this list
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
	    @tests = if string.nil? || string =~ /^\s*$/
		     then nil
		     else string.split(/\s*,\s*/)
		     end
	end

	def categories=(string)
	    return if string =~ /^\s*$/
	    @categories = string.split(/\s*,\s*/)
	end

	def autoconf
	    # Debug
	    $dbg.msg(DBG::AUTOCONF, 
	      "Test description requested for type: #{@desctype}") if @desctype
	    $dbg.msg(DBG::AUTOCONF, "Test listing requested") if @list
	    $dbg.msg(DBG::AUTOCONF, "Selected tests: " +
		     (@tests.nil? ? "ALL" : @tests.join(',')))
	    $dbg.msg(DBG::AUTOCONF, "Selected categories: " +
		     (@categories ? @categories.join(",") : "+"))
	end
    end


    ##
    ## Hold information about the publisher
    ##
    ## engine : the publisher to use (write class, read object)
    ##
    class Publisher
	def initialize
	    @publisher_class	= nil
	    @publisher		= nil
	end
	
	def engine=(klass)
	    @publisher_class = klass
	end
	def engine
	    @publisher
	end

	def autoconf(rflag)
	    # Set publisher class (if not already done)
	    if @publisher_class.nil?
		require 'publisher/text'
		@publisher_class = ::Publisher::Text
	    end

	    # Set output publisher
	    @publisher = @publisher_class::new(rflag, $console.stdout)

	    $dbg.msg(DBG::AUTOCONF, "Publish using #{@publisher_class}")
	end
    end


    ##
    ## Exception: Parameter errors (ie: usage)
    ##
    class ParamError < StandardError
    end



    ##
    ## Wrapper for batch data, so that they have the same kind
    ## of IO interfaces as File or STDIN
    ##
    class BatchData
	def initialize(data)  ; @data = data.split(/\n/) ; end
	def each_line(&block) ; @data.each &block        ; end
	def close             ; @data = nil              ; end
    end




    #
    # ATTRIBUTS
    #
    attr_reader :publisher, :fs, :network, :resolver, :rflag, :test, :report
    attr_reader :batch, :domain
    attr_writer :batch, :domain



    #
    # Create parameters
    #
    def initialize
	@publisher		= Publisher::new
	@fs			= FSData::new
	@network		= Network::new
	@resolver		= Resolver::new
	@test			= Test::new
	@report			= ProxyReport::new
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
	    when "af",  "allfatal"
		@report.allfatal
	    when "aw",  "allwarning"
		@report.allwarning
	    when "s",   "stop"
		@rflag.stop_on_fatal = true
	    when "ns",  "nostop"
		@rflag.stop_on_fatal = false
	    when "std", "standard"
		@report.standard
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
	    when "i", "intro"
		@rflag.intro	= true
	    when "n", "testname"
		@rflag.testname	= true
	    when "x", "explain"
		@rflag.explain	= true
	    when "d", "details"
		@rflag.details  = true
	    when "o", "reportok"
		@rflag.reportok	= true
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
	    when "bs", "byseverity"
		require 'report/byseverity'
		@report.reporter  = Report::BySeverity
	    when "bh", "byhost"
		require 'report/byhost'
		@report.reporter  = Report::ByHost
	    when "t", "text"
		require 'publisher/text'
		@publisher.engine = ::Publisher::Text
	    when "h", "html"
		require 'publisher/html'
		@publisher.engine = ::Publisher::HTML
	    when "g", "gtk"
		require 'publisher/gtk'
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
		@network.query_mode = NResolv::DNS::Client::STD
	    else
		raise ParamError,
		    $mc.get("xcp_param_unknown_modopt") % [token, "transp"]
	    end
	}
    end
end
