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
# HISTORIC:
#  - First version was developped by Erwan Mas
#  - C++ prototype was developped by 
#

$LOAD_PATH << "../lib/"


#
# Identification
#
CVS_NAME	= %q$Name$
RCS_ID		= %q$Id$
RCS_REVISION	= RCS_ID.split[2]
ZC_VERSION	= (Proc::new { 
		       n = CVS_NAME.split[1]
		       n = n.match(/^ZC-(.*)/) unless n.nil?
		       n = n[1]                unless n.nil?
		       n = n.gsub(/_/, ".")    unless n.nil?
		       
		       n || "<unreleased>"
		   }).call
ZC_MAINTAINER   = "Stephane D'Alu <sdalu@nic.fr>"
PROGNAME	= File.basename($0)

$zc_version = ZC_VERSION

#
# Requirement
#
require 'getoptlong'
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
#
$mc = MessageCatalog::new("zc.en")

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
	    param = Param::CLI::new
	    param.usage(EXIT_USAGE) if (@param = param.parse).nil?
	rescue Param::ParamError => e
	    $stderr.puts "ERROR: #{e}"
	    exit EXIT_ERROR
	end
    end


    #
    # Load ruby files implementing tests
    #
    def load_tests_implementation
	$dbg.msg(DBG::TEST_LOADING, "directory: #{@param.testdir}")
	Dir::open(@param.testdir) { |dir|
	    dir.each { |entry|
		next unless entry =~ /\.rb$/
		$dbg.msg(DBG::TEST_LOADING, "loading file: #{entry}")
		load "#{@param.testdir}/#{entry}"
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
	@config = Config::new(@test_manager)
	if @param.test
	    @config.add(@param.test, Config::Fatal)
	else
	    @config.read(@param.configfile)
	end
    end


    def zc(cm)
	# Begin formatter
	@param.publisher.begin
	
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
	
	
	# End formatter
	@param.publisher.end
	
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

	if ! @param.batch
	    @param.autoconf
	    cm = CacheManager::create(Test::DefaultDNS, @param.client)
	    ok = zc(cm)
	else
	    cm = CacheManager::create(Test::DefaultDNS, @param.client)
	    batchio = @param.batch == "-" ? $stdin : File::open(@param.batch) 
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
#
#
if ! $zc_slavemode
    exit ZoneCheck::new.start ? EXIT_OK : EXIT_FAILED
end
