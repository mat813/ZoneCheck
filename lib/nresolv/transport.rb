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

module NResolv
    class DNS
	DNSThreadGroup = ThreadGroup::new

        UDPRetrySequence = [ 5, 10, 20, 40 ]
	UDPSize = 512

	##
	##
	##
	class Requester
	    def initialize
                @queries = {}
            end
            
            def delete(query)
                @queries.delete(query)
            end

            def close
                thread, sock, @thread, @sock = @thread, @sock
                begin
                    if thread
                        thread.kill
                        thread.join
                    end
                ensure
                    sock.close if sock
                end
            end
            

            class Query
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
                    @id = -1
                    @thread = Thread.new {
                        DNSThreadGroup.add Thread.current
                        loop {
                            lenhdr = @sock.read(2)
                            len    = lenhdr.unpack('n')[0]
                            reply  = @sock.read(len)
                            msg = begin
                                      Message.decode(reply)
                                  rescue DecodeError
                                      STDERR.print("DNS message decoding error: #{reply.inspect}")
                                      next
                                  end
                            if q = @queries[msg.id]
                                q.recv msg
                            end
                        }
                    }
                end
                
                def query(msg, data)
                    id = Thread.exclusive { @id = (@id + 1) & 0xffff }
                    packet      = msg.encode
                    packet[0,2] = [packet.length, id].pack('nn')
                    return @queries[id] = Query::new(packet, data, @sock)
                end
                
                class Query < Requester::Query
                    def initialize(msg, data, sock)
                        super(data)
                        @msg = msg
                        @sock = sock
                    end
                    
                    def send
                        @sock.write(@msg)
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
                    @id     = -1
                    @thread = Thread::new {
                        DNSThreadGroup.add Thread.current
                        loop {
                            reply = @sock.recv(UDPSize)
                            msg = begin
                                      Message::from_wire(reply)
                                  rescue DecodeError
                                      STDERR.print("DNS message decoding error: #{reply.inspect}")
                                      next
                                  end
                            if q = @queries[msg.msgid]
                                q.recv msg
                            else
                                STDERR.print("non-handled DNS message: #{msg.msgid}")
                            end
                        }
                    }
                end
                
                def query(msg)
                    return @queries[msg.msgid] = Query::new(msg, @sock)
                end

                class Query < Requester::Query
                    def initialize(msg, sock)
			@queue  = Queue::new
                        @rawmsg = msg.to_wire
                        @sock   = sock
                    end

                    def wait
                        tout = 2
                        UDPRetrySequence.each { |timeout| tout += timeout }
                        timeout(tout) { return @queue.pop }
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

                    def recv(msg)
                        @thread.kill
                        @queue.push(msg)
                    end
                end
            end

	end
    end
end


