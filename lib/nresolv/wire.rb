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
# This file provide encoding/decoding facilities for the 'wire' format
# with the respective methods:
#  - message component: self.wire_decode, self.wire_encode
#  - message itself   : self.from_wire, to_wire
#

require 'nresolv/dbg'

class NResolv
    class DNS
	##
	## provide encoding/decoding methodes for DNS records
	##
	class Resource
	    module Generic
		class TXT
		    def self.wire_decode(decoder)
			txt = []
			while !decoder.empty?
			    txt << decoder.get_string
			end
			self::new(txt)
		    end
		end

		class CNAME
		    def self.wire_decode(decoder)
			self::new(Name::wire_decode(decoder))
		    end
		end

		class NS
		    def self.wire_decode(decoder)
			self::new(Name::wire_decode(decoder))
		    end
		    def wire_encode(encoder)
			@name.wire_encode(encoder)
		    end
		end

		class SOA
		    def self.wire_decode(decoder)
			mname = Name::wire_decode(decoder)
			rname = Name::wire_decode(decoder)
			ser, ref, ret, exp, min = *decoder.unpack('NNNNN')
			self::new(mname, rname, ser, ref, ret, exp, min)
		    end
		end

		class MX
		    def self.wire_decode(decoder)
			self::new(decoder.unpack('n')[0],
				  Name::wire_decode(decoder))
		    end
		end

		class PTR
		    def self.wire_decode(decoder)
			self::new(Name::wire_decode(decoder))
		    end
		end
		
		class RP
		    def self.wire_decode(decoder)
			self::new(Name::wire_decode(decoder),
				  Name::wire_decode(decoder))
		    end
		end

		class HINFO
		    def self.wire_decode(decoder)
			self::new(decoder.get_string, decoder.get_string)
		    end
		end

		class LOC
		    def self.wire_decode(decoder)
			version, size, horizpre, vertpre, latitude, longitude, altitude = *decoder.unpack('CCCCNNN')
			self::new(version, size, horizpre, vertpre, latitude, longitude, altitude)
		    end
		end
	    end

	    module IN
		class A
		    def self.wire_decode(decoder)
			addr = Address::IPv4::new(decoder.get_bytes(4).freeze)
			self::new(addr)
		    end
		    def wire_encode(encoder)
			encoder.data << address.address
		    end
		end

		class AAAA
		    def self.wire_decode(decoder)
			addr = Address::IPv6::new(decoder.get_bytes(16).freeze)
			self::new(addr)
		    end
		    def wire_encode(encoder)
			encoder.data << address.address
		    end
		end
	    end
	end


	##
	## provide encoding/decoding methodes for DNS name
	##
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
		    case decoder.look('C')[0]
		    when 0
			d << Label::wire_decode(decoder)
			return self::new(d)
		    when 192..255
			idx = decoder.unpack('n')[0] & 0x3fff
			if start_idx <= idx
			    raise Message::DecodingError,
				'foreward name pointer in global14'
			end
			
			origin = decoder.inside(start_idx - idx, idx, false) {
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
			    encoder.pack('n', 0xc000 | idx)
			    return
			else
			    if @labels[i] != Label::Root
				encoder.global14[domain] = encoder.data.length
			    end
			    @labels[i].wire_encode(encoder)
			end
		    }
		else
		    @labels.each { |lbl| lbl.wire_encode(encoder) }
		end
	    end
	end
	
	class Message
	    class EncodingError < NResolvError
	    end
	    
	    class DecodingError < NResolvError
		class NoMoreData < DecodingError
		end
	    end


	    class Encoder
		attr_reader :data, :global14

		def initialize
		    @data	= ''
		    @global14	= { }
		end
		
		def put_string(str)
		    @data << [str.length].pack('C') << str
		end

		def pack(template, *d)
		    @data << self.class::pack(template, *d)
		    self
		end

		def []=(idx, data)
		    @data[idx] = data
		end

		def size
		    @data.size
		end

		def self.pack(template, *d)
		    d.pack(template)
		end
	    end

	    class Decoder
		attr_reader :data, :index, :global14
		attr_reader :msg_can_be_truncated
		attr_writer :msg_can_be_truncated


		def remaining
		    @limit - @index
		end
		
		def initialize(data)
		    @data	= data
		    @limit	= data.length
		    @index	= 0
		    @msg_can_be_truncated	= false
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
		    raise DecodingError::NoMoreData, 'limit exceeded' if @limit<@index+1+len
		    index, @index = @index, @index + 1 + len
		    @data[index + 1, len]
		end

		def empty?
		    @limit == @index
		end

		def skip(size)
		    if @limit < @index + size
			raise DecodingError::NoMoreData, 'limit exceeded' 
		    end
		    @index += size
		end

		def inside(size, offset=nil, junkwarn=true)
		    begin
			saved_offset = @index
			saved_limit  = @limit

			@index = offset if offset

			if @limit < @index + size
			    raise DecodingError::NoMoreData, 'limit exceeded' 
			end
			
			saved_offset += size unless offset

			@limit = @index + size

			rval = yield

			if junkwarn && (@limit != @index)
			    Dbg.msg(DBG::WIRE, "junk #{@limit} / #{@index}")
			end

			return rval
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
			       else raise RuntimeError, 'unsupported template'
			       end
		    }
		    if @limit < @index+len
			raise DecodingError::NoMoreData, 'limit exceeded' 
		    end
		    if lookonly
		    then index = @index
		    else index, @index = @index, @index + len
		    end
		    @data.unpack("@#{index}#{template}")
		end
	    end

	    def self.from_wire(data)
		decoder = Decoder::new(data)
		id, flags                          = decoder.unpack('nn')
		qdcount, ancount, nscount, arcount = decoder.unpack('nnnn')

		msg		= Message::Answer::new(id)
		msg.qr		= ((flags >> 15) & 1) == 1
		msg.opcode	= OpCode::fetch_by_value((flags >> 11) & 15)
		msg.aa		= ((flags >> 10) & 1) == 1
		msg.tc		= ((flags >>  9) & 1) == 1
		msg.rd		= ((flags >>  8) & 1) == 1
		msg.ra		= ((flags >>  7) & 1) == 1
		msg.rcode	= RCode::fetch_by_value(flags & 15)

		decoder.msg_can_be_truncated = msg.tc

		msg.question	= Section::Q::wire_decode(decoder, qdcount)
		msg.answer	= Section::A::wire_decode(decoder, ancount)
		msg.authority	= Section::A::wire_decode(decoder, nscount)
		msg.additional	= Section::A::wire_decode(decoder, arcount)
		msg
	    end


	    def to_wire
		encoder = Encoder::new
		encoder.pack('n', @msgid)
		encoder.pack('n', 
			     (@qr ? 1 : 0)   << 15 |
		             (@opcode.value) << 11 |
		             (@aa ? 1 : 0)   << 10 |
		             (@tc ? 1 : 0)   <<  9 |
		             (@rd ? 1 : 0)   <<  8 |
		             (@ra ? 1 : 0)   <<  7 |
		             (@rcode.value))
		encoder.pack('nnnn',
			     @question   ? @question  .length : 0, 
		             @answer     ? @answer    .length : 0,
		             @authority  ? @authority .length : 0, 
			     @additional ? @additional.length : 0)
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
			begin 
			    # Get information about the record 
			    name  = Name::wire_decode(decoder)
			    t, c  = decoder.unpack('nn')
			    ttl   = decoder.unpack('N')[0]
			    res	  = begin
					rc	= RClass.fetch_by_value(c)
					rt	= RType .fetch_by_value(t)
					Resource.fetch_class(rc, rt)
				    rescue IndexError => e
					nil
				    end
			    rrsize = decoder.unpack('n')[0]

			    # Decode the resource inside the record
			    if res.nil?
				# Don't know how to decode (skip it)
				Dbg.msg(DBG::WIRE, "Skipping record (#{e})")
				decoder.skip(rrsize)
			    else
				# Decode the resource
				#  XXX: recovering gracefully in case of
				#       truncated resource (perhaps not a
				#       good idea)
				begin
				    rr = decoder.inside(rrsize) {
					res::wire_decode(decoder) }
				    asection.add(name, rr, ttl)
				rescue Message::DecodingError::NoMoreData
				    Dbg.msg(DBG::WIRE, 
					    'Skipping record (data missing)')
				end
			    end
			rescue Message::DecodingError::NoMoreData
			    # Nicely handle truncated message
			    # Recover gracessfully if it wasn't expected
			    #  (perhaps not a good idea)
			    if (!decoder.msg_can_be_truncated ||
				 decoder.remaining > 0)
				Dbg.msg(DBG::WIRE, 'Salvaging previous records (unexpected end of data)')
			    end
			    break
			end
		    }

		    asection
		end

		def wire_encode(encoder)
		    @record.each { |name, rdata, ttl|
			name.wire_encode(encoder)
			encoder.pack('nn', 
				     rdata.rtype.value, rdata.rclass.value)
			encoder.pack('N', ttl)
			encoder.data << 'xx'
			toto = encoder.data.length
			rdata.wire_encode(encoder)
			encoder.data[toto-2, 2] = [ encoder.data.length - toto ].pack('n')
		    }
		end
	    end

	    class Q
		def self.wire_decode(decoder, count)
		    qsection = self::new
		    
		    (1..count).each {
			name = Name::wire_decode(decoder)
			t, c = decoder.unpack('nn')
			res  = begin
				   rc	= RClass.fetch_by_value(c)
				   rt	= RType .fetch_by_value(t)
				   Resource.fetch_class(rc, rt)
			       rescue IndexError => e
				   nil
			       end
			if res.nil?
			    # Don't know how to decode (skip it)
			    Dbg.msg(DBG::WIRE, "Skipping query record (#{e})")
			else
			    qsection.add(name, res)
			end
		    }
		    qsection
		end
		
		def wire_encode(encoder)
		    @record.each { | name, rd_class|
			name.wire_encode(encoder)
			encoder.pack('nn', 
				     rd_class.rtype.value,
				     rd_class.rclass.value)
		    }
		end
	    end
	end
    end
end

