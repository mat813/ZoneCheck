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
    class Answer # --> ABSTRACT <--
	attr_reader :testname, :ns, :ip

	def initialize(testname, msg=nil, xpl=nil, xtra=nil, ns=nil, ip=nil)
	    @testname = testname
	    @msg      = msg	# Error message (if unexpected)
	    @xpl      = xpl	# Test explanation
	    @xtra     = xtra	# Extra information
	    @ns       = ns
	    @ip       = ip
	end
	
	def is_unexpected?
	    !@msg.nil?
	end

	def msg
	    if is_unexpected?
		"[TEST %s]: %s" % [ $mc.get("#{testname}_testname"), @msg] 
	    else
		$mc.get("#{testname}_error")
	    end
	end

	def testdesc
	    $mc.get("#{testname}_testname")
	end


	def explanation
	    if @xpl
		@xpl
	    else
		is_unexpected? ? nil : $mc.get("#{@testname}_explain")
	    end
	end

	def eql?(other)
	    self.instance_of?(Answer) && other.instance_of?(Answer) &&
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
    class Succeed < Answer
	def ok? ; true ; end
    end


    
    ##
    ## Test that has Failes
    ##
    class Failed < Answer
	def ok? ; false ; end
    end



    ##
    ## Test that was unable to be completed due to error
    ##
    class Error < Answer
	def ok? ; false ; end
    end




    def initialize(cm, domain_name, domain_ns)
	@attrcache_mutex	= Sync::new
	@domain_name		= domain_name
	@domain_ns		= domain_ns
	@cm			= cm
    end



    def is_cname?(ip, name)
	! @cm[ip].cname(name).nil?
    end

    def is_resolvable?(ip, name, domain)
	! (( name.in_domain?(domain)   && @cm[ip].addresses(name).empty?)   ||
	   ( @cm[ip].rec(@domain_name) && @cm[ip].addresses(name).empty?)   ||
	   (!@cm[ip].rec(@domain_name) && @cm[nil].addresses(name).empty?))
    end



    
    #-- Shortcuts -----------------------------------------------
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
