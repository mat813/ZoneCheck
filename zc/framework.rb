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

require 'cachemanager'

##
## Class that should be inherited by every test set
##
class Test
    DefaultDNS = NResolv::DNS::DefaultResolver


    include CacheManager::CacheAttribute

    ##
    ## Abstract class for: Succeed, Failed, Error
    ##
    class Result # --> ABSTRACT <--
	class Desc
	    attr_writer :err, :msg, :xpl, :xtr

	    def initialize(testname=nil)
		@testname	= testname
		@err		= nil	# Error message
		@msg		= nil	# Test message
		@xpl		= nil	# Test explanation
		@xtr		= nil	# Extra information
	    end

	    def hash
		@testname.hash ^ @err.hash ^ @msg.hash ^ @xpl.hash ^ @xtr.hash
	    end
	    
	    def eql?(other)
		(@testname == other.instance_eval("@testname") &&
		 @err      == other.instance_eval("@err")      &&
		 @msg      == other.instance_eval("@msg")      &&
		 @xpl      == other.instance_eval("@xpl")      &&
		 @xtr      == other.instance_eval("@xtr"))
	    end
	    alias == eql?

	    def is_error? ; !@err.nil? ; end

	    def xpl
		if @xpl 
		then @xpl
		else is_error? ? nil : $mc.get("#{@testname}_explain")
		end
	    end

	    def msg
		if is_error?
		    "[TEST %s]: %s" % [ $mc.get("#{@testname}_testname"), @err] 
		else
		    $mc.get("#{@testname}_error")
		end
	    end
	end





	attr_reader :testname, :desc, :ns, :ip

	def initialize(testname, desc, ns=nil, ip=nil)
	    @testname	= testname
	    @desc	= desc
	    @ns		= ns
	    @ip		= ip
	end
	

	def eql?(other)
	    self.instance_of?(Result) && other.instance_of?(Result) &&
		self.testname == other.testname                     &&
		self.ns       == other.ns                           &&
		self.ip       == other.ip
	end
	alias == eql?
	
	def hash
	    testname.hash ^ ns.hash ^ ip.hash
	end

	def tag
	    if ! @ns.nil?
		tag = @ns.to_s
		if ! @ip.nil?
		    tag << "/"
		    tag << @ip.to_s
		end
	    else
		tag = $mc.get("generic")
	    end
	    tag
	end

	def to_s
	    @msg
	end
    end



    ##
    ## Test that has Succeed
    ##
    class Succeed < Result
	def ok? ; true ; end
    end


    
    ##
    ## Test that has Failes
    ##
    class Failed < Result
	def ok? ; false ; end
    end



    ##
    ## Test that was unable to complet due to error
    ##
    class Error < Result
	def ok? ; false ; end
    end




    def initialize(config, cm, domain_name, domain_ns)
	@attrcache_mutex	= Sync::new
	@config			= config
	@cm			= cm
	@domain_name		= domain_name
	@domain_ns		= domain_ns
    end


    # Test if 'name' is a cname
    #  If 'domain' is specified and 'name' is directly in 'domain' the
    #   request will be done using the DNS at address 'ip', otherwise
    #   the default DNS is querried
    #  WARN: this is necessary because the query could be in the
    #        domain being delegated
    #  IDEA: a better way would be to use the cachemanager to fake
    #        the nameserver NS, A and AAAA records retrieved by autoconf
    #        unfortunately we have a NO_CACHE option in the debug mode
    def is_cname?(name, ip=nil, domain=@domain_name)
	auth_domain = name.domain
	unless auth_domain == domain
	    ns_list = @cm[nil].ns(auth_domain)
	    ns_addr = @cm[nil].addresses(ns_list[0].name)
	    ip = ns_addr[0]
	end
	! @cm[ip].cname(name).nil?
    end

    def is_resolvable?(name, ip=nil, domain=@domain_name)
#	puts "IP=#{ip} DOM=#{domain} NAME=#{name}"
#	puts  name.in_domain?(domain)
#	puts  @cm[ip].rec(@domain_name) && !@cm[ip].addresses(name).empty?
#	puts !@cm[ip].rec(@domain_name) && !@cm[nil].addresses(name).empty?
	
	(( name.in_domain?(domain))                                        ||
	 ( @cm[ip].rec(@domain_name) && !@cm[ip].addresses(name).empty?)   ||
	 (!@cm[ip].rec(@domain_name) && !@cm[nil].addresses(name).empty?))
    end


    def bestresolver(name=nil)
	return @domain_ns[0][0] if name.nil?

	if ((name == @domain_name) ||
	    (name.in_domain?(@domain_name) && 
	     (name.depth - @domain_name.depth) == 1))
	    @domain_ns[0][0]
	else
	    nil
	end
    end

    
    #-- Shortcuts -----------------------------------------------
    def const(name)
	@config.const(name)
    end

    def rec(ip=nil, dom=@domain_name, force=false)
	@cm[ip].rec(dom, force)
    end

    def soa(ip=nil, dom=@domain_name, force=false)
	@cm[ip].soa(dom, force)
    end


    def ns(ip=nil, dom=@domain_name, force=false)
	@cm[ip].ns(dom, force)
    end

    def mx(ip=nil, dom=@domain_name, force=false)
	@cm[ip].mx(dom, force)
    end

    def any(ip=nil, resource=nil)
	@cm[ip].any(@domain_name, resource)
    end
    
    def addresses(name, ip=nil)
	@cm[ip].addresses(name)
    end
    
    def ptr(ip, name)
	@cm[ip].ptr(name)
    end
end



##
## Hold tests that are generic
##
module CheckGeneric
end



##
## Hold tests that are directed to an NS entry
##  => take an NS name as argument
##
module CheckNameServer
end



##
## Hold tests that are directed to a DNS running on an IP address
##  => take an NS name and an IP address as argument
##
module CheckNetworkAddress
end



##
##
##
##
module CheckExtra
end
