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

#####
#
# TODO:
#   - add a close/destroy function to destroy the cachemanager and free
#     the dns resources
#

require 'sync'

##
## The CacheManager
##
class CacheManager
    ##
    ## The CacheAttribute module add attribut caching capability when 
    ## imported by a class
    ##
    ## WARN: the class should define attrcache_mutex as Sync
    ##
    module CacheAttribute
	def cache_attribute(attr, args=nil, force=false)
	    attribute = case args
			when NilClass  then attr
			when Array     then case args.length
					    when 0 then attr
					    when 1 then "#{attr}[args[0]]"
					    else        "#{attr}[args]"
					    end
			else           "#{attr}[args]"
			end

	    return yield if $dbg.enable?(DBG::NOCACHE)

	    @attrcache_mutex.synchronize {
		if force || (r = instance_eval("#{attribute}")).nil?
		    r = yield
		    instance_eval("#{attribute} = r")
		    $dbg.msg(DBG::CACHE_INFO, "computed: #{attribute}=#{r}")
		else
		    $dbg.msg(DBG::CACHE_INFO, "cached  : #{attribute}=#{r}")
		end
		r
	    }
	end
    end



    ##
    ## Proxy an NResolv::DNS::Resource class
    ##
    ## This will allow to add access to extra fields that are normally
    ## provided only in the DNS message header
    ##
    class ProxyResource
	attr_reader :ttl, :aa, :ra, :r_name
	def initialize(resource, ttl, name, msg)
	    @resource = resource
	    @ttl      = ttl
	    @r_name   = name
	    @aa       = msg.aa
	    @ra       = msg.ra
	end

	alias _type type
	def type
	    @resource.type
	end
	alias class type

	def kind_of?(k)
	    @resource.kind_of?(k)
	end
	alias instance_of? kind_of?
	alias is_a?        kind_of?

	def eql?(other)
	    return false unless self.type == other.type
	    other = other.instance_eval("@resource") if respond_to?(:_type)
	    @resource == other
	end
	alias == eql?

	def hash
	    @resource.hash
	end

	def to_s
	    @resource.to_s
	end

	def method_missing(method, *args)
	    @resource.method(method).call(*args)
	end
    end







    include CacheAttribute

    attr_reader :all_caches, :all_caches_m, :root


    private
    def initialize(root, dns, client)
	# Root node propagation
	@root		= root.nil? ? self      : root
	@all_caches	= root.nil? ? {}        : root.all_caches
	@all_caches_m	= root.nil? ? Sync::new : root.all_caches_m

	# DNS / client type
	@dns		= dns
	@client		= client

	# Cached attributs
	@attrcache_mutex= Sync::new
	@address	= {}
	@soa		= {}
	@any		= {}
	@ns		= {}
	@mx		= {}
	@cname		= {}
	@ptr		= {}
	@rec		= {}
    end
    
    def get_resources(name, resource, rec=true, exception=false)
	res = []
	@dns.each_resource(name, resource, rec, exception) {|args|
	    res << ProxyResource::new(*args)
	}
	res
    end

    def get_resource(name, resource, rec=true, exception=false)
	@dns.each_resource(name, resource, rec, exception) {|args|
	    return ProxyResource::new(*args)
	}
	nil
    end


    public
    def [](ip, client=@client)
	@all_caches_m.synchronize {
	    return @root if ip.nil?

	    ip = ip.to_s
	    config = NResolv::DNS::Config::new([ ip ], [])
	    key    = [ip, client]
	    if (ic = @all_caches[key]).nil?
		dns    = client::new(config)
		ic     = CacheManager::new(@root, dns, client)
		@all_caches[key] = ic
	    end
	    ic
	}
    end

    

    # Create the root information cache
    def self.create(dns, client=NResolv::DNS::Client::Classic)
	CacheManager::new(nil, dns, client)
    end



    #-- Shortcuts ----------------------------------------------------
    def addresses(host, order=Address::OrderDefault)
	host = NResolv::to_nameaddr(host)
	case host
	when Address::IPv4, Address::IPv6
	    [ host ]
	when NResolv::DNS::Name
	    cache_attribute("@address", host) {
		begin
		    @dns.addresses(host, order)
		rescue NResolv::NoEntryError
		    []
		end
	    }
	else
	    raise RuntimeError
	end
    end

    # ANY records
    def any(domainname, resource=nil, force=nil)
	res = cache_attribute("@any", domainname, force) {
	    get_resources(domainname, NResolv::DNS::Resource::IN::ANY)
	}
	if resource.nil?
	    return res
	else
	    nres = [ ]
	    res.each { |r| nres << r if r.class == resource }
	    return nres
	end
    end

    # SOA record
    def soa(domainname, force=nil)
	cache_attribute("@soa", domainname, force) {
	    get_resource(domainname,  NResolv::DNS::Resource::IN::SOA)
	}
    end

    # NS records
    def ns(domainname, force=nil)
	cache_attribute("@ns", domainname, force) {
	    get_resources(domainname, NResolv::DNS::Resource::IN::NS)
	}
    end
    
    # MX record
    def mx(domainname, force=nil)
	cache_attribute("@mx", domainname, force) {
	    get_resources(domainname, NResolv::DNS::Resource::IN::MX)
	}
    end
    
    # CNAME record
    def cname(name, force=nil)
	cache_attribute("@cname", name, force) {
	    get_resource(name,        NResolv::DNS::Resource::IN::CNAME)
	}
    end

    # PTR records
    def ptr(name, force=nil)
	cache_attribute("@ptr", name, force) {
	    get_resources(name,       NResolv::DNS::Resource::IN::PTR)
	}
    end	

    
    #-- Shortcuts ----------------------------------------------------
    def rec(domainname, force=nil)
	cache_attribute("@rec", domainname, force) {
	    soa(domainname, force).ra
	}
    end
end
