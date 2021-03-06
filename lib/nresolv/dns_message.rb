# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/08/02 13:58:17
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

#
# TODO: add a hash facility to Section
#

class NResolv
    class DNS
	class Message
	    attr_reader :msgid, :opcode

	    # Allow generation of message id
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
		    raise ArgumentError, 'message id should be in [0..0xffff]'
		end
		@msgid = id
	    end


	    def opcode=(code)
		if code.nil? || code.class != OpCode
		    raise ArgumentError, 
			'expected type NResolv::DNS::OpCode'
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
		@rcode					= RCode::NOERROR
		@question				= nil
		@answer = @authority = @additional	= nil
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
		    @question = Section::Q::new
		end

		def question=(q)
		    unless q.nil? || q.class == Section::Q
			raise ArgumentError,
			    'expected type NResolv::DNS::Section::Q'
		    end
		    @question = q
		end
	    end

	    ##
	    ##
	    ##
	    class Answer < Message
		attr_reader :qr, :aa, :rd, :ra, :tc
		attr_reader :rcode, :question, :answer, :authority, :additional
		attr_writer :qr, :aa, :rd, :ra, :tc

		def initialize(msgid=nil)
		    super(msgid)
		    @qr         = true
		    @opcode     = OpCode::QUERY
		    @question   = Section::Q::new
		    @answer     = Section::A::new
		    @authority  = Section::A::new
		    @additional = Section::A::new
		end

		def rcode=(code)
		    # Sanity check
		    unless code.kind_of?(RCode)
			raise ArgumentError, "expecting #{RCode}"
		    end

		    # Initialize
		    @rcode	= code
		end

		def question=(q)
		    # Sanity check
		    unless q.kind_of?(Section::Q)
			raise ArgumentError, "expecting #{Section::Q}"
		    end

		    # Initialize
		    @question	= q
		end

		def answer=(a)
		    # Sanity check
		    unless a.kind_of?(Section::A)
			raise ArgumentError, "expecting #{Section::A}"
		    end

		    # Initialize
		    @answer	= a
		end
		
		def authority=(a)
		    # Sanity check
		    unless a.kind_of?(Section::A)
			raise ArgumentError, "expecting #{Section::A}"

		    end
		    # Initialize
		    @authority	= a
		end
		
		def additional=(a)
		    # Sanity check
		    unless a.kind_of?(Section::A)
			raise ArgumentError, "expecting #{Section::A}"
		    end

		    # Initialize
		    @additional	= a
		end
	    end
	end


	##
	## ABSTRACT
	##
	class Section
	    def initialize
		if self.class == Section
		    raise "#{self.class} is an abstract class"
		end

		@record = []
	    end

	    def length		; @record.length		; end
	    def empty?		; @record.empty?		; end
	    def [](idx)		; @record[idx]			; end
	    def each(&block)	; @record.each &block		; end
	    def reject!(&block)	; @record.reject! &block	; end
	    def sort!		; @record.sort! { |x, y| 
		                    x[0].to_s <=> y[0].to_s }	; end



	    ##
	    ##
	    ##
	    class A < Section
		def add(name, rdata, ttl)
		    # XXX checking
		    @record << [ name, rdata, ttl ]
		end
	    end
	    
	    ##
	    ##
	    ##
	    class Q < Section
		def add(name, rd_class)
		    # XXX checking
		    @record << [ name, rd_class ]
		end
	    end
	end
    end
end

