# $Id$

# 
# AUTHOR : Stephane D'Alu <sdalu@nic.fr>
# CREATED: 2002/08/02 13:58:17
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


#
# Add a dig-like formated output
#

class NResolv
    class DNS
	def self.dump_comment(output=$stdout, comment=nil, tag=";; ")
	    if comment
		comment.split(/\n/, -1).each { |line|
		    line.gsub!(/\s+$/, "")
		    output << "#{tag}#{line}\n"
		}
	    end
	end

	class Resource
	    def to_dig
		"#{rclass}\t#{rtype}\t" + _fields.collect { |name, value|
		    value.to_s }.join(" ")
	    end

	    module Generic
		class SOA
		    def to_dig
			"#{rclass}\t#{rtype}\t#{@mname} #{@rname} (#{@serial} #{@refresh} #{@retry} #{@expire} #{@minimum})"
		    end
		end
	    end
	end

	class Message
	    # dump the message content (with a format like +dig+) into 
	    # the stream _output_, by default +STDOUT+ is used
	    def dump(output=$stdout)
		# Print header
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

		DNS::dump_comment(output, hdr1)
		DNS::dump_comment(output, hdr2)
		DNS::dump_comment(output, hdr3)
		DNS::dump_comment(output, "")
		
		# Print section content
		[ [ @question,   "QUESTION SECTION:"   ],
		  [ @answer,     "ANSWER SECTION:"     ],
		  [ @authority,  "AUTHORITY SECTION:"  ],
		  [ @additional, "ADDITIONAL SECTION:" ] ].each { |sec, title|
		    next if sec.nil? || sec.empty?
		    sec.dump(output, title)
		    output << "\n"
		}
	    end
	end

	class Section
	    def dump(output=$stdout, comment=nil, align=29)
		DNS.dump_comment(output, comment)
		prevname = nil
		each { |entry|
		    name     = entry[0]
		    dispname = prevname == name ? nil : name
		    prevname = name
		    output << entry_to_dig_s(entry, align)
		}
	    end

	    class A
		private
		def entry_to_dig_s(entry, align)
		    name, rr, ttl = entry
		    "%-*s  %6d  %-*s  %-*s  %s\n" % [
			align-7, name,
			ttl,
			rr.rclass.class.maxlen, rr.rclass,
			rr.rtype.class.maxlen,  rr.rtype,
			rr.respond_to?(:to_dig) ? rr.to_dig : rr.to_s ]
		end
	    end
	
	    class Q
		private
		def entry_to_dig_s(entry, align)
		    name, rr = entry
		    ";%-*s  %-*s  %-*s\n" % [
			align, name,
			rr::rclass.class.maxlen, rr::rclass,
			rr::rtype.class.maxlen,  rr::rtype ]
		end
	    end
	end
    end
end
