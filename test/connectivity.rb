# ZCTEST 1.0
# $Id$

# 
# AUTHOR : Stephane D'Alu <sdalu@nic.fr>
# CREATED: 2002/08/02 13:58:17
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS:
#
#

#####
#
# WARN:
#   - 'chk_icmp' contains system dependant 'ping' command
#      although -q and -c option seems to be fairly standard,
#      unfortunately 'ping' is not part of POSIX
# 
# OPEN:
#   - 'chk_udp' perhaps used a SOA request instead of a 'server status'
#     in case the tested DNS uses view
#

require 'framework'

module CheckNetworkAddress
    ##
    ## Check nameserver connectivity (ICMP, UDP, TCP)
    ## 
    ## - as request are directly made to the DNS (no CacheManager)
    ##   the tests won't be affected by the transport flags
    ## 
    class Connectivity < Test
	def initialize(*args)
	    super(*args)
	    @ping4_cmd = const("ping4")
	    @ping6_cmd = const("ping6")
	end

	#-- Tests ---------------------------------------------------
	# DESC: Test TCP connectivity with DNS server
	def chk_tcp(ns, ip)
	    # The idea is to open a TCP connection
	    #  if no one is listening          => Errno::ECONNREFUSED
	    #  if there is a firewal (timeout) => Errno::EINVAL
	    sock = nil
	    begin
		sock = TCPSocket::new(ip.to_s, NResolv::DNS::Port)
		true
	    rescue Errno::ECONNREFUSED, Errno::EINVAL
		false
	    ensure
		sock.close unless sock.nil?
	    end
	end

	# DESC: Test UDP connectivity with DNS server
	def chk_udp(ns, ip)
	    # The idea is to send 25 'server status' request in 5 seconds
	    #  if we received one answer within 8 seconds (dont care about 
	    #  its content, although generally 'Not Implemented')
	    #  we consider it sucessful
	    msg        = NResolv::DNS::Message::Query::new
	    msg.opcode = NResolv::DNS::OpCode::STATUS
	    rawmsg     = msg.to_wire
	    sock       = nil
	    thr        = nil
	    begin
		sock = UDPSocket::new(ip.protocol)
		sock.connect(ip.to_s, NResolv::DNS::Port)
		thr = Thread::new {
		    (1..25).each { sock.write(rawmsg) ; sleep(0.2) }
		}
		begin
		    timeout(8) { sock.recv(1) }
		    true
		rescue TimeoutError
		    false
		end
	    ensure
		thr.kill   unless thr.nil?
		sock.close unless sock.nil?
	    end
	end

	# DESC: Test if host is alive (watch for firewall)
	def chk_icmp(ns, ip)
	    ping_cmd = case ip
		       when Address::IPv4 then @ping4_cmd
		       when Address::IPv6 then @ping6_cmd
		       else raise "INTERNAL: Unknown address format"
		       end
	    system(ping_cmd % [ ip.to_s ])
	end
    end
end
