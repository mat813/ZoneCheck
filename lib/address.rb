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

require 'address/common'
require 'address/ipv4'
require 'address/ipv6'


##
## All addresses object are immutables
##
class Address
    #
    # Address detection order (between IPv4/IPv6)
    #
    OrderStrict        = [ Address::IPv4, Address::IPv6 ]
    OrderCompatibility = [ Address::IPv6::Compatibility ]
    OrderIPv6Only      = [ Address::IPv6 ]
    OrderIPv4Only      = [ Address::IPv4 ]
    OrderDefault       = OrderStrict


    # Check if a string as a valid address representation 
    #  and respect the address priority order
    def self.is_valid(addr, order=OrderDefault)
	order.each { |klass|
	    return true if addr =~ klass::Regex }
	false
    end

    # Try to convert a string into any address (and respect the
    #  address priority order)
    def self.create(arg, order=OrderDefault)
	order.each { |klass|
	    begin
		return klass::create(arg)
	    rescue InvalidAddress
	    end
	}
	raise InvalidAddress, "can't interpret #{arg.inspect} as address"
    end
end


