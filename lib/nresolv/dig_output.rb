# $Id$

# 
# AUTHOR : Stephane D'Alu <sdalu@nic.fr>
# CREATED: 2002/08/02 13:58:17
#
# $Revivion$ 
# $Date$
#
# CONTRIBUTORS:
#
#


#
# Add dig like formated output
#

module NResolv
    class DNS
	def self.dump_comment(recv=STDOUT, comment=nil, tag=";; ")
	    if comment
		comment.split('\n', -1).each { |line|
		    recv << "#{tag}#{line.gsub(/\s*$/, "")}\n"
		}
	    end
	end

	class Message
	    # dump the message content (with a format like +dig+) into 
	    # the stream _recv_, by default +STDOUT+ is used
	    def dump(recv=STDOUT)
		hdr1 = "opcode: %-*s  status: %-*s  id: %#06x" % [
		    OpCode::maxlen, @opcode,
		    RCode::maxlen,  @rcode ? @rcode : RCode::filler("-"),
		    @msgid ]
		hdr2 = "flags: %s %s %s %s %s %s %s" % [
		    @qr ? "qr" : "--",
		    @aa ? "aa" : "--",
		    @tc ? "tc" : "--",
		    @rd ? "rd" : "--", @ra ? "ra" : "--",
		    @ad ? "ad" : "--", @cd ? "cd" : "--" ]
		hdr3 = "QUERY: %-2d  ANSWER: %-2d  AUTHORITY: %-2d  ADDITIONAL: %-2d" % [
		    @question.nil?   ? 0 : @question.length,
		    @answer.nil?     ? 0 : @answer.length, 
		    @authority.nil?  ? 0 : @authority.length, 
		    @additional.nil? ? 0 : @additional.length ]

		DNS::dump_comment(recv, hdr1)
		DNS::dump_comment(recv, hdr2)
		DNS::dump_comment(recv, hdr3)
		DNS::dump_comment(recv, "")
		
		[ [ @question,   "QUESTION SECTION:"   ],
		  [ @answer,     "ANSWER SECTION:"     ],
		  [ @authority,  "AUTHORITY SECTION:"  ],
		  [ @additional, "ADDITIONAL SECTION:" ] ].each { |sec, title|
		    if sec && !sec.empty?
			sec.dump(recv, title)
			recv << "\n"
		    end
		}
	    end
	end

	class Section
	    DEFAULT_ALIGNEMENT = 29

	    def dump(recv=STDOUT, comment=nil)
		DNS.dump_comment(recv, comment)
		maxlen = DEFAULT_ALIGNEMENT
		prevname = nil
		each { |entry|
		    name = entry[0]
		    dispname = prevname == name ? nil : name
		    prevname = name

		    recv << entry_to_s([entry[0], *entry[1..-1]])
		}
	    end

	    class A
		private
		def entry_to_s(entry)
		    name, rr, ttl = entry
		    "%-*s  %6d  %-*s  %-*s  %s\n" % [
			DEFAULT_ALIGNEMENT-7, name,
			ttl,
			rr.rclass.class.maxlen, rr.rclass,
			rr.rtype.class.maxlen,  rr.rtype,
			rr ]
		end
	    end
	
	    class Q
		private
		def entry_to_s(entry)
		    name, rr = entry
		    ";%-*s  %-*s  %-*s\n" % [
			DEFAULT_ALIGNEMENT, name,
			rr::rclass.class.maxlen, rr::rclass,
			rr::rtype.class.maxlen,  rr::rtype ]
		end
	    end
	end
    end
end
