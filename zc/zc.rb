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

$LOAD_PATH << "../lib/"


#
# Identification
#
RCS_ID		= %q$Id$
RCS_REVISION	= RCS_ID.split[2]
PROGNAME	= File.basename($0)


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


#
# Parse command line
#
begin
    Param::cmdline_usage(EXIT_USAGE) if (param = Param::cmdline_parse).nil?
    param.autoconf
rescue Param::ParamError => e
    $stderr.puts "ERROR: #{e}"
    exit EXIT_ERROR
end


#
# Load ruby files implementing tests
#
$dbg.msg(DBG::TEST_LOADING, "directory: #{param.testdir}")
Dir::open(param.testdir) { |dir|
    dir.each { |entry|
	next unless entry =~ /\.rb$/
	$dbg.msg(DBG::TEST_LOADING, "loading file: #{entry}")
	load "#{param.testdir}/#{entry}"
    }
}
    

#
# Load TestManager with test classees
#
# Create test manager
test_manager = TestManager::new
    
# Add the test classes (they should have Test as superclass)
[ CheckGeneric, CheckNameServer, CheckNetworkAddress].each { |mod|
    mod.constants.each { |t|
	testclass = eval "#{mod}::#{t}"
	if testclass.superclass == Test
	    $dbg.msg(DBG::TEST_LOADING, "instanciate class: #{testclass}")
	    test_manager << testclass
	else
	    $dbg.msg(DBG::TEST_LOADING, "not a test class: #{testclass}")
	end
    }
}


#
# Read the 'zc.conf' configuration file
#
config = Config::new(test_manager)
config.read(param.configfile)



def zc(test_manager, config, cm, param)
    # Begin formatter
    param.publisher.begin

    # Display intro (ie: domain and nameserver summary)
    param.publisher.intro(param.domain) if param.rflag.intro

    # Initialise and test
    test_manager.init(config, cm, param)
    success = begin
		  test_manager.test
		  true
	      rescue Report::FatalError
		  false
	      end

    # Finish diagnostic (in case of pending output)
    param.report.finish
    
    
    # End formatter
    param.publisher.end

    return success
end




if ! param.batch
    cm = CacheManager::create(Test::DefaultDNS, param.client)
    success = zc(test_manager, config, cm, param)
else
    cm = CacheManager::create(Test::DefaultDNS, param.client)
    $stdin.each_line { |line|
	case line
	when /^\s*$/
	    next
	when /^DOM=(\S+)\s+NS=(\S+)\s*$/
	    param.domain = Param::Domain::new($1, $2)
	when /^DOM=(\S+)\s*$/
	    param.domain = Param::Domain::new($1)
	else
	    $stderr.puts "ERROR: Unable to parse batch line"
	    exit(EXIT_ERROR)
	end
	param.autoconf
	zc(test_manager, config, cm, param)
    }
end


#
# EXIT
#
exit success ? EXIT_OK : EXIT_FAILED
