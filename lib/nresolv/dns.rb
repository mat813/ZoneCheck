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
# CONTRIBUTORS:
#
#

require 'address'

module NResolv
    class NResolvError < StandardError
    end
end

load 'nresolv/dns_name.rb'
load 'nresolv/dns_resource.rb'
load 'nresolv/dns_message.rb'

