# $Id$

# 
# AUTHOR : Stephane D'Alu <sdalu@nic.fr>
# CREATED: 2002/08/02 13:58:17
#
# $Revivion$ 
# $Date$
#
# CONTRIBUTORS:
#
#

require 'sync'



##
##
##
class CacheManager
    class ProxyResource
	attr_reader :ttl, :r_name
	def initialize(resource, ttl, name, msg)
	    @resource = resource
	    @ttl      = ttl
	    @r_name   = name
	    @msg      = msg
	end

	def aa
	    @msg.aa
	end

	def method_missing(method, *args)
	    @resource.method(method).call(*args)
	end
    end

    attr_reader :all_caches, :all_caches_m, :root


    def cache_attribute(attribute, args=nil, force=false)
	@mutex.synchronize {
	    if force || (r = instance_eval("#{attribute}")).nil?
		r = yield
		instance_eval("#{attribute} = r")
#		puts "Computed: #{attribute}=#{r}"
	    else
#		puts "Cached: #{attribute}=#{r}"
	    end
	    r
	}
    end

    def initialize(root, dns)
	@root		= root.nil? ? self      : root
	@all_caches	= root.nil? ? {}        : root.all_caches
	@all_caches_m	= root.nil? ? Sync::new : root.all_caches_m
	@address	= {}
	@soa		= {}
	@any		= {}
	@ns		= {}
	@cname		= {}
	@dns		= dns
	@mutex		= Sync::new
    end
    
    def [](ip, client=NResolv::DNS::Client::Classic)
	@all_caches_m.synchronize {
	    return @root if ip.nil?

	    ip = ip.to_s
	    config = NResolv::DNS::Config::new([ ip ], [])
	    if (ic = @all_caches[[ip, client]]).nil?
		dns    = client::new(config)
		ic     = CacheManager::new(@root, dns)
		@all_caches[config] = ic
	    end
	    ic
	}
    end


    # Create the root information cache
    def self.create(dns)
	CacheManager::new(nil, dns)
    end


    def get_resources(name, resource, rec=true, exception=true)
	res = []
	@dns.each_resource(name, resource, rec, true) {|r,t,n,m|
	    res << ProxyResource::new(r,t,n,m)
	}
	res
    end

    def get_resource(name, resource, rec=true, exception=true)
	@dns.each_resource(name, resource, rec, true) {|r,t,n,m|
	    return ProxyResource::new(r,t,n,m)
	}
	nil
    end

    #
    def any(domainname, resource=nil)
	res = cache_attribute("@any[args[0]]", [ domainname ]) {
	    get_resources(domainname, NResolv::DNS::Resource::IN::ANY)
	}
	if resource.nil?
	    return res
	else
	    nres = [ ]
	    res.each { |r| nres << r if r.instance_of?(resource) }
	    return nres
	end
    end

    def soa(domainname, force)
	cache_attribute("@soa[args[0]]", [ domainname ], force) {
	    get_resource(domainname, NResolv::DNS::Resource::IN::SOA)
	}
    end

    def ns(domainname, force)
	cache_attribute("@ns[args[0]]", [ domainname ], force) {
	    get_resources(domainname, NResolv::DNS::Resource::IN::NS)
	}
    end
    
    def cname(name)
	cache_attribute("@cname[args[0]]", [ name ]) {
	    get_resource(name, NResolv::DNS::Resource::IN::CNAME)
	}
    end

    def addresses(host, order=Address::OrderDefault)
	host = NResolv::to_nameaddr(host)
	case host
	when Address::IPv4, Address::IPv6
	    [ host ]
	when NResolv::DNS::Name
	    cache_attribute("@address[args[0]]", [ host ]) {
		@dns.addresses(host, order)
	    }
	else
	    raise RuntimeError
	end
    end
end
