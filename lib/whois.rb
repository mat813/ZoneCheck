# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2003/03/25 11:59:39
#
# COPYRIGHT: AFNIC (c) 2003
# CONTACT  : 
# LICENSE  : RUBY
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS: (see also CREDITS file)
#
#

require 'socket'
require 'address'
require 'nresolv'

class WHOIS
    INETNUM	= "inetnum"
    ROUTE	= "route"

    Port	= 43
    IPV4_MAP	= <<-EOT
INTERNET PROTOCOL V4 ADDRESS SPACE

(last updated 2003-02-12)

The allocation of Internet Protocol version 4 (IPv4) address space to
various registries is listed here. Originally, all the IPv4 address
spaces was managed directly by the IANA. Later parts of the address
space were allocated to various other registries to manage for
particular purposes or regional areas of the world.  RFC 1466 [RFC1466]
documents most of these allocations.

Address
Block   Date     Registry - Purpose                  Notes or Reference
-----   ------   ---------------------------         ------------------
000/8   Sep 81   IANA - Reserved
001/8   Sep 81   IANA - Reserved
002/8   Sep 81   IANA - Reserved
003/8   May 94   General Electric Company
004/8   Dec 92   Bolt Beranek and Newman Inc.
005/8   Jul 95   IANA - Reserved
006/8   Feb 94   Army Information Systems Center
007/8   Apr 95   IANA - Reserved
008/8   Dec 92   Bolt Beranek and Newman Inc.
009/8   Aug 92   IBM
010/8   Jun 95   IANA - Private Use                  See [RFC1918]
011/8   May 93   DoD Intel Information Systems
012/8   Jun 95   AT&T Bell Laboratories
013/8   Sep 91   Xerox Corporation
014/8   Jun 91   IANA - Public Data Network
015/8   Jul 94   Hewlett-Packard Company
016/8   Nov 94   Digital Equipment Corporation
017/8   Jul 92   Apple Computer Inc.
018/8   Jan 94   MIT
019/8   May 95   Ford Motor Company
020/8   Oct 94   Computer Sciences Corporation
021/8   Jul 91   DDN-RVN
022/8   May 93   Defense Information Systems Agency
023/8   Jul 95   IANA - Reserved
024/8   May 01   ARIN - Cable Block                  (Formerly IANA - Jul 95)
025/8   Jan 95   Royal Signals and Radar Establishment
026/8   May 95   Defense Information Systems Agency
027/8   Apr 95   IANA - Reserved
028/8   Jul 92   DSI-North
029/8   Jul 91   Defense Information Systems Agency
030/8   Jul 91   Defense Information Systems Agency
031/8   Apr 99   IANA - Reserved
032/8   Jun 94   Norsk Informasjonsteknology
033/8   Jan 91   DLA Systems Automation Center
034/8   Mar 93   Halliburton Company
035/8   Apr 94   MERIT Computer Network
036/8   Jul 00   IANA - Reserved                     (Formerly Stanford University - Apr 93)
037/8   Apr 95   IANA - Reserved
038/8   Sep 94   Performance Systems International
039/8   Apr 95   IANA - Reserved
040/8   Jun 94   Eli Lily and Company
041/8   May 95   IANA - Reserved
042/8   Jul 95   IANA - Reserved
043/8   Jan 91   Japan Inet
044/8   Jul 92   Amateur Radio Digital Communications
045/8   Jan 95   Interop Show Network
046/8   Dec 92   Bolt Beranek and Newman Inc.
047/8   Jan 91   Bell-Northern Research
048/8   May 95   Prudential Securities Inc.
049/8   May 94   Joint Technical Command             (Returned to IANA  Mar 98)
050/8   May 94   Joint Technical Command             (Returned to IANA  Mar 98)
051/8   Aug 94   Deparment of Social Security of UK
052/8   Dec 91   E.I. duPont de Nemours and Co., Inc.
053/8   Oct 93   Cap Debis CCS
054/8   Mar 92   Merck and Co., Inc.
055/8   Apr 95   Boeing Computer Services
056/8   Jun 94   U.S. Postal Service
057/8   May 95   SITA
058/8   Sep 81   IANA - Reserved
059/8   Sep 81   IANA - Reserved
060/8   Sep 81   IANA - Reserved
061/8   Apr 97   APNIC                               (whois.apnic.net)
062/8   Apr 97   RIPE NCC                            (whois.ripe.net)
063/8   Apr 97   ARIN                                (whois.arin.net)	
064/8   Jul 99   ARIN                                (whois.arin.net) 
065/8   Jul 00   ARIN                                (whois.arin.net)
066/8   Jul 00   ARIN                                (whois.arin.net)
067/8   May 01   ARIN                                (whois.arin.net)
068/8   Jun 01   ARIN                                (whois.arin.net)
069/8   Aug 02   ARIN                                (whois.arin.net)
070/8   Sep 81   IANA - Reserved
071/8   Sep 81   IANA - Reserved
072/8   Sep 81   IANA - Reserved
073/8   Sep 81   IANA - Reserved
074/8   Sep 81   IANA - Reserved
075/8   Sep 81   IANA - Reserved
076/8   Sep 81   IANA - Reserved
077/8   Sep 81   IANA - Reserved
078/8   Sep 81   IANA - Reserved
079/8   Sep 81   IANA - Reserved
080/8   Apr 01   RIPE NCC                            (whois.ripe.net)
081/8   Apr 01   RIPE NCC                            (whois.ripe.net)
082/8   Nov 02   RIPE NCC                            (whois.ripe.net)
083/8   Sep 81   IANA - Reserved
084/8   Sep 81   IANA - Reserved
085/8   Sep 81   IANA - Reserved
086/8   Sep 81   IANA - Reserved
087/8   Sep 81   IANA - Reserved
088/8   Sep 81   IANA - Reserved
089/8   Sep 81   IANA - Reserved
090/8   Sep 81   IANA - Reserved
091/8   Sep 81   IANA - Reserved
092/8   Sep 81   IANA - Reserved
093/8   Sep 81   IANA - Reserved
094/8   Sep 81   IANA - Reserved
095/8   Sep 81   IANA - Reserved
096/8   Sep 81   IANA - Reserved
097/8   Sep 81   IANA - Reserved
098/8   Sep 81   IANA - Reserved
099/8   Sep 81   IANA - Reserved
100/8   Sep 81   IANA - Reserved
101/8   Sep 81   IANA - Reserved
102/8   Sep 81   IANA - Reserved
103/8   Sep 81   IANA - Reserved
104/8   Sep 81   IANA - Reserved
105/8   Sep 81   IANA - Reserved
106/8   Sep 81   IANA - Reserved
107/8   Sep 81   IANA - Reserved
108/8   Sep 81   IANA - Reserved
109/8   Sep 81   IANA - Reserved
110/8   Sep 81   IANA - Reserved
111/8   Sep 81   IANA - Reserved
112/8   Sep 81   IANA - Reserved
113/8   Sep 81   IANA - Reserved
114/8   Sep 81   IANA - Reserved
115/8   Sep 81   IANA - Reserved
116/8   Sep 81   IANA - Reserved
117/8   Sep 81   IANA - Reserved
118/8   Sep 81   IANA - Reserved
119/8   Sep 81   IANA - Reserved
120/8   Sep 81   IANA - Reserved
121/8   Sep 81   IANA - Reserved
122/8   Sep 81   IANA - Reserved
123/8   Sep 81   IANA - Reserved
124/8   Sep 81   IANA - Reserved
125/8   Sep 81   IANA - Reserved
126/8   Sep 81   IANA - Reserved
127/8   Sep 81   IANA - Reserved                     See [RFC3330]
128/8   May 93   Various Registries
129/8   May 93   Various Registries
130/8   May 93   Various Registries
131/8   May 93   Various Registries
132/8   May 93   Various Registries
133/8   May 93   Various Registries
134/8   May 93   Various Registries
135/8   May 93   Various Registries
136/8   May 93   Various Registries
137/8   May 93   Various Registries
138/8   May 93   Various Registries
139/8   May 93   Various Registries
140/8   May 93   Various Registries
141/8   May 93   Various Registries
142/8   May 93   Various Registries
143/8   May 93   Various Registries
144/8   May 93   Various Registries
145/8   May 93   Various Registries
146/8   May 93   Various Registries
147/8   May 93   Various Registries
148/8   May 93   Various Registries
149/8   May 93   Various Registries
150/8   May 93   Various Registries
151/8   May 93   Various Registries
152/8   May 93   Various Registries
153/8   May 93   Various Registries
154/8   May 93   Various Registries
155/8   May 93   Various Registries
156/8   May 93   Various Registries
157/8   May 93   Various Registries
158/8   May 93   Various Registries
159/8   May 93   Various Registries
160/8   May 93   Various Registries
161/8   May 93   Various Registries
162/8   May 93   Various Registries
163/8   May 93   Various Registries
164/8   May 93   Various Registries
165/8   May 93   Various Registries
166/8   May 93   Various Registries
167/8   May 93   Various Registries
168/8   May 93   Various Registries
169/8   May 93   Various Registries
170/8   May 93   Various Registries
171/8   May 93   Various Registries
172/8   May 93   Various Registries
173/8   May 93   Various Registries
174/8   May 93   Various Registries
175/8   May 93   Various Registries
176/8   May 93   Various Registries
177/8   May 93   Various Registries
178/8   May 93   Various Registries
179/8   May 93   Various Registries
180/8   May 93   Various Registries
181/8   May 93   Various Registries
182/8   May 93   Various Registries
183/8   May 93   Various Registries
184/8   May 93   Various Registries
185/8   May 93   Various Registries
186/8   May 93   Various Registries
187/8   May 93   Various Registries
188/8   May 93   Various Registries
189/8   May 93   Various Registries
190/8   May 93   Various Registries
191/8   May 93   Various Registries
192/8   May 93   Various Registries
193/8   May 93   RIPE NCC                            (whois.ripe.net)
194/8   May 93   RIPE NCC                            (whois.ripe.net)
195/8   May 93   RIPE NCC                            (whois.ripe.net)
196/8   May 93   Various Registries
197/8   May 93   IANA - Reserved
198/8   May 93   Various Registries
199/8   May 93   ARIN                                (whois.arin.net)
200/8   Nov 02   LACNIC                              (whois.lacnic.net)
201/8   May 93   Reserved                            (Central and South America)
202/8   May 93   APNIC                               (whois.apnic.net)
203/8   May 93   APNIC                               (whois.apnic.net)
204/8   Mar 94   ARIN                                (whois.arin.net)
205/8   Mar 94   ARIN                                (whois.arin.net)
206/8   Apr 95   ARIN                                (whois.arin.net)
207/8   Nov 95   ARIN                                (whois.arin.net)
208/8   Apr 96   ARIN                                (whois.arin.net)
209/8   Jun 96   ARIN                                (whois.arin.net)
210/8   Jun 96   APNIC                               (whois.apnic.net)
211/8   Jun 96   APNIC                               (whois.apnic.net)
212/8   Oct 97   RIPE NCC                            (whois.ripe.net)
213/8   Mar 99   RIPE NCC                            (whois.ripe.net)
214/8   Mar 98   US-DOD
215/8   Mar 98   US-DOD
216/8   Apr 98   ARIN                                (whois.arin.net)
217/8   Jun 00   RIPE NCC                            (whois.ripe.net)
218/8   Dec 00   APNIC                               (whois.apnic.net)
219/8   Sep 01   APNIC                               (whois.apnic.net)
220/8   Dec 01   APNIC                               (whois.apnic.net)
221/8   Jul 02   APNIC                               (whois.apnic.net)
222/8   Feb 03   APNIC                               (whois.apnic.net)
223/8   Feb 03   APNIC                               (whois.apnic.net)
224/8   Sep 81   IANA - Multicast
225/8   Sep 81   IANA - Multicast
226/8   Sep 81   IANA - Multicast
227/8   Sep 81   IANA - Multicast
228/8   Sep 81   IANA - Multicast
229/8   Sep 81   IANA - Multicast
230/8   Sep 81   IANA - Multicast
231/8   Sep 81   IANA - Multicast
232/8   Sep 81   IANA - Multicast
233/8   Sep 81   IANA - Multicast
234/8   Sep 81   IANA - Multicast
235/8   Sep 81   IANA - Multicast
236/8   Sep 81   IANA - Multicast
237/8   Sep 81   IANA - Multicast
238/8   Sep 81   IANA - Multicast
239/8   Sep 81   IANA - Multicast
240/8   Sep 81   IANA - Reserved
241/8   Sep 81   IANA - Reserved
242/8   Sep 81   IANA - Reserved
243/8   Sep 81   IANA - Reserved
244/8   Sep 81   IANA - Reserved
245/8   Sep 81   IANA - Reserved
246/8   Sep 81   IANA - Reserved
247/8   Sep 81   IANA - Reserved
248/8   Sep 81   IANA - Reserved
249/8   Sep 81   IANA - Reserved
250/8   Sep 81   IANA - Reserved
251/8   Sep 81   IANA - Reserved
252/8   Sep 81   IANA - Reserved
253/8   Sep 81   IANA - Reserved
254/8   Sep 81   IANA - Reserved
255/8   Sep 81   IANA - Reserved

Reference
---------
[RFC1466]

[RFC1918]

[RFC3330]

[]

EOT

     # 
     @@ipv4_8		= {}
     @@all_whois	= []
     IPV4_MAP.split(/\n/).each { |line|
	line =~ /^(\d{3})\/8\s+\w+\s+\d+\s\s+(.*?)\s*$/
	prefix, desc = $1, $2
	if prefix
	    @@ipv4_8[Address::IPv4::create("#{prefix}.0.0.0")] = desc
	    if desc =~ /\((whois\..*?)\)/
		whois = $1
		@@all_whois << whois unless @@all_whois.include?(whois)
	    end
	end
     }



     def self.getservers(obj)
	 case obj
	 when Address::IPv4
	     if ip_info = @@ipv4_8[obj.prefix(8)]
		 return case ip_info
			when /\((whois\..*?)\)/		then [ $1 ]
			when /Various\s+Registries/i	then @@all_whois
			end
	     end
	 when NResolv::DNS::Name
	     if tld = obj.tld
		 return [ tld[0].to_s + ".whois-servers.net" ]
	     end
	 else
	     raise ArgumentError
	 end
	 nil
     end

     def self.getwhois(host)
	 klass = case host
		 when "whois.ripe.net"	then RIR::RIPE
		 when "whois.apnic.net"	then RIR::APNIC
		 when "whois.arin.net"	then RIR::ARIN
		 else return nil
		 end
	 klass::new(host)
     end

     def self.query(name, type)
	 if servers = self.getservers(NResolv::to_name(name))
	     servers.each { |server|
		 if whois = self.getwhois(server)
		     if ans = whois.query(name, type)
			 return ans
		     end
		 end
	     }
	 end
	 nil
     end


     def initialize(host, port=Port)
	 @host = host
	 @port = port
     end

     def rawquery(name)
	 sock = nil
	 data = nil
	 begin
	     sock = TCPSocket::new(@host, @port)
	     sock.write("#{name}\n")
	     data = sock.readlines
	 ensure
	     sock.close unless @sock.nil?
	 end
	 data
     end

     class RIR < WHOIS
	 class LACNIC
	     def query(name, type)
		 case type
		 when INETNUM
		     data = rawquery("#{name}")
		     data.delete_if { |e| e =~ /^%/ }
		     data.collect { |e| e =~ /^\s*$/
		     data
		 else
		     nil
		 end
	     end
	 end

	 class ARIN
	     def query(name, type)
		 case type
		 when INETNUM
		     data = rawquery("-n #{name}")
		     data.delete_if { |e| e =~ /^#/ }
		     data.each { |e| return nil if e =~ /RESERVED-/ }
		     data
		 else
		     nil
		 end
	     end
	 end

	 class APNIC < RIR
	     def query(name, type)
		 case type
		 when INETNUM
		     data = rawquery("-r -T inetnum #{name}")
		     data.delete_if { |e| e =~ /^%/ }
		     data.each { |e| return nil if e =~ /IANA-NETBLOCK-/ }
		    data
		else
		    nil
		end
	    end
	end

	class RIPE < RIR
	    def query(name, type)
		case type
		when INETNUM
		    data = rawquery("-r -T inetnum #{name}")
		    data.delete_if { |e| e =~ /^%/ }
		    data.each { |e| return nil if e =~ /IANA-BLK/ }
		    data
		else
		    nil
		end
	    end
	end
    end

end

puts WHOIS::query("193.49.160.10", WHOIS::INETNUM)
puts "====="
puts WHOIS::query("192.134.4.116", WHOIS::INETNUM)
puts "====="
puts WHOIS::query("217.1.4.116",   WHOIS::INETNUM)

#puts WHOIS::getservers(NResolv::DNS::Name::create("zorg.fr."))

#w = WHOIS::new(WHOIS::getserver(NResolv::DNS::Name::create("zorg.fr.")))
#puts w.query("nic.fr")
