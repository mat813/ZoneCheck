#!/usr/local/bin/ruby
# $Id$

# 
# AUTHOR : Stephane D'Alu <sdalu@nic.fr>
# CREATED: 2002/08/02 13:58:17
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS:
#
#

ZC_INSTALL_PATH		= ENV["ZC_INSTALL_PATH"].untaint || "/homes/sdalu/ZC.CVS/zc"

ZC_DIR			= "#{ZC_INSTALL_PATH}/zc"
ZC_LIB			= "#{ZC_INSTALL_PATH}/lib"

ZC_CONFIG_FILE		= "#{ZC_INSTALL_PATH}/etc/zc.conf"
ZC_LOCALIZATION_DIR	= "#{ZC_INSTALL_PATH}/locale"
ZC_TEST_DIR		= "#{ZC_INSTALL_PATH}/test"

ZC_LANG_FILE		= "zc.%s"
ZC_LANG_DEFAULT		= "en"

ZC_INPUT_METHODS	= [ "cli", "cgi", "gtk" ]

ZC_CGI_ENV_KEYS		= [ "GATEWAY_INTERFACE", "SERVER_ADDR" ]
ZC_CGI_EXT		= "cgi"


#
# Identification
#
CVS_NAME	= %q$Name$
ZC_VERSION	= (Proc::new { 
		       n = CVS_NAME.split[1]
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
#
$SAFE = 1


#
# Add zonecheck directories to ruby path
#
$LOAD_PATH << ZC_DIR << ZC_LIB


#
# Requirement
#
require 'socket'

require 'nresolv'
require 'ext'

require 'dbg'
require 'msgcat'
require 'config'
require 'param'
require 'cachemanager'
require 'testmanager'


#
# Constants
#
EXIT_OK		=  0
EXIT_USAGE	= -1
EXIT_ABORTED	=  2
EXIT_FAILED	=  1
EXIT_ERROR      =  3


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
	      rescue Errno::EAFNOSUPPORT
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
    def initialize
	@input		= nil
	@param		= nil
	@test_manager	= nil
	@testlist	= nil
    end

    def destroy
    end


    #
    # Parse command line
    #
    def select_input_method
	# Default Input Method
	im = nil

	# Check argument 
	ARGV.delete_if { |a|
	    im = $1 if remove = a =~ /^--INPUT=(.*)/
	    remove
	}

	# Check environment variable ZC_INPUT
	im ||= ENV["ZC_INPUT"]

	# Try autoconfiguring
	im ||= if ((ZC_CGI_ENV_KEYS.collect {|k| ENV[k]}).nitems > 0) ||
		  (PROGNAME =~ /\.#{ZC_CGI_EXT}$/)
	       then "cgi"
	       else "cli"
	       end

	# Instanciate input method
	if ! ZC_INPUT_METHODS.include?(im)
	    l10n_error = $mc.get("w_error").upcase
	    l10n_input = $mc.get("input_unsupported") % [ im ]
	    $stderr.puts "#{l10n_error}: #{l10n_input}"
	    exit EXIT_ERROR
	end

	@input = case im
		 when "cli"  then Param::CLI::new
		 when "cgi"  then Param::CGI::new
		 when "gtk"  then Param::GTK::new
		 else raise RuntimeError, "XXX: Fix ZC_INPUT_METHODS"
		 end
    end

    #
    # fs should be configured
    def parse_arguments
	begin
	    if (@param = @input.parse).nil?
		@input.usage(EXIT_USAGE)
	    end
	rescue Param::ParamError => e
	    @input.error(e.to_s, EXIT_ERROR)
	end
    end

    def interact
	begin
	    @input.interact(@config)
	rescue Param::ParamError => e
	    @input.error(e.to_s, EXIT_ERROR)
	end
    end

    #
    # Load ruby files implementing tests
    #  WARN: we are required to untaint for loading
    #
    # To minimize risk of choosing a random directory, only files
    #  that have the ruby extension (.rb) and have the "ZCTEST 1.0"
    #  magic header are loaded.
    #
    def load_tests_implementation
	$dbg.msg(DBG::TEST_LOADING, "directory: #{@param.fs.testdir}")
	Dir::open(@param.fs.testdir) { |dir|
	    dir.each { |entry|
		next unless entry =~ /\.rb$/
		testfile = "#{@param.fs.testdir}/#{entry}".untaint
		next unless begin
				File.open(testfile) { |io|
			           io.gets =~ /^\#\s*ZCTEST\s+1\.0:?\W/
		                }
			    rescue # Carefull with rescue all
				false
			    end
		$dbg.msg(DBG::TEST_LOADING, "loading file: #{entry}")
		load testfile
	    }
	}
    end
    

    #
    # Load TestManager with test classees
    #
    def init_testmanager
	# Create test manager
	@test_manager = TestManager::new
    
	# Add the test classes (they should have Test as superclass)
	[ CheckGeneric, CheckNameServer, 
	    CheckNetworkAddress, CheckExtra].each { |mod|
	    mod.constants.each { |t|
		testclass = eval "#{mod}::#{t}"
		if testclass.superclass == Test
		    $dbg.msg(DBG::TEST_LOADING, 
			     "instanciate class: #{testclass}")
		    @test_manager << testclass
		else
		    $dbg.msg(DBG::TEST_LOADING, 
			     "not a test class: #{testclass}")
		end
	    }
	}
    end


    #
    # Read the 'zc.conf' configuration file
    #
    def load_configuration
	@config = Config::new(@test_manager)
	@config.read(@param.fs.cfgfile)
    end

    def select_tests
	if @param.test.categories
	    @config.limittest(Config::L_Category, @param.test.categories)
	end
	if @param.test.tests
	    @config.limittest(Config::L_Test, @param.test.tests)
	end
    end

    def zc(cm)
	# Setup publisher domain
	@param.publisher.engine.setup(@param.domain.name)

	# Display intro (ie: domain and nameserver summary)
	@param.publisher.engine.intro(@param.domain) if @param.rflag.intro
	
	# Initialise and test
	@test_manager.init(@config, cm, @param)
	success = begin
		      @test_manager.test
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
	ok = true

	@param.fs.autoconf
	@param.rflag.autoconf
	@param.publisher.autoconf(@param.rflag)
	@param.network.autoconf
	@param.resolver.autoconf
	@param.test.autoconf

	# Begin formatter
	@param.publisher.engine.begin
	
	# 
	if ! @param.batch
	    cm = CacheManager::create(Test::DefaultDNS, 
				      @param.network.query_mode)
	    @param.domain.autoconf(@param.resolver.local)
	    @param.report.autoconf(@param.domain, 
				   @param.rflag, @param.publisher.engine)
	    ok = zc(cm)
	else
	    cm = CacheManager::create(Test::DefaultDNS, 
				      @param.network.query_mode)
	    batchio = case @param.batch
		      when "-"                   then $stdin
		      when String                then File::open(@param.batch) 
		      when Param::CGI::BatchData then @param.batch
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
		ok = false unless zc(cm)
	    }
	    batchio.close unless @param.batch == "-"
	end

	# End formatter
	@param.publisher.engine.end

	exit EXIT_OK
    end

    def do_testlist
	puts @config.test_list.sort
	exit EXIT_OK
    end

    def do_testdesc
	suf = @param.test.desctype
	@config.test_list.each { |test|
	    puts $mc.get("#{test}_#{suf}")
	}
	exit EXIT_OK
    end

    def start 
	begin
	    select_input_method
	    parse_arguments
	    load_tests_implementation
	    init_testmanager
	    load_configuration
	    interact
	    select_tests

	    if    @param.test.list
		do_testlist
	    elsif @param.test.desctype
		do_testdesc
	    else
		do_check
	    end
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
    rescue => e
	puts e.message
	puts e.backtrace.join("\n")
    end
end
