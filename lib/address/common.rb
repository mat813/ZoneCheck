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


##
## Basic definition of an address
##
class Address
    class InvalidAddress < ArgumentError
    end

    attr_reader :address

    def namespace   ; ""                              ; end

    def inspect     ; "#<#{self.class} #{self.to_s}>" ; end
    def hash        ; @address.hash                   ; end
    def eql?(other) ; @address == other.address       ; end
    alias == eql?
end
