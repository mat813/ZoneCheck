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


module NResolv
    class NResolvError < StandardError
    end

    class DNS
	def self.dump_comment(recv=STDOUT, comment=nil, tag=";; ")
	    if comment
		comment.split('\n', -1).each { |line|
		    recv << "#{tag}#{line.gsub(/\s*$/, "")}\n"
		}
	    end
	end

	class Message
	    class DecodeError < NResolvError
	    end

	    attr_reader :msgid, :opcode

	    @@genid = rand 0xffff
	    def self.generate_id
		begin
		    Thread.exclusive { @@genid = (@@genid + 1) & 0xffff }
		rescue NameError
		    @@genid = (@@genid + 1) & 0xffff
		end
	    end
	    
	    def msgid=(id)
		if id < 0 || id > 0xffff
		    raise ArgumentError, "message id should be in [0..0xffff]"
		end
		@msgid = id
	    end


	    def opcode=(code)
		if code.nil? || code.type != OpCode
		    raise ArgumentError, 
			"expected type NResolv::DNS::OpCode"
		end
		@opcode = code
	    end


	    def initialize(id)
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

		if @question
		    @question.dump  (recv, "QUESTION SECTION:")
		    recv << "\n"
		end
		if @answer     && @answer.length     != 0
		    @answer.dump    (recv, "ANSWER SECTION:")
		    recv << "\n"
		end
		if @authority  && @authority.length  != 0
		    @authority.dump (recv, "AUTHORITY SECTION:")
		    recv << "\n"
		end
		if @additional && @additional.length != 0
		    @additional.dump(recv, "ADDITIONAL SECTION:")
		    recv << "\n"
		end
	    end


	    ## DNS Query message
	    ## 
	    ##
	    class Query < Message
		attr_reader :question
		attr_reader :rd, :cd
		attr_writer :rd, :cd

		def initialize(msgid=nil)
		    super(msgid)
		    @qr       = false
		    @opcode   = OpCode::QUERY
		    @question = QSection::new
		end

		def question=(q)
		    unless q.nil? || q.type == Section::QSection
			raise ArgumentError,
			    "expected type NResolv::DNS::Section::QSection"
		    end
		    @question = q
		end
	    end

	    ##
	    ##
	    ##
	    class Answer < Message
		attr_reader :qr, :aa, :rd, :ra
		attr_reader :rcode, :question, :answer, :authority, :additional
		attr_writer :qr, :aa, :rd, :ra

		def initialize(msgid=nil)
		    super(msgid)
		    @qr         = true
		    @question   = QSection::new
		    @answer     = ASection::new
		    @authority  = ASection::new
		    @additional = ASection::new
		end

		def rcode=(code)
		    if code.nil? || code.type != RCode
			raise ArgumentError, 
			    "expected type NResolv::DNS::RCode"
		    end
		    @rcode = code
		end

		def question=(q)
		    if q.nil? || q.type == Section::QSection
			raise ArgumentError,
			"expected type NResolv::DNS::Section::QSection"
		    end
		    @question = q
		end

		def answer=(a)
		    if a.nil? || a.type == Section::ASection
			raise ArgumentError,
			    "expected type NResolv::DNS::Section::ASection"
		    end
		    @answer = a
		end
		
		def authority=(a)
		    if a.nil? || a.type == Section::ASection
			raise ArgumentError,
			    "expected type NResolv::DNS::Section::ASection"
		    end
		    @authority = a
		end
		
		def additional=(a)
		    if a.nil? || a.type == Section::ASection
			raise ArgumentError,
			"expected type NResolv::DNS::Section::ASection"
		    end
		    @additional = a
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
	    def add(name, rdata, ttl)
		# XXX checking
		@record << [ name, rdata, ttl ]
	    end

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
	
	##
	##
	##
	class QSection < Section
	    def add(name, rdata_class)
		# XXX checking
		@record << [ name, rdata_class ]
	    end

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


require 'nresolv_internal'

