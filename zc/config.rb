# $Id$

# 
# CONTACT     : zonecheck@nic.fr
# AUTHOR      : Stephane D'Alu <sdalu@nic.fr>
#
# CREATED     : 2002/07/19 07:28:13
# REVISION    : $Revision$ 
# DATE        : $Date$
#
# CONTRIBUTORS: (see also CREDITS file)
#
#
# LICENSE     : GPL v2 (or MIT/X11-like after agreement)
# COPYRIGHT   : AFNIC (c) 2003
#
# This file is part of ZoneCheck.
#
# ZoneCheck is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# ZoneCheck is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ZoneCheck; if not, write to the Free Software Foundation,
# Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#

require 'framework'
require 'nresolv'

require 'ext/myxml'
require 'instructions'

##
## Hold the information about the zc.conf configuration file
##
class ZC_Config
    Warning		= 'w'		# Warning severity
    Fatal		= 'f'		# Fatal severity
    Info		= 'i'		# Informational

    Skip		= 'S'		# Don't run the test
    Ok			= 'o'		# Reserved

    Profile_Automatic	= 'automatic'
    Preset_Default	= 'default'

    E_PROFILE		= 'profile'	# XML Elements
    E_CONFIG		= 'config'	#      .
    E_PRESET		= 'preset'	#      .
    E_PARAM		= 'param'	#      .
    E_CASE		= 'case'	#      .
    E_WHEN		= 'when'	#      .
    E_ELSE		= 'else'	#      .
    E_CONST		= 'const'	#      .
    E_MAP		= 'map'		#      .
    E_RULES		= 'rules'	#      .
    E_CHECK		= 'check'	#      .
    E_TEST		= 'test'	#      .

    A_NAME		= 'name'	# XML attributes
    A_LONGDESC		= 'longdesc'	#      .
    A_VALUE		= 'value'	#      .
    A_ZONE		= 'zone'	#      .
    A_PROFILE		= 'profile'	#      .
    A_TEST		= 'test'	#      .
    A_CLASS		= 'class'	#      .
    A_SEVERITY		= 'severity'	#      .
    A_CATEGORY		= 'category'	#      .

    TestSeqOrder	= [ CheckGeneric.family, CheckNameServer.family, 
	                    CheckNetworkAddress.family, CheckExtra.family ]

    def self.severity2tag(severity)
	case severity
	when NilClass        then 'ok'
	when ZC_Config::Info    then 'info'
	when ZC_Config::Warning then 'warning'
	when ZC_Config::Fatal   then 'fatal'
	else raise ArgumentError, "unknown severity: #{severity}"
	end
    end

    #
    # Create a full filename from a configfile
    #  XXX: unix specific '/'
    def self.cfgfile(configfile)
	if configfile =~ /^\// 
	then configfile
	else $zc_config_dir + '/' + configfile
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
	attr_reader :path, :line
	def initialize(string=nil, path=nil, line=nil)
	    super(string) if string
	    @path, @line = path, line
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
    ## Store the different preset
    ##
    class Presets
	def initialize
	    @data = {}
	end

	# Store a new profile
	def <<(preset)
	    $dbg.msg(DBG::CONFIG, "adding preset: #{preset.name}")
	    @data[preset.name] = preset
	end

	# Retrieve a profile by its name
	def [](name)
	    @data[name]
	end

	# Iterate on |preset|
	def each(&block)
	    @data.each_value &block
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

	def fetch(name)
	    begin
		@data.fetch(name)
	    rescue IndexError
		if @parent 
		then @parent.fetch(name)
		else raise IndexError,
			"Unable to fetch ZoneCheck constant '#{name}'"
		end
	    end
	end
    end



    class Preset
	attr_reader :name
	def initialize(name, params)
	    @name = name
	    @data = params
	end
	def [](name)
	    @data[name]
	end
    end

    class Profile
	attr_reader :name, :rules, :constants, :longdesc

	def validate(testmanager)
	    @rules.each_value { |rules| rules.validate(testmanager) }
	end

	def initialize(name, constants, rules, longdesc)
	    @name, @constants, @rules, @longdesc = 
		name, constants, rules, longdesc
	end

	def self.from_xmlprofile(xmlprofile, parent=nil)
	    profilename	= xmlprofile[A_NAME]
	    longdesc	= xmlprofile[A_LONGDESC]
	    constants	= Constants::new(parent.constants)
	    rules	= {}

	    $dbg.msg(DBG::CONFIG, "processing profile: #{profilename}")

	    xmlprofile.each(E_CONST) { |element|
		name  = element[A_NAME]
		value = element[A_VALUE]
		constants[name]=value.untaint
	    }

	    xmlprofile.each(E_RULES) { |element|
		klass  = element[A_CLASS]
		rules[klass] = parse_block(element)
	    }

	    self::new(profilename, constants, rules, longdesc)
	end

	#-- [private] -----------------------------------------------
	private

	def self.parse_block(rule)
	    block = Instruction::Block::new
	    rule.each { |elt|
		next unless elt.kind_of?(MyXML::Node::Element)
		block << case elt.name
			 when E_CHECK then parse_check(elt)
			 when E_CASE  then parse_case(elt)
			 end
	    }
	    block
	end
	
	def self.parse_check(xmlelt)
	    name, severity, category = 
		xmlelt[A_NAME], xmlelt[A_SEVERITY], xmlelt[A_CATEGORY]

	    $dbg.msg(DBG::CONFIG, "creating instruction check: #{name}")
	    Instruction::Check::new(name, severity, category)
	end

	def self.parse_case(xmlelt)
	    when_stmt, else_stmt = {}, nil
	    testname = xmlelt[A_TEST]
	    xmlelt.each { |elt|
		next unless elt.kind_of?(MyXML::Node::Element)
		case elt.name
		when E_WHEN
		    when_stmt[elt[A_VALUE]] = parse_block(elt)
		when E_ELSE
		    else_stmt = parse_block(elt)
		end
	    }

	    $dbg.msg(DBG::CONFIG, "creating instruction test: #{testname}")
	    Instruction::Switch::new(testname, when_stmt, else_stmt)
	end
    end




    #
    # Initializer
    #
    def initialize(test_manager)
	@test_manager	= test_manager
    end


    #
    # Set the overriding configuration profile
    #
    def overrideconf(testlist)
	rules = {}

	# Order the check by class (or family)
	testlist.each { |checkname|
	    # Ensure that the check is currently available
	    if ! @test_manager.has_check?(checkname)
		raise ArgumentError, 
		    $mc.get('config:check_unknown') % [ checkname ]
	    end

	    # Ordering
	    (rules[@test_manager.family(checkname)] ||= []) << checkname
	}

	# Create a fake configuration
	fakeprofile = "<#{E_PROFILE} #{A_NAME}=\"override\" #{A_LONGDESC}=\"profile generated to only check a particular set of tests\">\n"
	TestSeqOrder.each { |family|
	    next unless rules[family]
	    fakeprofile += "<#{E_RULES} #{A_CLASS}=\"#{family}\">\n"
	    rules[family].each { |checkname|
		fakeprofile += "<#{E_CHECK} #{A_NAME}=\"#{checkname}\" #{A_SEVERITY}=\"#{Fatal}\" #{A_CATEGORY}=\"\"/>\n" }
	    fakeprofile += "</#{E_RULES}>\n"
	}
	fakeprofile += "</#{E_PROFILE}>\n"
	fakeconf  = "<?xml version='1.0' encoding='UTF-8'?>" + "\n"
	fakeconf += '<!DOCTYPE config PUBLIC "-//ZoneCheck//DTD Config V1.0//EN" "config.dtd">' + "\n"
	fakeconf += "<#{E_CONFIG}>" + fakeprofile + "</#{E_CONFIG}>"

	# Register it as an override profile
	xmlprofile = MyXML::Document::new(fakeconf).root.child(E_PROFILE)
	@profile_override = Profile::from_xmlprofile(xmlprofile, self)
    end


    #
    # Read the configuration file
    #
    def load(configfile)
	clear
	# Parse the configuration file
	cfgfile = ZC_Config.cfgfile(configfile)
	$dbg.msg(DBG::CONFIG, "loading main configuration: #{configfile}")
	$dbg.msg(DBG::CONFIG, "reading file: #{cfgfile}")

	io, main = nil, nil
	begin
	    io   = File::open(cfgfile)
	    main = MyXML::Document::new(io)
	rescue SystemCallError # for the Errno::ENOENT error
	    raise ConfigError, $mc.get('problem_file') % configfile
	rescue REXML::ParseException => e
	    raise SyntaxError::new(e.message, cfgfile, e.line)
	ensure
	    io.close unless io.nil?
	end

	main.root.each(E_CONST) { |element|
	    name  = element[A_NAME]
	    value = element[A_VALUE]
	    @constants[name] =value.untaint
	}

	main.root.each(E_MAP) { |element|
	    zone    = element[A_ZONE]
	    profile = element[A_PROFILE]
	    @mapping[zone] = profile.untaint
	}

	main.root.each(E_PRESET) { |preset|
	    presetname = preset[A_NAME]
	    params	= {}

	    preset.each(E_PARAM) { |param|
		name    = param[A_NAME]
		value   = param[A_VALUE]
		params[name] = value
	    }
	    @presets << Preset::new(presetname, params)
	}

	# Load all the available profiles
	Dir[ZC_Config.cfgfile('*.profile')].each { |cfgfile|
	    filename    = cfgfile.split('/')[-1]
	    profilename = filename.gsub(/\.profile$/, '')
	    next if @profiles[profilename]
	    $dbg.msg(DBG::CONFIG, "loading profile: #{filename}")
	    $dbg.msg(DBG::CONFIG, "reading file: #{cfgfile}")
	    io = nil
	    begin
		io = File::open(cfgfile)
		doc = MyXML::Document::new(io)
	    rescue SystemCallError # for the Errno::ENOENT error
		raise ConfigError, $mc.get("problem_file") % cfgfile
	    rescue REXML::ParseException => e
		raise SyntaxError::new(e.message, cfgfile, e.line)
	    end
	    doc.root.each(E_PROFILE) { |xmlprofile|
		@profiles << Profile::from_xmlprofile(xmlprofile, self) }
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
    # Force use of a particular profile
    #
    def profilename=(name)
	name = nil if name == Profile_Automatic
	if !name.nil? && @profiles[name].nil?
	    raise ConfigError, $mc.get('config:unknown_profile') % name
	end
	@profilename = name
    end


    #
    # Retrieve the bet profile for the zone
    #
    def profile(zone)
	pfile = selected_profile = @profiles[@profilename || @mapping[zone]]
	if @profile_override
	    # Ensure that the constants from the 'selected' profile
	    # will be used even in overrided profile
	    pfile = Profile::new(@profile_override.name,
				 selected_profile.constants,
				 @profile_override.rules,
				 @profile_override.longdesc)
	end
	pfile
    end


    attr_reader :constants, :profiles, :presets, :profilename

    #-- [private] ---------------------------------------------------------
    private
    #
    # Clear the current configuration
    #  (used in: initialize and load)
    #
    def clear
	@constants		= Constants::new
	@profiles		= Profiles::new
	@presets		= Presets::new
	@mapping		= ZoneMapping::new
	@profile_override	= nil
	@profilename		= nil
    end
end
