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


#
# Customizable constants
#  (Only the ZC_INSTALL_PATH really need modification)
#
ZC_INSTALL_PATH		= "/homes/sdalu/ZC.CVS/zc"

ZC_DIR			= "#{ZC_INSTALL_PATH}/zc"
ZC_LIB			= "#{ZC_INSTALL_PATH}/lib"

ZC_LOCALIZATION_FILE	= "#{ZC_DIR}/locale/zc.%s"
ZC_CONFIG_FILE		= "#{ZC_DIR}/zc.conf"
ZC_TEST_DIR		= "#{ZC_DIR}/test"

ZC_LANG_DEFAULT		= "en"

ZC_CGI_ENV_KEYS		= [ "GATEWAY_INTERFACE", "SERVER_ADDR" ]
ZC_CGI_EXT		= "cgi"

#
# Identification
#
CVS_NAME	= %q$Name$
ZC_VERSION	= (Proc::new { 
		       n = CVS_NAME.split[1]
		       n = n.match(/^ZC-(.*)/) unless n.nil?
		       n = n[1]                unless n.nil?
		       n = n.gsub(/_/, ".")    unless n.nil?
		       
		       n || "<unreleased>"
		   }).call
ZC_MAINTAINER   = "Stephane D'Alu <sdalu@nic.fr>"
PROGNAME	= File.basename($0)

$zc_version	= ZC_VERSION


#
# Add zonecheck directories to ruby path
#
$LOAD_PATH << ZC_DIR << ZC_LIB


#
# Requirement
#
require 'getoptlong'
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


#
# Internationalisation
#  WARN: default locale is mandatory as no human messages are
#        present in the code (except debugging)
#
[ ENV["LANG"], ZC_LANG_DEFAULT ].compact.each { |lang|
    localefile = ZC_LOCALIZATION_FILE % [ lang ]
    if File.readable?(localefile)
	$mc = MessageCatalog::new(localefile)
	break
    end
    $dbg.msg(DBG::LOCALE, "Unable to find locale for '#{lang}'")
}
raise "Default locale (#{ZC_LANG_DEFAULT}) not found" if $mc.nil?


# Test for IPv6 stack
#  WARN: doesn't implies that we have IPv6 connectivity
$ipv6_stack = begin
		  UDPSocket::new(Socket::AF_INET6).close
		  true
	      rescue SocketError
		  false
	      end


##
##
##
class ZoneCheck
    def initialize
	@param		= nil
	@test_manager	= nil
	@testlist	= nil
    end

    def destroy
    end


    #
    # Parse command line
    #
    def configure
	begin
	    param = if ((ZC_CGI_ENV_KEYS.collect {|k| ENV[k]}).nitems > 0) ||
		       (PROGNAME =~ /\.#{ZC_CGI_EXT}$/)
		    then Param::CGI::new
		    else Param::CLI::new
		    end
	    param.usage(EXIT_USAGE) if (@param = param.parse).nil?
	rescue Param::ParamError => e
	    $stderr.puts "ERROR: #{e}"
	    exit EXIT_ERROR
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
	$dbg.msg(DBG::TEST_LOADING, "directory: #{@param.testdir}")
	Dir::open(@param.testdir) { |dir|
	    dir.each { |entry|
		next unless entry =~ /\.rb$/
		testfile = "#{@param.testdir}/#{entry}".untaint
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
    def load_testlist
	@config = Config::new(@test_manager, @param.category)
	if @param.test
	    @config.newtest(@param.test, Config::Fatal, "none")
	else
	    @config.read(@param.configfile)
	end
    end


    def zc(cm)
	# Setup publisher domain
	@param.publisher.setup(@param.domain.name)

	# Display intro (ie: domain and nameserver summary)
	@param.publisher.intro(@param.domain) if @param.rflag.intro
	
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

    def run
	ok = true

	@param.output_autoconf
	
	# Begin formatter
	@param.publisher.begin
	
	# 
	if ! @param.batch
	    @param.autoconf
	    cm = CacheManager::create(Test::DefaultDNS, @param.client)
	    ok = zc(cm)
	else
	    cm = CacheManager::create(Test::DefaultDNS, @param.client)
	    batchio = case @param.batch
		      when "-"    then $stdin
		      when String then File::open(@param.batch) 
		      when Param::CGI::BatchData then @param.batch
		      end
	    batchio.each_line { |line|
		next if line =~ /^\s*$/
		next if line =~ /^\#/
		if ! parse_batch(line)
		    $stderr.puts "ERROR: Unable to parse batch line"
		    exit(EXIT_ERROR)
		end
		@param.autoconf
		ok = false unless zc(cm)
	    }
	    batchio.close unless @param.batch == "-"
	end

	# End formatter
	@param.publisher.end
    end

    def start 
	begin
	    configure
	    load_tests_implementation
	    init_testmanager
	    load_testlist
	    
	    if @param.give_testlist
		puts @config.test_list.sort
		exit EXIT_OK
	    end
	    if @param.give_testdesc
		suf = @param.give_testdesc
		@config.test_list.each { |test|
		    puts $mc.get("#{test}_#{suf}")
		}
		exit EXIT_OK
	    end

	    run
	ensure
	    destroy
	end
    end
end



#
# Launch ZoneCheck
#  (if not in slave method)
#
if ! $zc_slavemode
    exit ZoneCheck::new.start ? EXIT_OK : EXIT_FAILED
end
