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


require 'socket'
require 'yaml'

require 'nresolv/dbg'


class NResolv
    class DNS
	##
	##
	##
	class RootServer
	    def initialize(rootserver)
		@rootserver = { }
		rootserver.each { |k, v|
		    @rootserver[NResolv::DNS::Name::create(k)] =
			v.collect { |addr| Address::create(addr) } }
	    end

	    def [](idx)	; @rootserver[idx]			; end
	    def size	; @rootserver.size			; end
	    def each	; @rootserver.each { |*a| yield a }	; end 
	    def keys	; @rootserver.keys			; end

	    def self.from_hintfile(filename)
		File::open(filename) { |io|
		    return RootServer::new(YAML::load(io)) }
	    end

	    ICANN	= RootServer::new ({ 
		'a.root-servers.net.' => [ '198.41.0.4'     ],
		'b.root-servers.net.' => [ '128.9.0.107'    ],
		'c.root-servers.net.' => [ '192.33.4.12'    ],
		'd.root-servers.net.' => [ '128.8.10.90'    ],
		'e.root-servers.net.' => [ '192.203.230.10' ],
		'f.root-servers.net.' => [ '192.5.5.241'    ],
		'g.root-servers.net.' => [ '192.112.36.4'   ],
		'h.root-servers.net.' => [ '128.63.2.53'    ],
		'i.root-servers.net.' => [ '192.36.148.17'  ],
		'j.root-servers.net.' => [ '192.58.128.30'  ],
		'k.root-servers.net.' => [ '193.0.14.129'   ],
		'l.root-servers.net.' => [ '198.32.64.12'   ],
		'm.root-servers.net.' => [ '202.12.27.33'   ] })

	    Default	= (Proc::new {
			       rootserver = ICANN
			       if f = $nresolv_rootserver_hintfile
				   begin
				       rootserver = RootServer.from_hintfile(f)
				   rescue YAML::ParseError,SystemCallError => e
				       Dbg.msg(DBG::CONFIG, 
					       "Unable to read/parse rootserver hint file (#{e})")
				   end
			       end
			       rootserver
			   }).call
	end



	##
	##
	##
	class Config
	    attr_reader :nameserver
	    attr_reader :rootserver

	    def self.from_resolv(filename='/etc/resolv.conf')
		nameserver, search = [], nil

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
		nameserver= [ '0.0.0.0' ] if nameserver.empty?
		search    = Socket.gethostname=~/\./ ? [$'] : [] if search.nil?
		# Ensure we have root in the search list
		search << '.'
		# Create config
		self::new(nameserver, search)
	    end

	    def self.from_winreg
		nameserver, search = [], nil

		# Read configuration from 'nslookup'
		nslookup_info = `nslookup 127.0.0.1`.split(/\r?\n/)
		nslookup_info[1] =~ /^[^:]+:\s*(.*?)\s*$/
		nameserver << $1.to_s.untaint unless $1.nil?

		# Autoconf for missing information
		nameserver= [ '0.0.0.0' ] if nameserver.empty?
		search    = Socket.gethostname=~/\./ ? [$'] : [] if search.nil?
		# Ensure we have root in the search list
		search << '.'
		# Create config
		self::new(nameserver, search)
	    end

	    def initialize(nameserver, search=[Name::Root], ndots=3)
		# Initialize attributs
		@nameserver = case nameserver
			      when Array then nameserver
			      else [ nameserver ]
			      end
		@rootserver = nil
		@search     = search.collect { |domain|
		                  Name::create(domain, true) }.uniq.freeze
		@ndots      = ndots < 0 ? 0 : ndots
	    end
	    
	    def candidates(name)
		# Ensure we got a DNS name
		name = Name::create(name)

		if name.absolute?
		then [ name ]
		else if name.depth + 1 >= @ndots
		     then [ Name::create(name, true) ]
		     else @search.collect { |domain| domain.prepend(name) }
		     end
		end
	    end

#	    Iterative	= nil
	    Recursive	= case RUBY_PLATFORM
			  when /cygwin/, /mswin32/ then Config::from_winreg
			  else                          Config::from_resolv
			  end
	    Default	= Recursive
	end
    end
end

