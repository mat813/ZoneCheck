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


=begin
= nresolv library

== NResolv::DNS::Section ABSTRACTclass
=== methods
--- NResolv::DNS::Section#length
--- NResolv::DNS::Section#each
--- NResolv::DNS::Section#reject!
--- NResolv::DNS::Section#sort!
--- NResolv::DNS::Section#[idx]

== NResolv::DNS::Message ABSTRACT class
=== class methods
--- NResolv::DNS::Message.generate_id
--- NResolv::DNS::Message.from_wire

=== methods
--- NResolv::DNS::Message#dump(recv)
((|recv|)) is the stream receiver
--- NResolv::DNS::Message#is_valid?
--- NResolv::DNS::Message#to_wire(bufsize=512, compress=Compress::None)



=end


require 'nresolv_internal'
require 'socket'
require 'thread'


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
	    attr_reader :msgid

	    @@genid = rand 0xffff
	    def self.generate_id
		Thread.exclusive { @@genid = (@@genid + 1) & 0xffff }
	    end
	    
	    def msgid=(id)
		if id < 0 || id > 0xffff
		    raise ArgumentError, "message id should be in [0..0xffff]"
		end
		@msgid = id
	    end

	    def initialize(id=nil)
		self.msgid = id.nil? ? Message::generate_id : id

		@qr					= nil
		@opcode					= nil
		@aa					= nil
		@tc = @rd = @ra				= nil
		@ad = @cd				= nil # RFC 2535
		@rcode					= nil
		@question				= nil
		@answer = @authority = @additional	= nil
	    end
 
	    def is_valid?
		! @msgid.nil?
	    end

	    def dump(recv=STDOUT)
		hdr1 = "opcode: %-*s  status: %-*s  id: %#06x" % [
		    OpCode::maxstrlen, @opcode,
		    RCode::maxstrlen,  @rcode ? @rcode : RCode::filler("-"),
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

		if @question
		    @question.dump  (recv, "QUESTION SECTION:")
		    recv << "\n"
		end
		if @answer
		    @answer.dump    (recv, "ANSWER SECTION:")
		    recv << "\n"
		end
		if @authority
		    @authority.dump (recv, "AUTHORITY SECTION:")
		    recv << "\n"
		end
		if @additional
		    @additional.dump(recv, "ADDITIONAL SECTION:")
		    recv << "\n"
		end
	    end


	    ##
	    ## 
	    ##
	    class Query < Message
		attr_reader :opcode, :rd, :cd, :question
		attr_writer :opcode, :rd, :cd, :question

		def initialize(msgid=nil)
		    super(msgid)
		    @qr       = false
		    @opcode   = OpCode::QUERY
		    @question = QSection::new
		end

		def is_valid?
		    true
		end
	    end

	    ##
	    ##
	    ##
	    class Answer < Message
		attr_reader :qr, :opcode, :aa, :rd, :ra
		attr_reader :rcode, :question, :answer, :authority, :additional
		attr_writer :qr, :opcode, :aa, :rd, :ra
		attr_writer :rcode, :question, :answer, :authority, :additional

		def initialize
		    super
		    @qr = true
		end

	    end
	end


	##
	## ABSTRACT
	##
	class Section
	    DEFAULT_ALIGNEMENT = 29

	    def initialize
		if self.type == Section
		    raise RuntimeError, "Abstract Class"
		end

		@record = []
	    end

	    def length
		@record.length
	    end

	    def each(&block)
		@record.each &block
		self
	    end

	    def reject!(&block)
		@record.reject! &block
		self
	    end

	    def sort!
		@record.sort! { |x, y|
		    x[0].to_s <=> y[0].to_s
		}
		self
	    end

	    def [](idx) 
		@record[idx]
	    end

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
	end


	##
	##
	##
	class ASection < Section
	    def add(name, ttl, rdata)
		@record << [ name, ttl, rdata ]
	    end

	    private
	    def entry_to_s(entry)
		name, rr, ttl = entry
		"%-*s  %6d  %-*s  %-*s  %s\n" % [
		    DEFAULT_ALIGNEMENT-7, name,
		    ttl,
		    rr.rclass.class.maxstrlen, rr.rclass,
		    rr.rtype.class.maxstrlen,  rr.rtype,
		    rr ]
	    end
	end
	
	##
	##
	##
	class QSection < Section
	    def add(name, rdata_class)
		@record << [ name, rdata_class ]
	    end

	    private
	    def entry_to_s(entry)
		name, rr = entry
		";%-*s  %-*s  %-*s\n" % [
		    DEFAULT_ALIGNEMENT, name,
		    rr::CLASS.class.maxstrlen, rr::CLASS,
		    rr::TYPE.class.maxstrlen,  rr::TYPE ]
	    end
	end
    end
end

