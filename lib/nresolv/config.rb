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
#   Config.new(nameserver, search=[""], absdepth=3)
#   Config.from_resolv(filename="/etc/resolv.conf")
#   Config#nameserver
#   Config#candidates(name)
#   Config::DefaultConfig
#

require 'socket'


module NResolv
    class DNS
	##
	##
	##
	class Config
	    attr_reader :nameserver

	    def self.from_resolv(filename="/etc/resolv.conf")
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
			    when "nameserver" then nameserver += args
			    when "domain"     then search = [args[0]]
			    when "search"     then search = args
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
		
		# Ensure that domain in the search list are FQDN
		search.map { |domain| # domain can't be empty
		    domain.concat(".") unless domain[-1] == ?. }
		# Ensure root is in the search list
		search.push("") unless search.include?("")

		# Create config
		self::new(nameserver, search)
	    end

	    def self.from_winreg
	    end

	    def initialize(nameserver, search=[""], absdepth=3)
		# Sanity check
		search.map { |domain|
		    if (! domain.empty?) && (domain[-1] != ?.)
			raise ArgumentError, 
			    "domains in the search list should be absolute"
		    end
		}
		
		# Initialize attributs
		@nameserver = case nameserver
			      when Array then nameserver
			      else [ nameserver ]
			      end
		@search     = search.uniq
		@absdepth   = absdepth < 0 ? 0 : absdepth
	    end
	    
	    def candidates(name)
		if name[-1] == ?.
		then [ name ]
		else if name.count(".") + 1 >= @absdepth
		     then [ "#{name}." ]
		     else @search.collect { |domain| "#{name}.#{domain}" }
		     end
		end
	    end
	end
	
	DefaultConfig = Config::from_resolv
    end
end

