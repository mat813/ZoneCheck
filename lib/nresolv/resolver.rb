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

class NResolv
    class DNS
	class DNSNResolvError < NResolvError
	    attr_reader :mesg
	    def initialize(mesg=nil) ; @mesg = mesg ; end
	    def to_s ; (@mesg.nil? ? self.class : @mesg).to_s ; end
	end

	class NoEntryError  < DNSNResolvError
	end

	class NoDomainError < NoEntryError
	end

	class ReplyError    < DNSNResolvError
	end
    
	##
	## Abstract client class
	##  - support multiple servers
	##  - protocol layer is selected using Requester
	##
	class Client
	    attr_reader :config

	    def initialize(config=DefaultConfig)
		if self.class == Client
		    raise RuntimeError, "#{self.class} is an abstract class"
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
		begin
		    rpl = query(msg)
		rescue NoEntryError
		    raise if exception
		    return
		end
		case rpl.rcode
		when RCode::NOERROR
		when RCode::NXDOMAIN
		    raise NoDomainError, rpl.rcode if exception
		    return
		else
		    raise ReplyError, rpl.rcode
		end

		count = 0
		extract_resource(rpl, name, resource) { |n, r, t|
		    yield [r, t, n, rpl]
		    count += 1
		}

		if exception && (count == 0)
		    raise NoEntryError, "no matching answer"
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
		    msg.answer.each { |n, r, t| 
			if (n == name) && (r.rtype==RType::CNAME)
			    name = r.cname
			    break
			end
		    }
		    msg.answer.each { |n, r, t|
			yield [n, r, t] if (n == name) && (r.class == resource)
		    }
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
		    raise ArgumentError, "DNS name should be abolute"
		end

		# Retrieve addresses in the requested order
		order.each { |o|
		    if o == Address::IPv6::Compatibility
			[ Resource::IN::A, Resource::IN::AAAA ].each { |rt|
			    each_resource(name, rt, true, false) { |r,|
				yield Address::IPv6::create(r.address) }
			}
		    elsif o == Address::IPv6
			each_resource(name, Resource::IN::AAAA, 
				      true, false) { |r,|
			    yield r.address }
		    elsif o == Address::IPv4
			each_resource(name, Resource::IN::A, 
				      true, false) { |r,|
			    yield r.address }
		    end
		}
	    end


	    ##
	    ## UDP only client
	    ##  (support multiple DNS servers)
	    ##
	    ## WARN: this could result dealing later with truncated messages
	    ##
	    class UDP < Client
		def initialize(config=DefaultConfig)
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
					"truncated message due to UDP")
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
		def initialize(config=DefaultConfig)
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
					"truncated message impossible in TCP")

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
		def initialize(config=DefaultConfig)
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
				Dbg.msg(DBG::RESOLVER, "falling back to TCP")
				nmsg = tcp.query(msg).send.wait
				if nmsg.tc
				    Dbg.msg(DBG::RESOLVER,
					 "truncated message impossible in TCP")
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
