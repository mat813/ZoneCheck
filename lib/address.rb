# $Id$

require 'address/ipv4'
require 'address/ipv6'

class Address
    OrderStrict        = [ Address::IPv4, Address::IPv6 ]
    OrderCompatibility = [ Address::IPv6::Compatibility ]
    OrderIPv6Only      = [ Address::IPv6 ]
    OrderIPv4Only      = [ Address::IPv4 ]
    OrderDefault       = OrderStrict

    def self.is_valid(addr)
	case addr
	when Address::IPv4::Regex, Address::IPv6::Regex then true
	else false
	end
    end

    class InvalidAddress < ArgumentError
    end

    attr_reader :address

    def self.create(arg, order=OrderDefault)
	order.each { |klass|
	    begin
		return klass::create(arg)
	    rescue InvalidAddress
	    end
	}
	raise InvalidAddress, "can't interpret as address: #{arg.inspect}"
    end

    def eql?(other)
	@address == other.address
    end
    alias == eql?
    
    def hash
	@address.hash
    end
end


