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
    class DNS
	class Resource
	    module Generic
		class CNAME
		    def self.wire_decode(decoder)
			self::new(Name::wire_decode(decoder))
		    end
		end

		class NS
		    def self.wire_decode(decoder)
			self::new(Name::wire_decode(decoder))
		    end
		end

		class SOA
		    def self.wire_decode(decoder)
			mname = Name::wire_decode(decoder)
			rname = Name::wire_decode(decoder)
			ser, ref, ret, exp, min = *decoder.unpack("NNNNN")
			self::new(mname, rname, ser, ref, ret, exp, min)
		    end
		end

		class MX
		    def self.wire_decode(decoder)
			self::new(decoder.unpack("n"),
				  Name::wire_decode(decoder))
		    end
		end

		class PTR
		    def self.wire_decode(decoder)
			self::new(Name::wire_decode(decoder))
		    end
		end
	    end

	    module IN
		class A
		    def self.wire_decode(decoder)
			self::new(Address::IPv4::new(decoder.get_bytes(4)))
		    end
		end

		class AAAA
		    def self.wire_decode(decoder)
			self::new(Address::IPv6::new(decoder.get_bytes(16)))
		    end
		end
	    end
	end

	class Name
	    class Label
		def wire_encode(encoder)
		    encoder.put_string(@string)
		end

		def self.wire_decode(decoder) 
		    Ordinary::new(decoder.get_string)
		end
	    end

	    def self.wire_decode(decoder)
		start_idx = decoder.index
		d = []

		while true
		    case decoder.look("C")[0]
		    when 0
			d << Label::wire_decode(decoder)
			return self::new(d)
		    when 192..255
			idx = decoder.unpack('n')[0] & 0x3fff
			if start_idx <= idx
			    raise Message::DecodeError, "foreward name pointer"
			end
			
			origin = decoder.inside(start_idx - idx, idx) {
			    self.wire_decode(decoder)
			}
			return self::new(d, origin)
		    else
			d << Label::wire_decode(decoder)
		    end
		end
		# NOT REACHED
	    end
	    
	    
	    def wire_encode(encoder)
		if encoder.global14
		    @labels.each_index { |i|
			domain = @labels[i..-1]
			if idx = encoder.global14[domain]
			    encoder << [0xc000 | idx].pack("n")
			    return
			else
			    encoder.global14[domain] = encoder.data.length
			    @labels[i].wire_encode(encoder)
			end
		    }
		else
		    @labels.each { |lbl| lbl.wire_encode(encoder) }
		end
	    end
	end
	
	class Message
	    class Encoder
		attr_reader :data, :global14

		def initialize
		    @data = ""
		    @global14 = { }
		end
		
		def <<(obj)
		    @data << obj
		    self
		end
		
		def put_string(str)
		    @data << [str.length].pack("C") << str
		end

		def pack(template, *d)
		    @data << d.pack(template)
		    self
		end
	    end

	    class Decoder
		attr_reader :data, :index, :global14

		def initialize(data)
		    @data  = data
		    @limit = data.length
		    @index = 0
		end

		def look(template)
		    unpack(template, true)
		end

		def get_bytes(len)
		    d = @data[@index, len]
		    @index += len
		    return d
		end

		def get_string
		    len = @data[@index]
		    raise DecodeError, "limit exceeded" if @limit<@index+1+len
		    index, @index = @index, @index + 1 + len
		    @data[index + 1, len]
		end

		def inside(size, offset=nil)
		    begin
			saved_offset = @index
			saved_limit  = @limit

			@index = offset if offset

			if @limit < @index + size
			    raise DecodeError, "limit exceeded" 
			end
			
			saved_offset += size unless offset

			@limit = @index + size
			return yield
		    ensure
			@limit = saved_limit
			@index = saved_offset
		    end
		end

		def unpack(template, lookonly=false)
		    len = 0
		    template.each_byte {|byte|
			len += case byte
			       when ?c, ?C then 1
			       when ?n     then 2
			       when ?N     then 4
			       else
				   raise StandardError, "unsupported template"
			       end
		    }
		    raise DecodeError, "limit exceeded" if @limit < @index+len
		    if lookonly
			index = @index
		    else
			index, @index = @index, @index + len
		    end
		    @data.unpack("@#{index}#{template}") # XXX: segfault
		end
	    end

	    def self.from_wire(data)
		decoder = Decoder::new(data)
		id, flags                          = decoder.unpack("nn")
		qdcount, ancount, nscount, arcount = decoder.unpack("nnnn")

		msg = Message::Answer::new(id)
		msg.qr         = ((flags >> 15) & 1) == 1
		msg.opcode     = OpCode::fetch_by_value((flags >> 11) & 15)
		msg.aa         = ((flags >> 10) & 1) == 1
		msg.tc         = ((flags >>  9) & 1) == 1
		msg.rd         = ((flags >>  8) & 1) == 1
		msg.ra         = ((flags >>  7) & 1) == 1
		msg.rcode      = RCode::fetch_by_value(flags & 15)
		msg.question   = Section::Q::wire_decode(decoder, qdcount)
		msg.answer     = Section::A::wire_decode(decoder, ancount)
		msg.authority  = Section::A::wire_decode(decoder, nscount)
		msg.additional = Section::A::wire_decode(decoder, arcount)
		msg
	    end


	    def to_wire
		encoder = Encoder::new
		encoder << [ @msgid ].pack("n")
		encoder << [ (@qr ? 1 : 0)   << 15 |
		             (@opcode.value) << 11 |
		             (@aa ? 1 : 0)   << 10 |
		             (@tc ? 1 : 0)   <<  9 |
		             (@rd ? 1 : 0)   <<  8 |
		             (@ra ? 1 : 0)   <<  7 |
		             (@rcode.value) ].pack("n")
		encoder << [ @question   ? @question  .length : 0, 
		             @answer     ? @answer    .length : 0,
		             @authority  ? @authority .length : 0, 
			     @additional ? @additional.length : 0].pack("nnnn")
		@question  .wire_encode(encoder) if @question
		@answer    .wire_encode(encoder) if @answer
		@authority .wire_encode(encoder) if @authority
		@additional.wire_encode(encoder) if @additional
		encoder.data
	    end
	end

	class Section
	    class A
		def self.wire_decode(decoder, count)
		    asection = self::new
		    
		    (1..count).each {
			name = Name::wire_decode(decoder)
			t, c = decoder.unpack("nn")
			ttl  = decoder.unpack("N")[0]
			res  = Resource.fetch_class(RClass.fetch_by_value(c),
						    RType .fetch_by_value(t))
			rr = decoder.inside(decoder.unpack("n")[0]) {
			    res::wire_decode(decoder)
			}
			
			asection.add(name, rr, ttl)
		    }
		    asection
		end
	    end

	    class Q
		def self.wire_decode(decoder, count)
		    qsection = self::new
		    
		    (1..count).each {
			name = Name::wire_decode(decoder)
			t, c = decoder.unpack("nn")
			res  = Resource.fetch_class(RClass.fetch_by_value(c),
						    RType .fetch_by_value(t))
			qsection.add(name, res)
		    }
		    qsection
		end
		
		def wire_encode(encoder)
		    @record.each { | name, rd_class|
			name.wire_encode(encoder)
			encoder << [ rd_class.rtype.value,
			    rd_class.rclass.value ].pack("nn")
		    }
		end
	    end
	end
    end
end

