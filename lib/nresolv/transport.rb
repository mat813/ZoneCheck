# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/08/26 21:58:17
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


require 'socket'
require 'thread'
require 'sync'
require 'fcntl'
require 'timeout'

require 'nresolv/dns'
require 'nresolv/wire'
require 'nresolv/dbg'

#
# requester = Requester::ConnectedUDP::new(address)
# query     = requester.query(msg)
# reply     = query.send.wait
#


#
# PUBLIC:
#   Requester.new
#   Requester#query(msg)
#   Requester#close
#   Requester#restart
#
# FRIEND (Query)
#   Requester#delete(id)
#   Requester#handler
#
# PROTECTED
#   Requester#dispatch(data)
# A Requester#connect_start
# A Requester#connect_end
# A Requester#create_query(msg)
#


#
# PUBLIC
#   Query#send
#   Query#wait
#   Query#close
#   Query#msgid
#
# FRIEND (Requester)
#   Query.new
#


class NResolv
    ##
    ## Timeout Errors
    ##
    class TimeoutError < NResolvError
    end

    class NetworkError < NResolvError
    end


    class DNS
	Port		 = 53
	TCPTimeout	 = 5
#       UDPRetrySequence = [ 5, 10, 20, 40 ]
	UDPRetrySequence = [ 1, 2, 3, 4 ]
	UDPSize		 = 512

	DNSThreadGroup   = ThreadGroup::new

	##
	##
	##
	class Requester
	    def initialize(host, port, keepconnect=false)
		@host          = host
		@port          = port
		@keepconnect   = keepconnect
                @queries       = {}
		@mutex         = Sync::new
		@closed        = false
		@close_on_exec = if Fcntl.constants.include?("F_SETFD")
				     Proc::new { |fd| 
			                 fd.fcntl(Fcntl::F_SETFD, 1) }
				 else
				     Proc::new { }
				 end
            end
            
	    # Delete a pending query by its _id_
	    #
	    # If no more query are left and the flag _keepconnect_ is set
	    # to +false+ the requester will be closed.
            def delete(id)
		@mutex.synchronize {
		    @queries.delete(id)
		    if (! @keepconnect) && (@queries.length == 0)
			connect_close
		    end
		}
            end
	    
	    # Return an handler for the connections
	    def handler
		@mutex.synchronize {
		    return connect_start
		}
	    end

	    # Create a query from the DNS message _msg_
	    def query(msg)
		unless msg.class == Message::Query
		    raise RuntimeError, "DNS message should be a query"
		end
		query = create_query(msg)
		@mutex.synchronize {
		    raise RuntimeError, "Requester is closed" if @closed
		    @queries[msg.msgid] = query
		}
	    end

	    # Dispatch the data (after decoding) to the waiting query
	    def dispatch(data)
		begin
		    msg = Message::from_wire(data)
		    if q = @queries[msg.msgid]
			q.recv msg
		    else
			Dbg.msg(DBG::TRANSPORT,
				"unhandled message (id=#{msg.msgid})")
		    end
		rescue Message::DecodingError => e
		    Dbg.msg(DBG::TRANSPORT, "Ignoring packet (#{e})")
		rescue Exception => e
		    $stderr.puts "Host: #{@host}"
		    $stderr.puts "Unexpected exception while decoding: #{e}"
		    $stderr.puts e.backtrace.join("\n")
		end
	    end

	    # Close the requester and all the pending queries
            def close
		@mutex.synchronize {
		    @closed = true
		    if @queries.length > 0
			@queries.each { |id, query| query.close }
		    end
		    connect_close
		}
            end
            
	    # Restart the requester if it has been previously closed
	    def restart
		@mutex.synchronize {
		    @closed = false
		}
	    end

	    ##
	    ##
	    ##
            class Query
		attr_reader :msgid

		# two queries are identical if they have the same message id.
		def eql?(other)
		    (self.class == other.class) && (self.msgid == other.msgid)
		end
		alias == eql?
		    
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
		    rescue ::TimeoutError
			raise NResolv::TimeoutError
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
            ## TCP requester
            ##
            class TCP < Requester
                def initialize(host, port=Port, keepconnect=false)
                    super(host, port, keepconnect)
		    @sock        = nil
		    @thread      = nil
		end

		def connect_start
		    return @sock unless @sock.nil?

                    @sock = TCPSocket::new(@host, @port)
		    @close_on_exec.call(@sock)
                    @thread = Thread::new {
                        DNSThreadGroup.add Thread.current
                        loop {
			    lenhdr = @sock.read(2)
			    len    = lenhdr.unpack('n')[0]
			    reply  = @sock.read(len)
			    dispatch(reply)
                        }
                    }
		    @sock
                end

		def connect_close
		    thread, sock, @thread, @sock = @thread, @sock
		    begin
			thread.kill if thread
		    ensure
			sock.close  if sock
		    end
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
			@pktlen    = [@rawmsg.length].pack('n')
			@dflttout  = TCPTimeout
                    end
                    
                    def send
                        sock = @requester.handler
			sock.write(@pktlen)
                        sock.write(@rawmsg)
                        sock.flush
                        self
                    end
                end
            end
            

            ##
	    ## UDP requester
            ##
            class UDP < Requester
                def initialize(host, port=Port, keepconnect=true)
                    super(host, port, keepconnect)
		    @sock = nil
                end
		
		def connect_start
		    return @sock unless @sock.nil?

		    # Dirty hack for finding which protocol to use
		    protocol = @host =~ /:/ ? Socket::AF_INET6 \
		                            : Socket::AF_INET

                    @sock = UDPSocket::new(protocol)
                    @sock.connect(@host, @port)
		    @close_on_exec.call(@sock)
                    @thread = Thread::new {
                        DNSThreadGroup.add Thread.current
                        loop {
			    reply = @sock.recv(UDPSize+1)
			    if ! reply.slice!(UDPSize).nil?
				Dbg.msg(DBG::TRANSPORT,
				   "packet bigger than expected (>#{UDPSize})")
			    end
			    dispatch(reply)
                        }
                    }
		    @sock
		end

		def connect_close
		    thread, sock, @thread, @sock = @thread, @sock
		    begin
			thread.kill if thread
		    ensure
			sock.close  if sock
		    end
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
                        @sock      = requester.handler
			@dflttout  = 2
			UDPRetrySequence.each { |tout| @dflttout += tout }
                    end

                    def send
			sock = @requester.handler
			sock.write(@rawmsg)
                        @thread = Thread::new {
			    DNSThreadGroup.add Thread.current
                            UDPRetrySequence.each { |timeout|
                                sleep timeout
                                sock.write(@rawmsg)
                            }
                        }
                        self
                    end

		    def close
			thread, @thread = @thread
			thread.kill    if thread
			super()
		    end
                end
            end
	end
    end
end
