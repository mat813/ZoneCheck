# 

require 'socket'

#
# PUBLIC
#   Config.new(nameserver, search=[""], absdepth=3)
#   Config.from_resolv(filename="/etc/resolv.conf")
#   Config#nameserver
#   Config#candidates(name)
#   Config::DefaultConfig
#

module NResolv
    class DNS
	class Config
	    attr_reader :nameserver

	    def self.from_resolv(filename="/etc/resolv.conf")
		nameserver = []
		search     = nil

		# read config file
		begin
		    open(filename) {|f|
			f.each {|line|
			    line.sub!(/[\#;].*/, '')
			    keyword, *args = line.split(/\s+/)
			    args.each { |arg| arg.untaint }
			    next unless keyword
			    case keyword
			    when 'nameserver'
				nameserver += args
			    when 'domain'
				search = [args[0]]
			    when 'search'
				search = args
			    end
			}
		    }
		rescue Errno::ENOENT
		end
		
		# try to auto-configure for missing information
		nameserver = ['0.0.0.0'] if nameserver.empty?
		unless search
		    hostname = Socket.gethostname
		    if /\./ =~ hostname
			search = [$'] #'
		    else
			search = []
		    end
		end
		
		# ensure that domain in the search list are FQDN
		search.map { |domain|
		    domain.concat(".") unless domain =~ /\.$/
		}
		# ensure root is in the search list
		search.push("") unless search.include?("")

		self::new(nameserver, search)
	    end

	    def initialize(nameserver, search=[""], absdepth=3)
		@nameserver = nameserver
		@search     = search
		@absdepth   = absdepth
	    end
	    
	    def candidates(name)
		if name =~ /\.$/
		    [ name ]
		else
		    if name.count(".") + 1 >= @absdepth
			[ name + "." ]
		    else
			@search.collect { |domain| name + "." + domain }
		    end
		end
	    end
	end
	
	DefaultConfig = Config::from_resolv
    end
end

