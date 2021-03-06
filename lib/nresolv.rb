# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/08/02 13:58:17
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

require 'nresolv/constants'
require 'nresolv/dns'
require 'nresolv/wire'
require 'nresolv/transport'
require 'nresolv/config'
require 'nresolv/resolver'
require 'nresolv/dig_output'
require 'nresolv/compatibility'

require 'address'

class NResolv
    # 
    # Ensure that 'arg' will be an Address or a DNS Name object,
    # raise the ArgumentError exception if conversion failed
    def self.to_addrname(arg)
        case arg
        when Address::IPv4, Address::IPv6, NResolv::DNS::Name
            arg
        when String
            begin
                Address::create(arg)
            rescue Address::InvalidAddress
                unless arg[-1] == ?.
                    $stderr.puts "WARNING: #{arg} is not fully qualified"
                end
                DNS::Name::create(arg)
            end
        else
            raise ArgumentError, "address or DNS Name expected"
        end
    end
end
