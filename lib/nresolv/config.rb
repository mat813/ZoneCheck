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
# CONTRIBUTORS: (see also CREDITS file)
#
#

#
# PUBLIC
#   Config.new(nameserver, search=[''], absdepth=3)
#   Config.from_resolv(filename='/etc/resolv.conf')
#   Config#nameserver
#   Config#candidates(name)
#   Config::DefaultConfig
#

require 'socket'


class NResolv
    class DNS
	##
	##
	##
	class Config
	    attr_reader :nameserver

	    def self.from_resolv(filename='/etc/resolv.conf')
		nameserver = []
		search     = nil

		# Read configuration file
		begin
		    File.open(filename) {|io|
			io.each { |line|
			    line.sub!(/[\#;].*/, '')
			    keyword, *args = line.split(/\s+/)
			    args.each { |arg| arg.untaint }
			    case keyword
			    when 'nameserver' then nameserver += args
			    when 'domain'     then search = [args[0]]
			    when 'search'     then search = args
			    end
			}
		    }
		rescue Errno::ENOENT
		end
		
		# Autoconf for missing information
		if nameserver.empty?
		    nameserver = ['0.0.0.0'] 
		end
		if search.nil?
		    search = Socket.gethostname =~ /\./ ? [$'] : [] #' <- emacs
		end
		
		# Create domain list
		search.map! { |domain| Name::create(domain, true) }
		search << Name::Root

		# Create config
		self::new(nameserver, search)
	    end

	    def self.from_winreg
		nameserver = []
		search     = nil

		# Use of 'nslookup'
		nslookup_info = `nslookup 127.0.0.1`.split(/\r?\n/)
		nslookup_info[1] =~ /^[^:]+:\s*(.*?)\s*$/

		nameserver << $1.to_s.untaint unless $1.nil?

		# Autoconf for missing information
		if nameserver.empty?
		    nameserver = ['0.0.0.0'] 
		end
		if search.nil?
		    search = Socket.gethostname =~ /\./ ? [$'] : [] #' <- emacs
		end
		
		# Create domain list
		search.map! { |domain| Name::create(domain, true) }
		search << Name::Root

		# Create config
		self::new(nameserver, search)
	    end

	    def initialize(nameserver, search=[Name::Root], absdepth=3)
		# Sanity check
		search.each { |domain|
		    unless domain.absolute?
			raise ArgumentError, 
			    'domains in the search list should be absolute'
		    end
		}
		
		# Initialize attributs
		@nameserver = case nameserver
			      when Array then nameserver
			      else [ nameserver ]
			      end
		@search     = search.uniq.freeze
		@absdepth   = absdepth < 0 ? 0 : absdepth
	    end
	    
	    def candidates(name)
		# Ensure we got a DNS name
		name = Name::create(name)

		if name.absolute?
		then [ name ]
		else if name.depth + 1 >= @absdepth
		     then [ Name::create(name, true) ]
		     else @search.collect { |domain| domain.prepend(name) }
		     end
		end
	    end
	end
	
	DefaultConfig = case RUBY_PLATFORM
	                when /cygwin/, /mswin32/ then Config::from_winreg
	                else                          Config::from_resolv
	                end
    end
end

