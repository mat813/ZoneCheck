# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/07/19 07:28:13
#
# COPYRIGHT: AFNIC (c) 2003
# CONTACT  : zonecheck@nic.fr
# LICENSE  : GPL v2 (or MIT/X11-like after agreement)
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS: (see also CREDITS file)
#
#

require 'framework'
require 'nresolv'

require 'rexml/document'
require 'instructions'

##
## Hold the information about the zc.conf configuration file
##
class Config
    Warning		= "w"		# Warning severity
    Fatal		= "f"		# Fatal severity
    Info		= "i"		# Informational

    Skip		= "S"		# Don't run the test
    Ok			= "o"		# Reserved


    TestSeqOrder	= [ CheckGeneric, CheckNameServer, 
	                    CheckNetworkAddress, CheckExtra ]

    def self.severity2tag(severity)
	case severity
	when NilClass        then "ok"
	when Config::Info    then "info"
	when Config::Warning then "warning"
	when Config::Fatal   then "fatal"
	else raise ArgumentError, "unknown severity: #{severity}"
	end
    end

    #
    # Create a full filename from a configfile
    #  XXX: unix specific '/'
    def self.cfgfile(configfile)
	if configfile =~ /^\// 
	then configfile
	else $zc_config_dir + "/" + configfile
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
    ## Hold mapping information between a 'zone' and a 'profile'
    ##
    class ZoneMapping
	def initialize
	    @data = {}
	end

	# Store a new mapping
	def []=(zone, profilename)
	    zone = NResolv::DNS::Name::create(zone)
	    $dbg.msg(DBG::CONFIG, "adding mapping: #{zone} -> #{profilename}")
	    @data[zone] = profilename
	end

	# Returns the best mapping for a zone (longuest match)
	def [](zone)
	    depth, profilename = -1, nil
	    @data.each { |tld, name|
		next unless zone.in_domain?(tld) && (depth < tld.depth)
		depth, profilename = tld.depth, name
	    }
	    profilename
	end
	
	# Iterate on all the couple |zone, profile|
	def each(&bloc)
	    @data.each &bloc
	end
    end


    ##
    ## Store the different profiles
    ##
    class Profiles
	def initialize
	    @data = {}
	end

	# Store a new profile
	def <<(profile)
	    $dbg.msg(DBG::CONFIG, "adding profile: #{profile.name}")
	    @data[profile.name] = profile
	end

	# Retrieve a profile by its name
	def [](name)
	    @data[name]
	end

	# Iterate on |profile|
	def each(&block)
	    @data.each_value &block
	end
    end


    ##
    ## Store constants and allow inheritence from parent
    ## 
    class Constants
	attr_reader :parent
	def initialize(parent = nil)
	    @parent	= parent
	    @data	= {}
	end

	def []=(name, value)
	    $dbg.msg(DBG::CONFIG, "adding constant: #{name}")
	    @data[name] = value
	end

	def [](name)
	    @data[name] || (@parent ? @parent[name] : nil)
	end
    end



    class Preconf
	def initialize
	end
    end

    class Profile
	attr_reader :name, :rules, :constants

	def validate(testmanager)
	    @rules.each_value { |rules| rules.validate(testmanager) }
	end

	
	def initialize(xmlprofile, parent=nil)
	    @name	= xmlprofile.attributes['name']
	    @constants	= Constants::new(parent.constants)
	    @rules	= {}

	    $dbg.msg(DBG::CONFIG, "processing profile: #{@name}")

	    xmlprofile.elements.each("const") { |element|
		name  = element.attributes["name"]
		value = element.attributes["value"]
		@constants[name]=value.untaint
	    }

	    xmlprofile.elements.each("rules") { |element|
		klass  = element.attributes["class"]
		klass = case klass
			when 'generic'    then CheckGeneric
			when 'nameserver' then CheckNameServer
			when 'address'    then CheckNetworkAddress
			when 'extra'      then CheckExtra
			end

		@rules[klass] = parse_block(element)
	    }
	end

	#-- [private] -----------------------------------------------
	private


	def parse_block(rule)
	    block = Instruction::Block::new
	    rule.each_child { |elt|
		next unless elt.kind_of?(REXML::Element)
		block << case elt.name
			 when 'check' then parse_check(elt)
			 when 'case'  then parse_case(elt)
			 end
	    }
	    block
	end
	
	def parse_check(xmlelt)
	    Instruction::Check::new(xmlelt.attributes['name'],
				    xmlelt.attributes['severity'],
				    xmlelt.attributes['catagory'])
	end

	def parse_case(xmlelt)
	    when_stmt, else_stmt = {}, nil
	    xmlelt.each_child { |elt|
		next unless elt.kind_of?(REXML::Element)
		case elt.name
		when 'when' 
		    when_stmt[elt.attributes['value']] = parse_block(elt)
		when 'else'
		    else_stmt = parse_block(elt)
		end
	    }
	    Instruction::Switch::new(xmlelt.attributes['test'],
				     when_stmt, else_stmt)
	end
    end





    #
    # Initializer
    #
    def initialize(test_manager)
	@test_manager	= test_manager
    end


    def clear
	@constants	= Constants::new
	@profiles	= Profiles::new
	@mapping	= ZoneMapping::new
	@overrideconf	= nil
    end


    #
    # Set the overriding configuration profile
    #
    def overrideconf(testlist)
	# Create
	@overrideconf = ByDomain::new(self, NResolv::DNS::Name::Root, 
				   @test_manager)
	Config::TestSeqOrder.each { |family|
	    @overrideconf[family] = Instruction::Block::new
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
	    instr  = Instruction::Check::new(checkname, 
						   Config::Fatal, "none")
	    @overrideconf[family] << instr
	}
    end





    #
    # Read the configuration file
    #
    def load(configfile)
	clear
	# Parse the configuration file
	cfgfile = Config.cfgfile(configfile)
	$dbg.msg(DBG::CONFIG, "loading main configuration: #{configfile}")
	$dbg.msg(DBG::CONFIG, "reading file: #{cfgfile}")

	io, main = nil, nil
	begin
	    io   = File::open(cfgfile)
	    main = REXML::Document::new(io)
	rescue SystemCallError # for the Errno::ENOENT error
	    raise ConfigError, $mc.get("problem_file") % configfile
	rescue REXML::ParseException => e
	    puts "YO: #{e.position} / #{e.line} / #{e.message}"
	ensure
	    io.close unless io.nil?
	end

	main.root.elements.each("const") { |element|
	    name  = element.attributes["name"]
	    value = element.attributes["value"]
	    @constants[name] =value.untaint
	}

	main.root.elements.each("map") { |element|
	    zone    = element.attributes["zone"]
	    profile = element.attributes["profile"]
	    @mapping[zone] = profile.untaint
	}


	@mapping.each { |zone, profilename|
	    next if @profiles[profilename]
	    rulesfile ="#{profilename}.rules"
	    cfgfile = Config.cfgfile(rulesfile)
	    $dbg.msg(DBG::CONFIG, "loading profile: #{rulesfile}")
	    $dbg.msg(DBG::CONFIG, "reading file: #{cfgfile}")
	    io = nil
	    begin
		io = File::open(cfgfile)
		doc = REXML::Document::new(io)
	    rescue SystemCallError # for the Errno::ENOENT error
		raise ConfigError, $mc.get("problem_file") % configfile
	    rescue REXML::ParseException => e
		puts "YO: #{e.position} / #{e.line} / #{e.message}"
	    end
	    @profiles << Profile::new(doc.root.elements[1], self)

	}

    end


    #
    # Validate the loaded configuration file
    #  (ie: check the existence of all used methods chk_* and tst_*)
    #
    def validate(testmanager)
	@profiles.each { |c| c.validate(testmanager) }
    end

    #
    # Retrieve the bet profile for the zone
    #
    def profile(zone)
	@profiles[@mapping[zone]]
    end


    attr_reader :constants
end

