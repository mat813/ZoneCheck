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
# CONTRIBUTORS:
#
#

require 'thread'

class NResolv
    class Hosts
	DefaultFileName = '/etc/hosts'

	class HostsResolvError < NResolvError
	end


	def initialize(filename = DefaultFileName)
	    @filename    = filename
	    @mutex       = Mutex.new
	    @initialized = false
	end
	
	def lazy_initialize
	    @mutex.synchronize {
		return if @initialized

		@name2addr = {}
		@addr2name = {}
		open(@filename) {|f|
		    f.each {|line|
			line.sub!(/\#.*/, '')
			addr, host, *aliases = line.split(/\s+/)
			next unless addr
			@addr2name[addr] = [] unless @addr2name.include? addr
			@addr2name[addr] << host
			@addr2name[addr] += aliases
			@name2addr[host] = [] unless @name2addr.include? host
			@name2addr[host] << addr
			aliases.each {|n|
			    @name2addr[n] = [] unless @name2addr.include? n
			    @name2addr[n] << addr
			}
		    }
		}
		@name2addr.each {|name, arr| arr.reverse!}
		@initialized = true
	    }
	end
	
	def getaddress(name)
	    each_address(name) {|address| return address}
	    raise HostResolvError, "#{@filename} has no name: #{name}"
	end
	
	def getaddresses(name)
	    ret = []
	    each_address(name) {|address| ret << address}
	    return ret
	end
	
	def each_address(name, &proc)
	    lazy_initialize
	    if @name2addr.include?(name)
		@name2addr[name].each(&proc)
	    end
	end
	
	def getname(address)
	    each_name(address) {|name| return name}
	    raise HostResolvError, "#{@filename} has no address: #{address}"
	end
	
	def getnames(address)
	    ret = []
	    each_name(address) {|name| ret << name}
	    return ret
	end
	
	def each_name(address, &proc)
	    lazy_initialize
	    if @addr2name.include?(address)
		@addr2name[address].each(&proc)
	    end
	end

	DefaultResolver = self::new
    end
end
