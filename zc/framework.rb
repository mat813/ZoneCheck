# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/08/02 13:58:17
#
# COPYRIGHT: AFNIC (c) 2003
# LICENSE  : GPL v2.0
# CONTACT  : zonecheck@nic.fr
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS:
#
#

require 'cache'
require 'cachemanager'

##
## Class that should be inherited by every test set
##
class Test
    ##
    ## Abstract class for: Succeed, Failed, Error
    ##
    class Result # --> ABSTRACT <--
	class Desc
	    attr_writer :err, :msg, :xpl, :xtr, :data

	    def initialize(testname=nil)
		@testname	= testname
		@err		= nil	# Error message
		@msg		= nil	# Test message
		@xpl		= nil	# Test explanation
		@xtr		= nil	# Extra information
		@data		= nil
	    end

	    def hash
		@testname.hash ^ @err.hash ^ @msg.hash ^ 
		    @xpl.hash ^ @xtr.hash ^ @data.hash
	    end
	    
	    def eql?(other)
		(@testname == other.instance_eval("@testname") &&
		 @err      == other.instance_eval("@err")      &&
		 @msg      == other.instance_eval("@msg")      &&
		 @xpl      == other.instance_eval("@xpl")      &&
		 @xtr      == other.instance_eval("@xtr")      &&
		 @data     == other.instance_eval("@data"))
	    end
	    alias == eql?

	    def is_error? ; !@err.nil? ; end

	    def xpl
		if @xpl 
		    @xpl
		elsif is_error?
		    nil
		else
		    x = $mc.get("#{@testname}_explain")
		    if x == "[none]"
			nil
		    else
			x
		    end
		end
	    end

	    def dtl
		return nil if @data.nil?
		
		d = $mc.get("#{@testname}_details")
		if d == "[none]"
		    nil
		else
		    d = d.dup
		    @data.each_pair { |k, v|
			d.gsub!(/%\{#{k}\}/, v.to_s)
		    }
		    d
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





	attr_reader :testname, :desc, :ns, :ip, :data

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
		tag = $mc.get("w_generic")
	    end
	    tag
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


    def self.with_msgcat(*msgcat_list)
	msgcat_list.each { |msgcat| $mc.read(msgcat) }
    end

    def initialize(network, config, cm, domain)
	@network	= network
	@config		= config
	@cm		= cm
	@domain		= domain

	@cache = Cache::new
    end


    # Test if 'name' is a cname
    #  If 'name' is inside the current domain, the specified 'ip'
    #   will be used (if 'ip' is nil the first nameserver address
    #   is used)
    #  WARN: this is necessary because the query could be in the
    #        domain being delegated
    #  IDEA: a better way would be to use the cachemanager to fake
    #        the nameserver NS, A and AAAA records retrieved by autoconf
    #        unfortunately we have a NOCACHE option in the debug mode
    def is_cname?(name, ip=nil)
	if name.in_domain?(@domain.name)
	    ip = @domain.addresses[0] if ip.nil?
	else
	    ip = nil
	end
	@cm[ip].cname(name)
    end

    def is_resolvable?(name, ip=nil, domain=@domain.name)
#	puts "IP=#{ip} DOM=#{domain} NAME=#{name}"
#	puts  name.in_domain?(domain)
#	puts  @cm[ip].rec(@domain_name) && !@cm[ip].addresses(name).empty?
#	puts !@cm[ip].rec(@domain_name) && !@cm[nil].addresses(name).empty?
	
	(( name.in_domain?(domain))                                        ||
	 ( @cm[ip].rec(@domain.name) && !@cm[ip].addresses(name).empty?)   ||
	 (!@cm[ip].rec(@domain.name) && !@cm[nil].addresses(name).empty?))
    end


    def bestresolverip(name=nil)
	return nil if name.nil?
	
	if (ips = @domain.get_resolver_ips(name)).nil?
	then nil
	else ips[0]
	end
    end

    #-- Shortcuts -----------------------------------------------
    def const(name)
	@config.const(name)
    end

    def rec(ip=nil, dom=@domain.name, force=false)
	@cm[ip].rec(dom, force)
    end

    def soa(ip=nil, dom=@domain.name, force=false)
	@cm[ip].soa(dom, force)
    end


    def ns(ip=nil, dom=@domain.name, force=false)
	@cm[ip].ns(dom, force)
    end

    def mx(ip=nil, dom=@domain.name, force=false)
	@cm[ip].mx(dom, force)
    end

    def any(ip=nil, resource=nil)
	@cm[ip].any(@domain.name, resource)
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
