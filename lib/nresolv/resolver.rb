# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/07/19 07:28:13
#
# COPYRIGHT: AFNIC (c) 2003
# CONTACT  : 
# LICENSE  : RUBY
#
# $Revision$ 
# $Date$
#
# INSPIRED BY:
#   - the ruby file: resolv.rb 
#
# CONTRIBUTORS: (see also CREDITS file)
#
#

require 'nresolv/dns'
require 'nresolv/transport'
require 'nresolv/config'
require 'nresolv/dbg'


#
# TODO: check implementation when following cname for non recursive
# TODO: better handling of exception (see CNAME exception)
# TODO: cname loop
#

class NResolv
    class DNS
	class DNSNResolvError < NResolvError
	    attr_reader :mesg
	    def initialize(mesg=nil) ; @mesg = mesg ; end
	    def to_s ; (mesg.nil? ? self.class : mesg).to_s ; end
	end

	class ReplyError    < DNSNResolvError
	    attr_reader :code, :name, :resource
	    def mesg ; @code ; end
	    def initialize(code, name, resource) 
		@code, @name, @resource = code, name, resource
	    end
	end

	class NoEntryError  < DNSNResolvError
	end

	class NoDomainError < NoEntryError
	end

    
	##
	## Abstract client class
	##  - support multiple servers
	##  - protocol layer is selected using Requester
	##
	class Client
	    attr_reader :config

	    def initialize(config=Config::Default)
		if self.class == Client
		    raise "#{self.class} is an abstract class"
		end
		@config = config
	    end

	    def getaddress(name, order=Address::OrderDefault)
		@config.candidates(name).each { |fqname|
		    each_address(fqname, order) { |address| return address } }
		raise NoEntryError, "address for #{name} not found"
	    end

	    def getaddresses(name, order=Address::OrderDefault)
		addrs = []
		@config.candidates(name).each { |fqname|
		    each_address(name, order) { |address| addrs << address }
		    break unless addrs.empty?
		}
		addrs
	    end

	    def getname(address)
		each_name(address) {|name| return name}
		raise NoEntryError, "no PTR information about #{address}"
	    end

	    def getnames(address)
		ret = []
		each_name(address) { |name| ret << name }
		return ret
	    end

	    
	    def getresources(name, resource, rec=true, exception=true)
		ret = [ ]
		each_resource(name, resource, rec, exception) {|resource,| 
		    ret << resource }
		return ret
	    end

	    #
	    # yield: resource, ttl, name, msg
	    # exceptions: NoEntryError, NoDomainError
	    def each_resource(name, resource, rec=true, exception=true)
		msg = NResolv::DNS::Message::Query::new
		msg.rd = rec
		msg.question.add(name, resource)
		rpl = query(msg)

		case rpl.rcode
		when RCode::NOERROR
		when RCode::NXDOMAIN
		    raise NoDomainError, rpl.rcode if exception
		    return
		else
		    raise ReplyError::new(rpl.rcode, name, resource)
		end

		count = 0
		extract_resource(rpl, name, resource) { |n, r, t|
		    yield [r, t, n, rpl]
		    count += 1
		}

		if exception && (count == 0)
		    raise NoEntryError, 'no matching answer'
		end
	    end

	    #
	    # yield: name, resource, ttl
	    def extract_resource(msg, name, resource)
		case resource.rtype 
		when RType::AXFR
		    msg.answer.each { |n, r, t|
			yield [n, r, t]
		    }
		when RType::ANY
		    msg.answer.each { |n, r, t|
			yield [n, r, t] if n == name
		    }
		when RType::CNAME
		    msg.answer.each { |n, r, t|
			yield [n, r, t] if (n == name) && (r.class == resource)
		    }
		else
		    # Do CNAME resolution
		    cnameloop = {}
		    catch (:redo) {
			msg.answer.each { |n, r, t| 
			    if (n == name) && (r.rtype == RType::CNAME)
				Dbg.msg(DBG::RESOLVER, 
					"following CNAME #{n} => #{r.cname}")
				if cnameloop.has_key?(name)
				    raise 'CNAME loop detected'
				end
				cnameloop[name] = true
				name = r.cname
				throw :redo
			    end
			}
		    }

		    found = false
		    msg.answer.each { |n, r, t|
			if (n == name) && (r.class == resource)
			    found = true
			    yield [n, r, t] 
			end
		    }

		    if !found && !cnameloop.empty?
			Dbg.msg(DBG::RESOLVER, 
				'iterate on CNAME not implemented (response will be empty)')
		    end
		end
	    end


	    def master(domain)
		domain = Name::create(domain)
		each_resource(domain, Resource::IN::SOA) { |r,|
		    return r.mname }
	    end
	    alias primary master

	    def nameservers(domain)
		domain = Name::create(domain)
		ns = []
		each_resource(domain, NResolv::DNS::Resource::IN::NS) { |r,|
		    ns << r.name }
		ns
	    end

	    def each_name(address)
		# ensure we got a DNS::Name
		#  (addresses are automatically conerted in their .arpa space)
		name = Name::create(address)

		# retrieve PTR information
		each_resource(name, Resource::IN::PTR, true, false) { |r,| 
		    yield r.ptrdname }
	    end


	    #
	    #  WARN: this can result in duplicated entries if order
	    #        wasn't correctly defined
	    def each_address(name, order=Address::OrderDefault)
		# ensure we got a DNS::Name
		name = Name::create(name)

		# Sanity check
		if ! name.absolute?
		    raise ArgumentError, 'DNS name should be abolute'
		end

		ipv4=ipv6=false
		order.each { |o|
		    if    o == Address::IPv6::Compatibility then ipv4=ipv6=true
		    elsif o == Address::IPv6                then      ipv6=true
		    elsif o == Address::IPv4                then ipv4     =true
		    else raise ArgumentError, "unknown address type #{o}"
		    end
		}

		list = nil
		if ipv4 && ipv6 then
		    list = getaddr(name, NResolv::DNS::Resource::IN::ANY,
				   [ RType::A, RType::AAAA ],
				   [ RCode::NOTIMP ], true)
		end

		if list.nil?
		    list = []
		    if ipv6
			begin
			    ignore = [ RCode::NOTIMP ]
			    ignore << RCode::SERVFAIL << RCode::FORMERR if ipv4
			    list << getaddr(name, 
					    NResolv::DNS::Resource::IN::AAAA,
					    [ RType::AAAA ], ignore, false)
			rescue NResolv::TimeoutError
			    raise unless ipv4
			end
		    end

		    if ipv4
			list << getaddr(name, NResolv::DNS::Resource::IN::A,
				    [ RType::A ], [ RCode::NOTIMP ], false)
		    end
		end

		list.flatten!
		list.compact

		addrlist = []
		order.each { |klass|
		    list.delete_if { |addr|
			begin
			    addrlist << klass::create(addr)
			    true
			rescue Address::InvalidAddress
			    false
			end
		    }
		}
		addrlist.each { |addr| yield addr }
	    end


	    private
	    def getaddr(name, resource, rtypes, ignore, auth)
		addrlist = []
		msg = NResolv::DNS::Message::Query::new
		msg.rd = !auth
		msg.question.add(name, resource)
		rpl = query(msg)
		
		if rpl.rcode == RCode::NOERROR
		    return nil unless !auth || rpl.aa
		    extract_resource(rpl, name, resource) { |n, r, t|
			addrlist << r.address if rtypes.include?(r.rtype) }
		elsif ignore.include?(rpl.rcode)
		    return nil
		else raise ReplyError::new(rpl.rcode, name, resource)
		end
		addrlist
	    end

	    ##
	    ## UDP only client
	    ##  (support multiple DNS servers)
	    ##
	    ## WARN: this could result dealing later with truncated messages
	    ##
	    class UDP < Client
		def initialize(config=Config::Default)
		    super(config)
		    @requester = config.nameserver.collect { |ns|
			NResolv::DNS::Requester::UDP::new(ns) }
		end

		def close
		    @requester.each { |r| r.close }
		end

		def query(msg)
		    # XXX: should be able to receive multiple envelops
		    # XXX: not sure for udp
		    exception = nil
		    @requester.each { |r|
			begin
			    nmsg = r.query(msg).send.wait
			    if nmsg.tc
				Dbg.msg(DBG::RESOLVER, 
					'truncated message due to UDP')
			    end
			    return nmsg
			rescue NResolv::TimeoutError, 
			       NResolv::NetworkError => exception
			end
		    }
		    raise exception
		end
	    end


	    ##
	    ## TCP only client
	    ##  (support multiple DNS servers)
	    ##
	    class TCP < Client
		def initialize(config=Config::Default)
		    super(config)
		    @requester = config.nameserver.collect { |ns|
			NResolv::DNS::Requester::TCP::new(ns) }
		end

		def close
		    @requester.each { |r| r.close }
		end

		def query(msg)
		    # XXX: should be able to receive multiple envelops
		    exception = nil
		    @requester.each { |r|
			begin
			    nmsg = r.query(msg).send.wait
			    if nmsg.tc
				Dbg.msg(DBG::RESOLVER,
					'truncated message impossible in TCP')

			    end
			    return nmsg
			rescue NResolv::TimeoutError, 
			       NResolv::NetworkError => exception
			end
		    }
		    raise exception
		end
	    end


	    ##
	    ## UDP with TCP fallback client
	    ##  (support multiple DNS servers)
	    ##
	    class STD < Client
		def initialize(config=Config::Default)
		    super(config)
		    @requester = config.nameserver.collect { |ns|
			[ NResolv::DNS::Requester::UDP::new(ns),
			  NResolv::DNS::Requester::TCP::new(ns) ] }
		end

		def close
		    @requester.each { |udp, tcp| udp.close ; tcp.close }
		end

		def query(msg)
		    exception = nil
		    @requester.each { |udp, tcp|
			begin
			    nmsg = udp.query(msg).send.wait
			    if nmsg.tc
				Dbg.msg(DBG::RESOLVER, 'falling back to TCP')
				nmsg = tcp.query(msg).send.wait
				if nmsg.tc
				    Dbg.msg(DBG::RESOLVER,
					 'truncated message impossible in TCP')
				end
			    end
			    return nmsg
			rescue NResolv::TimeoutError, 
			       NResolv::NetworkError => exception
			end
		    }
		    raise exception
		end
	    end
	end

	DefaultResolver = Client::STD::new
    end
end
