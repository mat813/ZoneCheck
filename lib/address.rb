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
# CONTRIBUTORS:
#
#

require 'address/ipv4'
require 'address/ipv6'


##
##
##
class Address
    OrderStrict        = [ Address::IPv4, Address::IPv6 ]
    OrderCompatibility = [ Address::IPv6::Compatibility ]
    OrderIPv6Only      = [ Address::IPv6 ]
    OrderIPv4Only      = [ Address::IPv4 ]
    OrderDefault       = OrderStrict

    class InvalidAddress < ArgumentError
    end

    attr_reader :address

    def self.is_valid(addr, order=OrderDefault)
	order.each { |klass|
	    return true if addr =~ klass::Regex
	}
	false
    end

    def self.create(arg, order=OrderDefault)
	order.each { |klass|
	    begin
		return klass::create(arg)
	    rescue InvalidAddress
	    end
	}
	raise InvalidAddress, "can't interpret as address: #{arg.inspect}"
    end

    def inspect     ; "#<#{self.class} #{self.to_s}>" ; end
    def hash        ; @address.hash                   ; end
    def eql?(other) ; @address == other.address       ; end
    alias == eql?
end


