# $Id$

# 
# AUTHOR : Stephane D'Alu <sdalu@nic.fr>
# CREATED: 2002/08/26 21:58:17
#
# $Revivion$ 
# $Date$
#
# CONTRIBUTORS:
#
#


require 'socket'
require 'thread'
require 'fcntl'
require 'timeout'

#
# requester = Requester::ConnectedUDP::new(address)
# query     = requester.query(msg)
# reply     = query.send.wait
#

module NResolv
    ##
    ## Timeout Errors
    ##
    class NResolvTimeout < StandardError
    end

    class DNS
	Port		 = 53
	DNSThreadGroup = ThreadGroup::new

	TCPTimeout	 = 5
        UDPRetrySequence = [ 5, 10, 20, 40 ]
	UDPSize		 = 512

	##
	##
	##
	class Requester
	    attr_reader :sock

	    def initialize
                @queries = {}
            end
            
            def delete(id)
                @queries.delete(id)
            end
	    
	    def query(msg)
		unless msg.type == Message::Query
		    raise RuntimeError, "DNS message should be a query"
		end
		@queries[msg.msgid] = create_query(msg)
	    end

	    def receive(data)
		begin
		    msg = Message::from_wire(data)
		    if q = @queries[msg.msgid]
			q.recv msg
		    else
			STDERR.print("non-handled DNS message id=#{msg.msgid}")
		    end
		rescue Message::DecodeError
		   STDERR.print("DNS message decoding error: #{reply.inspect}")
		end
	    end

	    # close the requester and all the pending queries
            def close
                thread, sock, @thread, @sock = @thread, @sock
                begin
                    if thread
                        thread.kill
                        thread.join
                    end
                ensure
		    if sock
			@queries.each { |id, query| query.close }
			sock.close
		    end
                end
            end
            

            class Query
		attr_reader :msgid

		# two queries are identical if they have the same message id.
		def eql?(other)
		    (self.type == other.type) && (self.msgid == other.msgid)
		end
		alias eql? ==
		    
		# return a hash value
		def hash
		    msgid.hash
		end

		# wait for an answer or a timeout (_NResolvTimeout_ exception).
		#
		# The timeout value can be specified by _tout_, if its
		# +nil+ a sensible default value is used.
		def wait(tout=nil)
		    tout = @dflttout if tout.nil?
		    begin
			timeout(tout) { return @queue.pop }
		    rescue TimeoutError
			raise NResolvTimeout
		    ensure
			close
		    end
		end

		# receive an answer message
		def recv(msg)
		    close
		    @queue.push(msg)
		end

		# close the query
		def close
		    @requester.delete(self)
		end

           end



	    ##
            ##
            ##
            class TCP < Requester
                def initialize(host, port=Port)
                    super()
                    @host = host
                    @port = port
                    @sock = TCPSocket.new(host, port)
                    @sock.fcntl(Fcntl::F_SETFD, 1)
                    @thread = Thread.new {
                        DNSThreadGroup.add Thread.current
                        loop {
			    lenhdr = @sock.read(2)
			    len    = lenhdr.unpack('n')[0]
			    reply  = @sock.read(len)
			    receive(reply)
                        }
                    }
                end
                
		def create_query(msg)
		    Query::new(msg, self)
		end

		private
                class Query < Requester::Query
                    def initialize(msg, requester)
			@requester = requester
 			@queue     = Queue::new
                        @rawmsg    = msg.to_wire
			@msgid     = msg.msgid
			@pktlen    = [@rawmsg.length].pack('n')
                        @sock      = requester.sock
			@dflttout  = 5
                    end
                    
                    def send
			@sock.write(@pktlen)
                        @sock.write(@rawmsg)
                        @sock.flush
                        self
                    end
                end
            end
            
        

            ##
	    ##
            ##
            class ConnectedUDP < Requester
                def initialize(host, port=Port)
                    super()
                    @host   = host
                    @port   = port
                    @sock   = UDPSocket::new
                    @sock.connect(host, port)
                    @sock.fcntl(Fcntl::F_SETFD, 1)
                    @thread = Thread::new {
                        DNSThreadGroup.add Thread.current
                        loop {
			    reply = @sock.recv(UDPSize)
			    receive(reply)
                        }
                    }
                end
                
                def create_query(msg)
                    Query::new(msg, self)
                end

                class Query < Requester::Query
                    def initialize(msg, requester)
			@requester = requester
			@queue     = Queue::new
                        @rawmsg    = msg.to_wire
 			@msgid     = msg.msgid
                        @sock      = requester.sock
			@dflttout  = 2
			UDPRetrySequence.each { |tout| @dflttout += tout }
                    end

                    def send
                        @thread = Thread::new {
			    DNSThreadGroup.add Thread.current
			    @sock.write(@rawmsg)
                            UDPRetrySequence.each { |timeout|
                                sleep timeout
                                @sock.write(@rawmsg)
                            }
                        }
                        self
                    end

		    def close
			thread, @thread = @thread
			if thread
			    thread.kill
			end
			super()
		    end
                end
            end
	end
    end
end
