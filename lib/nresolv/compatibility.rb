# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/07/19 07:28:13
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

class NResolv
    class DNS
	def initialize(config="/etc/resolv.conf")
	    cfg		= Config::from_resolv(config)
	    @client	= Client::STD::new(cfg)
	end

	def close
	    @client.close
	end

	def getaddress(name)
	    @client.getaddress(name)
	end

	def getaddresses(name)
	    @client.getaddresses(name)
	end

	def getname(address)
	    @client.getname(address)
	end

	def getnames(address)
	    @client.getnames(address)
	end
    end
end
