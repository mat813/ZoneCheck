# $Id$

require 'nresolv/dns'
require 'nresolv/transport'
require 'nresolv/config'

module NResolv
    class NoEntryError < NResolvError
    end

    class NoDomainError < NoEntryError
    end

    class ReplyError < NResolvError
    end
    
    class RefusedError < NResolvError
    end

    class DNS
	class Client
	    def initialize(config=DefaultConfig)
		@config = config
	    end

	    def getresources(name, resource, rec=true, exception=true)
		ret = [ ]
		each_resource(name, resource, rec, exception) {|resource,| 
		    ret << resource
		}
		return ret
	    end

	    #
	    # yield: resource, ttl, name, msg
	    # exceptions: NoEntryError, NoDomainError, RefusedError
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
		when RCode::REFUSED
		    raise RefusedError, "#{rpl.rcode}"
		when RCode::NXDOMAIN
		    raise NoDomainError, "#{rpl.rcode}" if exception
		    return
		else
		    raise ReplyError, "#{rpl.rcode}"
		end

		count = 0
		extract_resource(rpl, name, resource) { |n, r, t|
		    yield r, t, n, rpl
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
		when RType::ANY
		    msg.answer.each { |n, r, t|
			yield n, r, t if n == name
		    }
		when RType::CNAME
		    msg.answer.each { |n, r, t|
			yield n, r, t if (n == name) && (r.class == resource)
		    }
		else
		    msg.answer.each { |n, r, t| 
			if (n == name) && (r.rtype==RType::CNAME)
			    name = r.cname
			    break
			end
		    }
		    msg.answer.each { |n, r, t|
			yield n, r, t if (n == name) && (r.class == resource)
		    }
		end
	    end

	    
	    def master(domain)
		domain = Name::create(domain)
		each_resource(domain, Resource::IN::SOA) { |r,|
		    return r.mname
		}
	    end
	    alias primary master

	    def nameservers(domain)
		domain = Name::create(domain)
		ns = []
		each_resource(domain, NResolv::DNS::Resource::IN::NS) { |r,|
		    ns << r.name
		}
		ns
	    end

	    def addresses(name, order=Address::OrderDefault)
		name = Name::create(name)
		addr  = []

		order.each { |o|
		    if o == Address::IPv6::Compatibility
			[ Resource::IN::A, Resource::IN::AAAA ].each { |rt|
			    each_resource(name, rt, true, false) { |r,|
				addr << Address::IPv6::create(r.address)
			    }
			}
		    elsif o == Address::IPv6
			begin
			    each_resource(name, Resource::IN::AAAA, 
					  true, false) { |r,|
				addr << r.address
			    }
			end
		    elsif o == Address::IPv4
			begin
			    each_resource(name, Resource::IN::A, 
					  true, false) { |r,|
				addr << r.address
			    }
			end
		    end
		}
		addr
	    end


	    class UDP < Client
		def initialize(config=DefaultConfig)
		    super(config)
		    @requester = config.nameserver.collect { |ns|
			NResolv::DNS::Requester::UDP::new(ns)
		    }
		end

		def close
		    @requester.each { |r| r.close }
		end

		def query(msg)
		    @requester.each { |r|
			begin
			    return r.query(msg).send.wait
			rescue NResolv::TimeoutError, NResolv::NetworkError
			end
		    }
		    raise NResolv::NoEntryError
		end
	    end


	    class TCP < Client
		def initialize(config=DefaultConfig)
		    super(config)
		    @requester = config.nameserver.collect { |ns|
			NResolv::DNS::Requester::TCP::new(ns)
		    }
		end

		def close
		    @requester.each { |r| r.close }
		end

		def query(msg)
		    @requester.each { |r|
			begin
			    return r.query(msg).send.wait
			rescue NResolv::TimeoutError, NResolv::NetworkError
			end
		    }
		    raise NResolv::NoEntryError
		end

	    end

   
	    class Classic < Client
		def initialize(config=DefaultConfig)
		    super(config)
		    @requester = config.nameserver.collect { |ns|
			[ NResolv::DNS::Requester::UDP::new(ns),
			  NResolv::DNS::Requester::TCP::new(ns) ]
		    }
		end

		def close
		    @requester.each { |udp, tcp| udp.close ; tcp.close }
		end

		def query(msg)
		    @requester.each { |udp, tcp|
			begin
			    msg = udp.query(msg).send.wait
			    msg = tcp.query(msg).send.wait if msg.tc
			    return msg
			rescue NResolv::TimeoutError, NResolv::NetworkError
			end
		    }
		    raise NResolv::NoEntryError
		end
	    end
	end

	DefaultResolver = Client::Classic::new
    end
end
