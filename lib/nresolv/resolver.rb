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
		msg.question.add(Name::new(name), resource)
		rpl = query(msg)
		rpl.answer.each { |n, r, t|
		    yield n, r, t, rpl
		}
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
