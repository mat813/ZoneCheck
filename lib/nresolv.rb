# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/08/02 13:58:17
#
# COPYRIGHT: AFNIC (c) 2003
# CONTACT  : 
# LICENSE  : GPL v2.0
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

require 'nresolv/constants'
require 'nresolv/dns'
require 'nresolv/wire'
require 'nresolv/transport'
require 'nresolv/config'
require 'nresolv/resolver'
require 'nresolv/dig_output'

require 'address'

module NResolv
    def self.to_nameaddr(arg)
        case arg
        when Address::IPv4, Address::IPv6, NResolv::DNS::Name
            arg
        when String
            begin
                Address::create(arg)
            rescue Address::InvalidAddress
                unless arg[-1] == ?.
                    puts "WARNING: #{arg} is not fully qualified"
                end
                DNS::Name::create(arg)
            end
        else
            raise ArgumentError, "IP or DNS Name expected"
        end
    end
end
