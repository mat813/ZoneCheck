# $Id$

require 'socket'

class Address
    ##
    ##
    ##
    class IPv4 < Address
	Proto = Socket::AF_INET

	Regex = /\A(\d+)\.(\d+)\.(\d+)\.(\d+)\z/
	
	def self.is_valid(str)
	    str =~ Regex
	end

	def self.create(arg)
	    case arg
	    when IPv4
		return arg
	    when Regex
		if (0..255) === (a = $1.to_i) &&
		   (0..255) === (b = $2.to_i) &&
		   (0..255) === (c = $3.to_i) &&
		   (0..255) === (d = $4.to_i)
		    return self.new([a, b, c, d].pack("CCCC").untaint)
		else
		    raise InvalidAddress, 
			"IPv4 address with invalid value: #{arg}"
		end
	    else
		raise InvalidAddress, 
		    "can't interprete as IPv4 address: #{arg.inspect}"
	    end
	end
	
	def initialize(address)
	    unless address.kind_of?(String) && address.length == 4
		raise InvalidAddress, "IPv4 address must be 4 bytes"
	    end
	    @address = address
	end
	
	def private?
	    # 10.0.0.0        -   10.255.255.255  (10/8 prefix)
	    # 172.16.0.0      -   172.31.255.255  (172.16/12 prefix)
	    # 192.168.0.0     -   192.168.255.255 (192.168/16 prefix)
	    bytes = @address.unpack("CCCC")
	    return (((bytes[0] == 10))                            ||
		    ((bytes[0] == 172) && (bytes[1]&0xf0 == 16))  ||
		    ((bytes[0] == 192) && (bytes[1] == 168)))
	end

	def prefix(size=nil)
	    if size.nil?
		# TODO
		raise RuntimeError, "Not Implemented Yet"
	    else
		if size > @address.size * 8
		    raise ArgumentError, "prefix size too big"
		end
		bytes, bits_shift = size / 8, 8 - (size % 8)
		address = @address.slice(0, bytes) + 
		    ("\0" * (@address.size - bytes))
		address[bytes] = (@address[bytes] >> bits_shift) << bits_shift
		IPv4::new(address)
	    end
	end

	def to_s
	    return sprintf("%d.%d.%d.%d", *@address.unpack("CCCC"))
	end
	
	def inspect
	    return "#<#{self.class} #{self.to_s}>"
	end
	
	def to_name
	    return '%d.%d.%d.%d.in-addr.arpa.' % 
		@address.unpack('CCCC').reverse
	end

	def protocol
	    Socket::AF_INET
	end

	Loopback = IPv4::create("127.0.0.1")
    end
end
