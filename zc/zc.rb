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



$dbg = DBG::new


#
# Internationalisation
#
$mc = MessageCatalog::new("zc.en")


#
# Parse command line
#
begin
    Param::cmdline_usage(EXIT_USAGE) if ($param = Param::cmdline_parse).nil?
    $param.autoconf
rescue Param::ParamError => e
    $stderr.puts "ERROR: #{e}"
    exit EXIT_ERROR
end


def zc(param)
    formatter = param.formatter

    # Begin formatter
    formatter.begin

    # Display intro (ie: domain and nameserver summary)
    if param.intro
	formatter.intro(param.domainname, param.ns, param.cache)
    end


    #
    # Loading into the TestManager all the implemented tests
    #
    # Create test manager
    test_manager = TestManager::new(param)
    
    # Load ruby files implementing tests
    $dbg.msg(DBG::TEST_LOADING, "directory: #{param.testdir}")
    Dir::open(param.testdir) { |dir|
	dir.each { |entry|
	    next unless entry =~ /\.rb$/
	    $dbg.msg(DBG::TEST_LOADING, "loading file: #{entry}")
	    load "#{param.testdir}/#{entry}"
	}
    }
    
    # Use the test classes (they should have Test as superclass)
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
    # Read the configuration file
    #
    config = Config::new(test_manager, param.fatal, param.warning, param.info)
    config.read(param.configfile)
    
    
    #
    # Initialise and run the tests
    #
    test_manager.init(config)
    success = begin
		  test_manager.test
		  true
	      rescue Diagnostic::FatalError
		  false
	      end
    

    #
    # Finish diagnostic (in case of pending output)
    #
    param.diagnostic.finish
    
    
    #
    # End formatter
    #
    formatter.end

    return success
end

success = zc($param)

#
# EXIT
#
exit success ? EXIT_OK : EXIT_FAILED
