#

require 'nresolv/parsing'
require 'nresolv/transport'
require 'nresolv/config'

module NResolv
    class NoAnswer < NResolvError
    end

    class DNS
	class Client
	    def initialize(config=DefaultConfig)
		@config = config
	    end

	    def each_resource(name, resource, rec=true)
		msg = NResolv::DNS::Message::Query::new
		msg.rd = rec
		msg.question.add(name, resource)
		rpl = query(msg)
		extract_resource(rpl, name, resource) { |n, r, t|
		    yield n, r, t, rpl
		}
	    end


	    def extract_resource(msg, name, resource)
		case resource.rtype 
		when Resource::Type::ANY
		    msg.answer.each { |n, r, t|
			yield n, r, t if n == name
		    }
		when Resource::Type::CNAME
		    msg.answer.each { |n, r, t|
			yield n, r, t if (n == name) && (r.class == resource)
		    }
		else
		    msg.answer.each { |n, r| 
			if (n == name) && (r.rtype==Resource::Type::CNAME)
			    name = Name::new(r.to_s)
			    puts r.to_s
			    break
			end
		    }
		    puts name.to_s(true)
		    msg.answer.each { |n, r, t|
			yield n, r, t if (n == name) && (r.class == resource)
		    }
		end
	    end

	    
	    def resources(name, resource, rec=true)
	    end

	    def addresses(sname)
		dname = Name::new(sname)
		@addr = []
		each_resource(dname, NResolv::DNS::Resource::IN::A) { |n, r, t, m|
		    @addr << r.to_s if r.type == NResolv::DNS::Resource::IN::A
		}
		@addr
	    end


	    class UDP < Client
		def initialize(config=DefaultConfig)
		    super(config)
		    @requester = config.nameserver.collect { |ns|
			NResolv::DNS::Requester::UDP::new(ns)
		    }
		end

		def query(msg)
		    @requester.each { |r|
			begin
			    return r.query(msg).send.wait
			rescue NResolv::TimeoutError, NResolv::NetworkError
			end
		    }
		    raise NResolv::NoAnswer
		end
	    end


	    class TCP < Client
		def initialize(config=DefaultConfig)
		    super(config)
		    @requester = config.nameserver.collect { |ns|
			NResolv::DNS::Requester::TCP::new(ns)
		    }
		end

		def query(msg)
		    @requester.each { |r|
			begin
			    return r.query(msg).send.wait
			rescue NResolv::TimeoutError, NResolv::NetworkError
			end
		    }
		    raise NResolv::NoAnswer
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

		def query(msg)
		    @requester.each { |udp, tcp|
			begin
			    msg = udp.query(msg).send.wait
			    msg = tcp.query(msg).send.wait if msg.tc
			    return msg
			rescue NResolv::TimeoutError, NResolv::NetworkError
			end
		    }
		    raise NResolv::NoAnswer
		end
	    end
	end
    end
end
