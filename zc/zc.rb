#!/usr/local/bin/ruby
# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/08/02 13:58:17
#
# COPYRIGHT: AFNIC (c) 2003
# CONTACT  : zonecheck@nic.fr
# LICENSE  : GPL v2.0
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS:
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

ZC_GTK_ENV_KEYS		= [ "DISPLAY" ]

ZC_HTML_PATH		= "/zc/"

## --> END OF CUSTOMIZATION <-- ######################################



#
# Identification
#
ZC_CVS_NAME	= %q$Name$
ZC_VERSION	= (Proc::new { 
		       n = ZC_CVS_NAME.split[1]
		       n = /^ZC-(.*)/.match(n) unless n.nil?
		       n = n[1]                unless n.nil?
		       n = n.gsub(/_/, ".")    unless n.nil?
		       
		       n || "<unreleased>"
		   }).call
ZC_MAINTAINER   = "Stephane D'Alu <sdalu@nic.fr>"
PROGNAME	= File.basename($0)

$zc_version	= ZC_VERSION


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
require 'config'
require 'param'
require 'cachemanager'
require 'testmanager'


#
# Constants
#
EXIT_OK		=  0	# Everything went fine
EXIT_USAGE	= -1	# The user didn't bother reading the man page
EXIT_ABORTED	=  2	# The user aborted the program before completion
EXIT_FAILED	=  1	# The program completed but the result is negative
EXIT_ERROR      =  3	# An error unrelated to the result occured


#
# Debugger object
#
$dbg = DBG::new
$dbg.level=ENV["ZC_DEBUG"] if ENV["ZC_DEBUG"]


# Test for IPv6 stack
#  WARN: doesn't implies that we have IPv6 connectivity
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
#        present in the code (except debugging)
#
$mc = MessageCatalog::new(ZC_LOCALIZATION_DIR)
begin
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


##
##
##
class ZoneCheck
    #
    # Input method
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
	    $stderr.puts "#{l10n_error}: #{l10n_input}"
	    exit EXIT_ERROR
	end
	im.untaint

	# Instanciate input method
	begin
	    require "input/#{im}"
	rescue LoadError => e
	    l10n_error = $mc.get("w_error").upcase
	    l10n_input = $mc.get("input_unsupported") % [ im ]
	    $stderr.puts "#{l10n_error}: #{l10n_input}"
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
#	puts "DESTROYED"
    end


    def zc(cm)
	# Setup publisher domain
	@param.publisher.engine.setup(@param.domain.name)

	# Retrieve specific configuration
	if (cfg = @config[@param.domain.name]).nil?
	    l10n_error = $mc.get("param_unsupported_domain")
	    @param.publisher.engine.error(l10n_error % @param.domain.name)
	    return false
	end

	# Display intro (ie: domain and nameserver summary)
	@param.publisher.engine.intro(@param.domain) if @param.rflag.intro
	
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
		
	return success
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
	begin
	    if ! @param.batch
		cm = CacheManager::create(@param.resolver.local,
					  @param.network.query_mode)
		
		@param.domain.autoconf(@param.resolver.local)
		@param.report.autoconf(@param.domain, 
				       @param.rflag, @param.publisher.engine)
		zc(cm)
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
		    zc(cm)
		}
		batchio.close unless @param.batch == "-"
	    end
	rescue Param::ParamError => e
	    @param.publisher.engine.error(e.message)
	end

	# End formatter
	@param.publisher.engine.end
    end


    #
    # Print the list of available tests
    #
    def do_testlist
	puts @test_manager.list.sort
    end

    #
    # Print the description of the tests
    #  If no selection is done (option -T), the description is
    #  printed for all the available tests
    #
    def do_testdesc
	suf = @param.test.desctype
	list = @param.test.tests || @test_manager.list.sort
	list.each { |test|
	    puts $mc.get("#{test}_#{suf}")
	}
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

	    # Test selection/limitation
	    if @param.test.categories
		@config.limittest(Config::L_Category, @param.test.categories)
	    end
	    if @param.test.tests
		@config.overrideconf(@param.test.tests)
	    end

	    # Do the job
	    if    @param.test.list	then do_testlist
	    elsif @param.test.desctype	then do_testdesc
	    else			     do_check
	    end

	    # Everything is fine
	    exit EXIT_OK
	rescue Param::ParamError => e
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
    begin
	exit ZoneCheck::new.start ? EXIT_OK : EXIT_FAILED
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
