# ZCTEST 1.0
# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/08/02 13:58:17
#
# COPYRIGHT: AFNIC (c) 2003
# CONTACT  : zonecheck@nic.fr
# LICENSE  : GPL v2.0 (or MIT/X11-like after agreement)
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS: (see also CREDITS file)
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
# BUGFIX:
#   - chk_udp: recvfrom reject datagram bigger than the requested size
#              instead of copying the beginning
#     using the NResolv::DNS::UDPSize instead of 1 byte
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
	with_msgcat "test/connectivity.%s"

	def initialize(*args)
	    super(*args)
	    @ping4_cmd = const("ping4")
	    @ping6_cmd = const("ping6")
	end

	#-- Checks --------------------------------------------------
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
	    # The idea is to send 25 'query' concerning the domain in 5 seconds
	    #  if we received one answer within 8 seconds (dont care about 
	    #  its content, we consider it sucessful)
	    msg        = NResolv::DNS::Message::Query::new
	    msg.question.add(@domain.name, NResolv::DNS::Resource::IN::ANY)
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
		    timeout(8) { sock.recv(NResolv::DNS::UDPSize) }
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
	    # Build ping command
	    ping_tmpl = case ip
			when Address::IPv4 then @ping4_cmd
			when Address::IPv6 then @ping6_cmd
			else raise "INTERNAL: Unknown address format"
			end
	    ping_cmd = ping_tmpl % [ ip.to_s ]

	    # Do ping
	    system(ping_cmd)
	end
    end
end
