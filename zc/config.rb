# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/07/19 07:28:13
#
# COPYRIGHT: AFNIC (c) 2003
# CONTACT  : zonecheck@nic.fr
# LICENSE  : GPL v2.0 (or MIT/X11-like after agreement)
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS: (see also CREDITS file)
#
#

require 'framework'
require 'nresolv'


require 'config/pos'
require 'config/token'
require 'config/lexer'
require 'config/parser'


##
## Hold the information about the zc.conf configuration file
##
class Config
    Warning		= "w"		# Warning severity
    Fatal		= "f"		# Fatal severity
    Info		= "i"		# Informational
    Skip		= "S"		# Don't run the test

    TestSeqOrder	= [ CheckGeneric, CheckNameServer, 
	                    CheckNetworkAddress, CheckExtra ]

    #
    # Create a full filename from a configfile
    #  XXX: unix specific '/'
    def self.cfgfile(configfile)
	if configfile =~ /^\// 
	then configfile
	else ZC_CONFIG_DIR + "/" + configfile
	end
    end


    ## Configuration error
    ##  (unknown test, ordering problem, file not found)
    ## 
    class ConfigError < StandardError
    end


    ##
    ## Syntax error, while parsing the file
    ##
    class SyntaxError < ConfigError
	attr_reader :path, :pos
	def initialize(string=nil, path=nil, pos=nil)
	    super(string) if string
	    @path, @pos = path, pos
	end
    end


    ##
    ##
    ##
    ##
    class ByDomain
	def initialize(parent, domain, test_manager)
	    @domain		= domain
	    @test_manager	= test_manager
	    @parent		= parent
	    @constants		= {}
	    @test_seq		= {}
	end


	#
	# Set tests sequence for the 'family'
	#
	def []=(family, sequence)
	    if ! TestSeqOrder.include?(family)
		raise ArgumentError, $mc.get("config_family_unknown") % [ 
		    family.to_s ]
	    end
	    @test_seq[family] = sequence
	end


	#
	# Retrieve tests sequence
	#
	def [](family)
	    if ! TestSeqOrder.include?(family)
		raise ArgumentError, $mc.get("config_family_unknown") % [ 
		    family.to_s ]
	    end
	    @test_seq[family]
	end


	#
	# Add a new constant
	#
	def newconst(name, value)
	    # Check if constant is currently registered
	    if @constants.has_key?(name)
		raise ArgumentError, $mc.get("xcp_config_constexists") % [name]
	    end
	    # Debug
	    $dbg.msg(DBG::CONFIG, "adding constant: #{name} (in #{@domain})")
	    # Register constant
	    @constants[name] = value
	end


	#
	# Retrieve the constant value
	#
	def const(name)
	    @constants[name] || @parent.const(name)
	end

	#
	#
	#
	def check_wanted?(checkname, category)
	    
	end

	#
	# Read the configuration file
	#
	def read(configfile)
	    # Parse the configuration file
	    cfgfile = Config.cfgfile(configfile)
	    $dbg.msg(DBG::CONFIG, "domain config file: #{configfile}")
	    $dbg.msg(DBG::CONFIG, "reading file: #{cfgfile}")
	    begin
		io = File::open(cfgfile)
		parser = Config::Parser::new(Config::Lexer::new(io))
		constants, test_seq = parser.parse_cfg_specific
		io.close
	    rescue SystemCallError # for the Errno::ENOENT error
		raise ConfigError, $mc.get("problem_file") % configfile
	    end

	    # Add elements
	    begin
		# Set tests sequences
		test_seq.each  { |family, sequence| self[family] = sequence }
		# Add constants
		constants.each { |name, value|      newconst(name, value)   }
	    rescue ArgumentError => e
		raise ConfigError, e
	    end
	end


	#
	# Validate the loaded configuration file
	#  (ie: check the existence of all used methods chk_* and tst_*)
	#
	def validate(testmanager)
	    @test_seq.each_value { |b| 
		begin
		    b.semcheck(testmanager) 
		rescue StandardError => e
		    raise ConfigError, $mc.get("config_for_domain") % [ 
			e.message, @domain ]
		end
	    }
	end
    end


    #
    # Initializer
    #
    def initialize(test_manager)
	@test_manager	= test_manager
	@constants	= {}
	@conf		= {}
	@overrideconf	= nil
    end


    #
    # Retrieve configuration for the specified domain
    #  (retrieving the longest match)
    #
    def [](domain)
	return @overrideconf if @overrideconf

	depth = -1;
	cfg   = nil
	@conf.keys.each { |dom|
	    next unless domain.in_domain?(dom) && (depth < dom.depth)
	    depth = dom.depth
	    cfg   = @conf[dom]
	}
	cfg
    end


    #
    # Retrieve the constant value
    #
    def const(name)
	begin
	    @constants.fetch(name)
	rescue IndexError
	    # WARN: not localized (programming error)
	    raise RuntimeError, 
		"Trying to fetch undefined constant '#{name}'"
	end
    end

    #
    # Add a new constant
    #
    def newconst(name, value)
	# Check if constant is currently registered
	if @constants.has_key?(name)
	    raise ArgumentError, $mc.get("xcp_config_constexists") % [ name ]
	end
	# Debug
	$dbg.msg(DBG::CONFIG, "adding constant: #{name}")
	# Register constant
	@constants[name] = value
    end


    #
    # Set the overriding configuration profile
    #
    def overrideconf(testlist)
	# Create
	@overrideconf = ByDomain::new(self, NResolv::DNS::Name::Root, 
				   @test_manager)
	Config::TestSeqOrder.each { |family|
	    @overrideconf[family] = Instruction::Node::Block::new
	}

	# Populate with the requested check
	testlist.each { |checkname|
	    # Check that we have the method
	    if ! @test_manager.has_check?(checkname)
		raise ArgumentError, $mc.get("config_method_unknown") % [ 
		    checkname ]
	    end

	    # Add the new instruction
	    family = @test_manager.family(checkname)
	    instr  = Instruction::Node::Check::new(checkname, 
						   Config::Warning, "none")
	    @overrideconf[family] << instr
	}
    end


    #
    # Add a new configuration profile
    #
    def newconf(domain, file)
	# Check if this specific configuration is already registered
	if @conf.has_key?(domain)
	    raise ArgumentError, $mc.get("xcp_config_confexists") % [ domain ]
	end

	# Debug
	$dbg.msg(DBG::CONFIG, "adding config for: #{domain}")

	# Read and register specific configuration
	if file.nil?
	    # Create a blackhole
	    cfg = nil
	else
	    # Create a new profile and read it from the configuration file
	    cfg = ByDomain::new(self, domain, @test_manager)
	    cfg.read(file)
	end
	@conf[domain] = cfg
    end



    #
    # Read the configuration file
    #
    def read(configfile)
	# Parse the configuration file
	cfgfile = Config.cfgfile(configfile)
	$dbg.msg(DBG::CONFIG, "main config file: #{configfile}")
	$dbg.msg(DBG::CONFIG, "reading file: #{cfgfile}")
	begin
	    io = File::open(cfgfile)
	    parser = Config::Parser::new(Config::Lexer::new(io))
	    config, constants, useconf = parser.parse_cfg_main
	    io.close
	rescue SystemCallError # for the Errno::ENOENT error
	    raise ConfigError, $mc.get("problem_file") % configfile
	end

	
	# Add elements
	begin
	    # Add constants
	    constants.each { |k, v| newconst(k, v) }

	    # Create/Load domain specific configuration
	    useconf.each { |domain, filename|
		newconf(NResolv::DNS::Name::create(domain), filename)
	    }
	rescue ArgumentError => e
	    raise ConfigError, e
	end
    end


    #
    # Validate the loaded configuration file
    #  (ie: check the existence of all used methods chk_* and tst_*)
    #
    def validate(testmanager)
	@conf.each_value { |c| c.validate(testmanager) }
    end
end
