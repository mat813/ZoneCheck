#!/usr/local/bin/ruby
# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/08/02 13:58:17
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


## !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
##
## WARN: when editing this file on installed ZoneCheck, you should
##       keep in mind that some ZoneCheck variant (cgi, ...) are 
##       more or less strongly connected with this file by:
##       - a copy     : only THIS file will be modified
##       - a hardlink : depending of your editor behaviour when
##                      saving the file, all the files will hold
##                      the modification OR only this file will.
##       - a symlink  : no problem should occured (except if on Windows)
##
## !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


## --> CUSTOMIZATION <-- #############################################
# 
# You shouldn't really need to change these values:
#  - This is normally automatically done when performing a: make install
#  - Setting the environment variable ZC_INSTALL_PATH should be enough
#     for testing the code
#

ZC_INSTALL_PATH		= ENV["ZC_INSTALL_PATH"].untaint || (ENV["HOME"].untaint || "/homes/sdalu") + "/ZC.CVS/zc"


ZC_DIR			= "#{ZC_INSTALL_PATH}/zc"
ZC_LIB			= "#{ZC_INSTALL_PATH}/lib"

ZC_CONFIG_DIR		= "#{ZC_INSTALL_PATH}/etc"
ZC_LOCALIZATION_DIR	= "#{ZC_INSTALL_PATH}/locale"
ZC_TEST_DIR		= "#{ZC_INSTALL_PATH}/test"

ZC_CONFIG_FILE		= "zc.conf"

ZC_LANG_FILE		= "zc.%s"
ZC_LANG_DEFAULT		= "en"

ZC_DEFAULT_INPUT	= "cli"

ZC_CGI_ENV_KEYS		= [ "GATEWAY_INTERFACE", "SERVER_ADDR" ]
ZC_CGI_EXT		= "cgi"

ZC_GTK_ENV_KEYS		= [] #[ "DISPLAY" ]

ZC_HTML_PATH		= "/zc" # no trailing /

ZC_CONTACT		= "zonecheck@nic.fr"

## --> END OF CUSTOMIZATION <-- ######################################


#
# Identification
#
ZC_CVS_NAME	= %q$Name$
ZC_NAME		= "ZoneCheck"
ZC_VERSION	= (Proc::new { 
		       n = ZC_CVS_NAME.split[1]
		       n = /^ZC-(.*)/.match(n) unless n.nil?
		       n = n[1]                unless n.nil?
		       n = n.gsub(/_/, ".")    unless n.nil?
		       
		       n || "<unreleased>"
		   }).call
ZC_MAINTAINER   = "Stephane D'Alu <sdalu@nic.fr>"
PROGNAME	= File.basename($0)


#
# Constants
#
EXIT_OK		=  0	# Everything went fine
EXIT_USAGE	= -1	# The user didn't bother reading the man page
EXIT_ABORTED	=  2	# The user aborted the program before completion
EXIT_FAILED	=  1	# The program completed but the result is negative
EXIT_ERROR      =  3	# An error unrelated to the result occured


#
# Sanity check
#
m = /^(\d+)\.(\d+)\./.match(RUBY_VERSION)
if (m[1].to_i <= 1) && (m[2].to_i < 8)
    $stderr.puts "#{PROGNAME}: ruby version 1.8.0 at least is required."
    exit EXIT_ERROR
end


#
# Run at safe level 1
#  A greater safe level is unfortunately not possible due to some 
#  low level operations in the NResolv library
#
$SAFE = 1


#
# Add zonecheck directories to ruby path
#
$LOAD_PATH << ZC_DIR << ZC_LIB


#
# Requirement
#
# Standard Ruby libraries
require 'socket'

# External libraries
require 'nresolv'

# Modification to standard/core ruby classes
require 'ext/array'

# ZoneCheck component
require 'dbg'
require 'msgcat'
require 'console'
require 'config'
require 'param'
require 'cachemanager'
require 'testmanager'


#
# Debugger object
#  (earlier initialization, can also be set via input interface)
#
$dbg       = DBG::new
$dbg.level = ENV["ZC_DEBUG"] if ENV["ZC_DEBUG"]


# IPv4/IPv6 stack detection
#  WARN: doesn't implies that we have the connectivity
$ipv4_stack = begin
		  UDPSocket::new(Socket::AF_INET).close
		  true
	      rescue NameError,      # if Socket::AF_INET doesn't exist
		     SystemCallError # for the Errno::EAFNOSUPPORT error
		  false
	      end
$ipv6_stack = begin
		  UDPSocket::new(Socket::AF_INET6).close
		  true
	      rescue NameError,      # if Socket::AF_INET6 doesn't exist
		     SystemCallError # for the Errno::EAFNOSUPPORT error
		  false
	      end


#
# Internationalisation
#  WARN: default locale is mandatory as no human messages are
#        present in the code (except for debugging purpose)
#

# Initialize the message catalog system
$mc = MessageCatalog::new(ZC_LOCALIZATION_DIR)

# Include the 'with_msgcat' facility in every objects
def with_msgcat(*msgcat_list)
    msgcat_list.each { |msgcat| $mc.read(msgcat) }
end

# Load the default locale
begin
    # Assume that if the ZC_LANG_FILE is available for a locale
    #  all the other necessary files are also available for that locale
    [ ENV["LANG"], ZC_LANG_DEFAULT ].compact.each { |lang|
	if $mc.available?(ZC_LANG_FILE, lang)
	    $dbg.msg(DBG::LOCALE, "Using locale: #{lang}")
	    $mc.lang = lang
	    $mc.read(ZC_LANG_FILE)
	    break
	end
	$dbg.msg(DBG::LOCALE, "Unable to find locale for '#{lang}'")
    }
    raise "Default locale (#{ZC_LANG_DEFAULT}) not found" if $mc.lang.nil?
rescue => e
    raise if $zc_slavemode
    $stderr.puts "ERROR: #{e.to_s}"
    exit EXIT_ERROR
end


#
# Console (needed for localisation)
#
$console = Console::new
$console.encoding = $mc.encoding


##
##
##
class ZoneCheck
    #
    # Input method
    #   (pseudo parameter in CLI: --INPUT=???)
    #
    def self.input_method
	im = nil	# Input Method

	# Check meta argument
	ARGV.delete_if { |a|
	    im = $1 if remove = a =~ /^--INPUT=(.*)/
	    remove
	}

	# Check environment variable ZC_INPUT
	im ||= ENV["ZC_INPUT"]

	# Try autoconfiguration
	im ||= if ((ZC_CGI_ENV_KEYS.collect {|k| ENV[k]}).nitems > 0) ||
		  (PROGNAME =~ /\.#{ZC_CGI_EXT}$/)
	       then "cgi"
	       elsif (ZC_GTK_ENV_KEYS.collect {|k| ENV[k]}).nitems > 0
	       then "gtk"
	       else ZC_DEFAULT_INPUT
	       end

	# Sanity check on Input Method
	if ! (im =~ /^\w+$/)
	    l10n_error = $mc.get("w_error").upcase
	    l10n_input = $mc.get("input_suspicious") % [ im ]
	    $console.stderr.puts "#{l10n_error}: #{l10n_input}"
	    exit EXIT_ERROR
	end
	im.untaint

	# Instanciate input method
	begin
	    require "input/#{im}"
	rescue LoadError => e
	    l10n_error = $mc.get("w_error").upcase
	    l10n_input = $mc.get("input_unsupported") % [ im ]
	    $console.stderr.puts "#{l10n_error}: #{l10n_input}"
	    exit EXIT_ERROR
	end
	eval "Input::#{im.upcase}::new"
    end


    def initialize
	@input		= nil
	@param		= nil
	@test_manager	= nil
	@testlist	= nil
    end

    def destroy
    end


    def lastaction(success)
    end

    def parse_batch(line)
	case line
	when /^DOM=(\S+)\s+NS=(\S+)\s*$/
	    @param.domain = Param::Domain::new($1, $2)
	    true
	when /^DOM=(\S+)\s*$/
	    @param.domain = Param::Domain::new($1)
	    true
	else
	    false
	end
    end


    def zc(cm)
	# Setup publisher (for the domain)
	@param.publisher.engine.setup(@param.domain.name)

	# Retrieve specific configuration
	if (cfg = @config[@param.domain.name]).nil?
	    l10n_error = $mc.get("input_unsupported_domain")
	    @param.publisher.engine.error(l10n_error % @param.domain.name)
	    return false
	end

	# Display intro (ie: domain and nameserver summary)
	@param.publisher.engine.intro(@param.domain)
	
	# Initialise and check
	@test_manager.init(cfg, cm, @param)
	success = begin
		      @test_manager.check
		      true
		  rescue Report::FatalError
		      false
		  end
	
	# Finish diagnostic (in case of pending output)
	@param.report.finish

	# Lastaction hook
	lastaction(success)

	# Return status
	return success
    end

    def do_check
	@param.fs.autoconf
	@param.rflag.autoconf
	@param.publisher.autoconf(@param.rflag)
	@param.network.autoconf
	@param.resolver.autoconf
	@param.test.autoconf

	# Begin formatter
	@param.publisher.engine.begin
	
	# 
	success = true
	begin
	    if ! @param.batch
		cm = CacheManager::create(@param.resolver.local,
					  @param.network.query_mode)
		
		@param.domain.autoconf(@param.resolver.local)
		@param.report.autoconf(@param.domain, 
				       @param.rflag, @param.publisher.engine)
		success = zc(cm)
	    else
		cm = CacheManager::create(@param.resolver.local, 
					  @param.network.query_mode)
		batchio = case @param.batch
			  when "-"              then $stdin
			  when String           then File::open(@param.batch) 
			  when Param::BatchData then @param.batch
			  end
		batchio.each_line { |line|
		    next if line =~ /^\s*$/
		    next if line =~ /^\#/
		    if ! parse_batch(line)
			@input.error($mc.get("xcp_zc_batch_parse"), EXIT_ERROR)
		    end
		    @param.domain.autoconf(@param.resolver.local)
		    @param.report.autoconf(@param.domain, 
					 @param.rflag, @param.publisher.engine)
		    success = false unless zc(cm)
		}
		batchio.close unless @param.batch == "-"
	    end
	rescue Param::ParamError => e
	    @param.publisher.engine.error(e.message)
	    success = false
	end

	# End formatter
	@param.publisher.engine.end

	#
	return success
    end


    #
    # Print the list of available tests
    # XXX: should use publisher
    #
    def do_testlist
	$console.stdout.puts @test_manager.list.sort
	true
    end

    #
    # Print the description of the tests
    #  If no selection is done (option -T), the description is
    #  printed for all the available tests
    # XXX: should use publisher
    #
    def do_testdesc
	suf = @param.test.desctype
	list = @param.test.tests || @test_manager.list.sort
	list.each { |test|
	    $console.stdout.puts $mc.get("#{test}_#{suf}")
	}
	true
    end

    def start 
	begin
	    # Input method selection
	    @input = ZoneCheck.input_method
	    
	    # Initialize parameters (from command line parsing)
	    @param = Param::new
	    @input.usage(EXIT_USAGE) unless @input.parse(@param)

	    # Load the test implementation
	    TestManager.load(@param.fs.testdir)

	    # Create test manager
	    @test_manager = TestManager::new
	    @test_manager.add_allclasses

	    # Load configuration
	    @config = Config::new(@test_manager)
	    @config.read(@param.fs.cfgfile)
	    @config.validate(@test_manager)

	    # Interaction
	    @input.interact(@param, @config, @test_manager)

	    # Test selection
	    @config.overrideconf(@param.test.tests) if @param.test.tests

	    # Do the job
	    success = if    @param.test.list		then do_testlist
		      elsif @param.test.desctype	then do_testdesc
		      else				     do_check
		      end

	    # Everything fine?
	    exit success ? EXIT_OK : EXIT_FAILED
	rescue Param::ParamError   => e
	    @input.error(e.to_s, EXIT_ERROR)
	rescue Config::SyntaxError => e
	    @input.error("%s %d: %s\n\t(%s)" % [ 
			     $mc.get("w_line").capitalize, e.pos.y, e.to_s,
			     e.path ], EXIT_ERROR)
	rescue Config::ConfigError => e
	    @input.error(e.to_s, EXIT_ERROR)
	rescue => e
	    raise if $dbg.enabled?(DBG::DONT_RESCUE)
	    @input.error(e.to_s, EXIT_ERROR)
	ensure
	    # exit() raise an exception ensuring that the following code
	    #   is executed
	    destroy
	end
	# NOT REACHED
    end
end



#
# Launch ZoneCheck
#  (if not in slave method)
#
if ! $zc_slavemode
    $zc_version	= ZC_VERSION
    $zc_name	= ZC_NAME
    $zc_contact	= ZC_CONTACT

    begin
	exit ZoneCheck::new::start ? EXIT_OK : EXIT_FAILED
    rescue Config::SyntaxError => e
	puts e.message
	puts e.at.x
	puts e.at.y
    rescue Param::ParamError => e
	puts e.class
	puts e.message
	puts e.backtrace.join("\n")
    end
end
