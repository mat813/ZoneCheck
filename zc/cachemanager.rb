# $Id$

# 
# CONTACT     : zonecheck@nic.fr
# AUTHOR      : Stephane D'Alu <sdalu@nic.fr>
#
# CREATED     : 2002/08/02 13:58:17
# REVISION    : $Revision$ 
# DATE        : $Date$
#
# CONTRIBUTORS: (see also CREDITS file)
#
#
# LICENSE     : GPL v2 (or MIT/X11-like after agreement)
# COPYRIGHT   : AFNIC (c) 2003
#
# This file is part of ZoneCheck.
#
# ZoneCheck is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# ZoneCheck is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ZoneCheck; if not, write to the Free Software Foundation,
# Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#

#####
#
# TODO:
#   - add a close/destroy function to destroy the cachemanager and free
#     the dns resources
#

require 'sync'
require 'cache'

##
## The CacheManager
##
class CacheManager
    ##
    ## Proxy an NResolv::DNS::Resource class
    ##
    ## This will allow to add access to extra fields that are normally
    ## provided only in the DNS message header:
    ##  - ttl    : time to live
    ##  - aa     : authoritative answer
    ##  - ra     : recursivity available
    ##  - r_name : resource name
    ##
    class ProxyResource
	attr_reader :ttl, :aa, :ra, :r_name

	#
	# Initialize proxy 
	#
	def initialize(resource, ttl, name, msg)
	    @resource = resource
	    @ttl      = ttl
	    @r_name   = name
	    @aa       = msg.aa
	    @ra       = msg.ra
	end
	
	#
	# Save the class method for later use
	# 
	alias _class class

	#
	# Equality should work with proxy object or real object
	#
	def eql?(other)
	    return false unless self.class == other.class
	    other = other.instance_eval('@resource') if respond_to?(:_class)
	    @resource == other
	end
	alias == eql?

	#
	# Redefine basic methods (hash, class, ...) to point to the
	# real object
	#
	def hash        ; @resource.hash        ; end
	def to_s        ; @resource.to_s        ; end
	def class       ; @resource.class       ; end
	def kind_of?(k) ; @resource.kind_of?(k) ; end
	alias instance_of? kind_of?
	alias is_a?        kind_of?

	#
	# Direct all unknown methods to the real object
	#
	def method_missing(method, *args)
	    @resource.method(method).call(*args)
	end
    end




    attr_reader :all_caches, :all_caches_m, :root

    def clear
	@cache.clear
    end


    private
    def initialize(root, dns, client)
	# Root node propagation
	@root		= root.nil? ? self      : root
	@all_caches	= root.nil? ? {}        : root.all_caches
	@all_caches_m	= root.nil? ? Sync::new : root.all_caches_m

	# DNS / client type
	@dns		= dns
	@client		= client

	# Cached items
	@cache = Cache::new
	@cache.create(:address, :soa, :any, :ns, :mx, :cname, :a, :aaaa, :ptr, :rec)
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
	    # Is the root asked?
	    return @root if ip.nil?

	    # Sanity check
	    case ip
	    when Address
	    else raise 'Argument should be an Address'
	    end
 
	    # Retrieve/Create the cachemanager for the address
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
    def self.create(dns, client=NResolv::DNS::Client::STD)
	CacheManager::new(nil, dns, client)
    end



    #-- Shortcuts ----------------------------------------------------
    def addresses(host, order=Address::OrderDefault)
	host = NResolv::to_addrname(host)
	case host
	when Address
	    [ host ]
	when NResolv::DNS::Name
	    @cache.use(:address, host) {
		begin
		    @dns.getaddresses(host, order)
		rescue NResolv::DNS::NoEntryError
		    []
		end
	    }
	else
	    raise ArgumentError, 'Expecting Address or DNS Name'
	end
    end

    # ANY records
    def any(domainname, resource=nil, force=nil)
	res = @cache.use(:any, domainname, force) {
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
	@cache.use(:soa, domainname, force) {
	    get_resource(domainname,  NResolv::DNS::Resource::IN::SOA)
	}
    end

    # NS records
    def ns(domainname, force=nil)
	@cache.use(:ns, domainname, force) {
	    get_resources(domainname, NResolv::DNS::Resource::IN::NS)
	}
    end
    
    # MX record
    def mx(domainname, force=nil)
	@cache.use(:mx, domainname, force) {
	    get_resources(domainname, NResolv::DNS::Resource::IN::MX)
	}
    end
    
    # A record
    def a(name, force=nil)
	@cache.use(:a, name, force) {
	    get_resources(name,        NResolv::DNS::Resource::IN::A)
	}
    end
    
    # AAAA record
    def aaaa(name, force=nil)
	@cache.use(:aaaa, name, force) {
	    get_resources(name,        NResolv::DNS::Resource::IN::AAAA)
	}
    end
    
    # CNAME record
    def cname(name, force=nil)
	@cache.use(:cname, name, force) {
	    get_resource(name,        NResolv::DNS::Resource::IN::CNAME)
	}
    end

    # PTR records
    def ptr(name, force=nil)
	@cache.use(:ptr, name, force) {
	    get_resources(name,       NResolv::DNS::Resource::IN::PTR)
	}
    end	

    # TXT record
    def txt(name, force=nil)
	@cache.use(:ptr, name, force) {
	    get_resources(name,       NResolv::DNS::Resource::IN::TXT)
	}
    end
    
    #-- Shortcuts ----------------------------------------------------
    def rec(domainname, force=nil)
	@cache.use(:rec, domainname, force) {
	    soa = soa(domainname, force)
	    raise NResolv::NResolvError, 'Domain doesn\'t exists' if soa.nil?
	    soa.ra
	}
    end
end
