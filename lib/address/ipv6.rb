# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/07/19 07:28:13
#
# COPYRIGHT: AFNIC (c) 2003
# LICENSE  : RUBY
# CONTACT  : 
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

require 'socket'
require 'address/common'
require 'address/ipv4'


class Address
    ##
    ## IPv6 address
    ##
    class IPv6 < Address
	private
	Regex_8Hex = /\A
            (?:[0-9A-Fa-f]{1,4}:){7}
	    [0-9A-Fa-f]{1,4}
            \z/x
	
	Regex_CompressedHex = /\A
            ((?:[0-9A-Fa-f]{1,4}(?::[0-9A-Fa-f]{1,4})*)?) ::
            ((?:[0-9A-Fa-f]{1,4}(?::[0-9A-Fa-f]{1,4})*)?)
            \z/x
	
	Regex_6Hex4Dec = /\A
            ((?:[0-9A-Fa-f]{1,4}:){6,6})
            (\d+)\.(\d+)\.(\d+)\.(\d+)
            \z/x
	
	Regex_CompressedHex4Dec = /\A
            ((?:[0-9A-Fa-f]{1,4}(?::[0-9A-Fa-f]{1,4})*)?) ::
            ((?:[0-9A-Fa-f]{1,4}:)*)
            (\d+)\.(\d+)\.(\d+)\.(\d+)
            \z/x

	Regex_4Dec = /\A
            (\d+)\.(\d+)\.(\d+)\.(\d+)
            \z/x

	public
	IPv6Regex = /
            (?:#{Regex_8Hex.source})              |
            (?:#{Regex_CompressedHex.source})     |
            (?:#{Regex_6Hex4Dec.source})          |
            (?:#{Regex_CompressedHex4Dec.source})
            /x

	IPv6StrictRegex = /
            (?:#{Regex_8Hex.source})              |
            (?:#{Regex_CompressedHex.source})
            /x

	IPv6LooseRegex = /
            (?:#{Regex_8Hex.source})              |
            (?:#{Regex_CompressedHex.source})     |
            (?:#{Regex_6Hex4Dec.source})          |
            (?:#{Regex_CompressedHex4Dec.source}) |
            (?:#{Regex_4Dec.source})
            /x
	
	Regex = IPv6Regex



	def self.hex_pack(str, data="")
	    str.scan(/[0-9A-Fa-f]+/) { |hex| data << [hex.hex].pack('n') }
	    data
	end

	def self.is_valid(str, opt=Regex)
	    str =~ opt
	end

	def self.create(arg, opt=Regex)
	    case arg
	    when IPv6
		return arg
	    when IPv4
		return self.create("::ffff:#{arg.to_s}")
	    when String
		address = ''

		# According to the option, select the test that
		# should be performed
		test = if    opt == IPv6StrictRegex then 1
		       elsif opt == IPv6Regex       then 2
		       elsif opt == IPv6LooseRegex  then 3
		       else  raise ArgumentError, "unknown option"
		       end

		# Test: a:b:c:d:e:f:g:h
		if    (test >= 1) && Regex_8Hex             =~ arg
		    hex_pack(arg, address)

		# Test: a:b:c::d:e:f
		elsif (test >= 1) && Regex_CompressedHex    =~ arg
		    prefix, suffix = $1, $2
		    a1 = hex_pack(prefix)
		    a2 = hex_pack(suffix)
		    omitlen = 16 - a1.length - a2.length
		    address << a1 << "\0" * omitlen << a2

		# Test: a:b:c:d:e:f:g.h.i.j
		elsif (test >= 2) && Regex_6Hex4Dec =~ arg
		    prefix, a, b, c, d = $1, $2.to_i, $3.to_i, $4.to_i, $5.to_i
		    if (0..255) === a && (0..255) === b && 
		       (0..255) === c && (0..255) === d
			hex_pack(prefix, address)
			address << [a, b, c, d].pack('CCCC')
		    end

		# Test: a::b:c:d.e.f.g
		elsif (test >= 2) && Regex_CompressedHex4Dec =~ arg
		    prefix, suffix, a, b, c, d = $1, $2, $3.to_i, $4.to_i, $5.to_i, $6.to_i
		    if (0..255) === a && (0..255) === b && 
		       (0..255) === c && (0..255) === d
			a1 = hex_pack(prefix)
			a2 = hex_pack(suffix)
			omitlen = 12 - a1.length - a2.length
			address << a1 << "\0" * omitlen << a2 << [a, b, c, d].pack('CCCC')
		    end

		# Test: a.b.c.d
		elsif (test >= 3) && Regex_4Dec              =~ arg
		    a, b, c, d = $1.to_i, $2.to_i, $3.to_i, $4.to_i
		    if (0..255) === a && (0..255) === b && 
		       (0..255) === c && (0..255) === d
			address << "\0" * 10 << "\377" * 2 << [a, b, c, d].pack('CCCC')
		    end
		end

		# Check if conversion succed
		if address.length != 16
		    raise InvalidAddress, 
			"IPv6 address with invalid value: #{arg}"
		end

		# Return new address
		return IPv6::new(address.untaint.freeze)
	    else
		raise InvalidAddress,
		    "can't interprete as IPv6 address: #{arg.inspect}"
	    end
	end
	
	def initialize(address)
	    unless (address.instance_of?(String) && 
		    address.length == 16 && address.frozen?)
		raise Argument,
		    "IPv6 raw address must be a 16 byte frozen string"
	    end
	    @address = address
	    freeze
	end
	
	def private?
	    return false
	end

	def prefix(size=nil)
	    if size.nil?
		prefix(64)
	    else
		if size > @address.size * 8
		    raise ArgumentError, "prefix size too big"
		end
		bytes, bits_shift = size / 8, 8 - (size % 8)
		address = @address.slice(0, bytes) + 
		    ("\0" * (@address.size - bytes))
		address[bytes] = (@address[bytes] >> bits_shift) << bits_shift
		IPv6::new(address.freeze)
	    end
	end

	def to_s
	    address = "%X:%X:%X:%X:%X:%X:%X:%X" % @address.unpack("nnnnnnnn")
	    unless address.sub!(/(^|:)0(:0)+(:|$)/, '::')
		address.sub!(/(^|:)0(:|$)/, '::')
	    end
	    address
	end
	
	def to_name
	    (@address.unpack("H32")[0].split(//).reverse + 
	     ['ip6', 'arpa', '']).join(".")
	end

	def protocol
	    Socket::AF_INET6
	end


	##
	## IPv6 address
	##  (allow creation of IPv4 mapped address by default)
	##
	class Compatibility < IPv6
	    def self.create(arg, opt=IPv6LooseRegex)
		IPv6::create(arg, opt)
	    end
	end

	##
	## IPv6 Loopback
	## 
	Loopback = IPv6::create("::1")
    end
end
