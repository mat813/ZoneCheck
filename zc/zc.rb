#!/usr/local/bin/ruby

require 'resolv'

module AFNIC
    class DNS
	class Resource < Resolv::DNS::Resource
	end

	module RCode
	    include Resolv::DNS::RCode
	end

	class Message < Resolv::DNS::Message
	end

	class Requester
	    def initialize
		@senders = {}
	    end
	    
	    def delete(arg)
		case arg
		when Sender
		    @senders.delete_if {|k, s| s == arg }
		when Queue
		    @senders.delete_if {|k, s| s.queue == arg }
		else
		    raise ArgumentError.new("neither Sender or Queue: #{arg}")
		end
	    end

	    class Request
	    end

	    class Sender
		def initialize(data, queue)
		    @data  = data
		    @queue = queue
		end
		attr_reader :queue
		
		def recv(msg)
		    @queue.push([msg, @data])
		end
	    end


	    class ConnectedUDP < Requester
		def initialize(host, port=Resolv::DNS::Port)
		    super()
		    @host = host
		    @port = port
		    @sock = UDPSocket.new
		    @sock.connect(host, port)
		    @sock.fcntl(Fcntl::F_SETFD, 1)
		    @id = -1
		    @thread = Thread.new {
			loop {
			    reply = @sock.recv(Resolv::DNS::UDPSize)
			    msg = begin
				      Message.decode(reply)
				  rescue DecodeError
				      STDERR.print("DNS message decoding error: #{reply.inspect}")
				      next
				  end
			    if s = @senders[msg.id]
				s.recv msg
			    else
				STDERR.print("non-handled DNS message: #{msg.inspect}")
			    end
			}
		    }
		end
		
		def sender(msg, data, queue, host=@host, port=@port)
		    unless host == @host && port == @port
			raise RequestError.new("host/port don't match: #{host}:#{port}")
		    end
		    id = Thread.exclusive { @id = (@id + 1) & 0xffff }
		    request = msg.encode
		    request[0,2] = [id].pack('n')
		    return @senders[id] = Sender.new(request, data, @sock, queue)
		end
		
		class Sender < Requester::Sender
		    def initialize(msg, data, sock, queue)
			super(data, queue)
			@msg  = msg
			@sock = sock
		    end
		    
		    def send
			@sock.send(@msg, 0)
		    end
		end
	    end
	end
	

	def initialize(nameserver)
	    @nameserver = nameserver
            @requester = Requester::ConnectedUDP.new(@nameserver)
	end

	

	def each_resource(name, typeclass, &proc)
	    q = Queue.new
	    begin
		msg    = Message.new
		msg.rd = 1
		msg.add_question(name, typeclass)
		sender = @requester.sender(msg, name, q, @nameserver)
		sender.send
		reply = reply_name = nil
		timeout(5) { reply, reply_name = q.pop }
		case reply.rcode
		when RCode::NoError
		    extract_resources(reply, reply_name, typeclass, &proc)
		    return
		when RCode::NXDomain
			raise Resolv::DNS::Config::NXDomain.new(reply_name)
		else
		    raise Resolv::DNS::Config::OtherResolvError.new(reply_name)
		end
	    ensure
		@requester.delete(q)
	    end
	end

	def extract_resources(msg, name, typeclass)
	    if typeclass < Resource::ANY
		n0 = Resolv::DNS::Name.create(name)
		msg.each_answer {|n, ttl, data|
		    yield data if n0 == n
		}
	    end
	    yielded = false
	    n0 = Resolv::DNS::Name.create(name)
	    msg.each_answer {|n, ttl, data|
		if n0 == n
		    case data
		    when typeclass
			yield data
			yielded = true
		    when Resource::CNAME
			n0 = data.name
		    end
		end
	    }
	    return if yielded
	    msg.each_answer {|n, ttl, data|
		if n0 == n
		    case data
		    when typeclass
			yield data
		    end
        end
	    }
	end

	def getresources(name, typeclass)
	    ret = []
	    each_resource(name, typeclass) {|resource| ret << resource}
	    return ret
	end

	def getaddress(name)
	    each_address(name) {|address| return address}
	    raise ResolvError.new("DNS result has no information for #{name}")
	end
	
	def getaddresses(name)
	    ret = []
	    each_address(name) {|address| ret << address}
	    return ret
	end
	
	def each_address(name)
	    each_resource(name, Resource::IN::A) {|resource| yield resource.address}
	end
	
	def getname(address)
	    each_name(address) {|name| return name}
	    raise ResolvError.new("DNS result has no information for #{address}")
	end
	
	def getnames(address)
	    ret = []
	    each_name(address) {|name| ret << name}
	    return ret
	end
	
    end
end

puts AFNIC::DNS.new("192.134.4.10").getresources("kame220.kame.net", AFNIC::DNS::Resource::IN::ANY).collect { |r| r.address }
