#!/usr/local/bin/ruby
# $Id$

# 
# AUTHOR : Stephane D'Alu <sdalu@nic.fr>
# CREATED: 2002/08/02 13:58:17
#
# $Revivion$ 
# $Date$
#
# CONTRIBUTORS:
#
#

$LOAD_PATH << "../lib/"

# Identification
RCS_ID		= %q$Id$
RCS_REVISION	= RCS_ID.split[2]
MYNAME		= File.basename($0)


# Requirement
require 'getoptlong'
require 'nresolv'
require 'ext'

require 'msgcat'
require 'config'
require 'param'
require 'cachemanager'
require 'testmanager'

require 'test/generic'
require 'test/ns_specific'
require 'test/soa'
require 'test/ns'
require 'test/mx'

# Constants
EXIT_OK		=  0
EXIT_USAGE	= -1
EXIT_ABORTED	=  2
EXIT_FAILED	=  1
EXIT_ERROR      =  3

# Internationalisation
$mc = MessageCatalog::new("zc.en")


# Parse command line
begin
    Param::cmdline_usage(EXIT_USAGE) if ($param = Param::cmdline_parse).nil?
    $param.autoconf
rescue Param::ParamError => e
    $stderr.puts "ERROR: #{e}"
    exit EXIT_ERROR
end

# Display intro (ie: domain and nameserver summary)
if $param.intro
    $param.formatter.intro($param.domainname, $param.ns, $param.cache)
end


# Loading all the classes implementing tests
test_manager = TestManager::new($param)
test_manager << CheckGeneric::DomainNameSyntax
test_manager << CheckGeneric::NameServers
test_manager << CheckGeneric::ServerAddress
test_manager << CheckNameServer::ServerAccess
test_manager << CheckNetworkAddress::SOA
test_manager << CheckNetworkAddress::NS
test_manager << CheckNetworkAddress::MX


# Read the configuration file
config = Config::new
config.read(test_manager, $param.configfile)


#set_trace_func proc { |event, file, line, id, binding, classname|
#  printf "%8s %s:%-2d %10s %8s\n", event, file, line, id, classname
#}

# Initialise and run the tests
test_manager.init(config)
success = begin
	      test_manager.test
	      true
	  rescue Diagnostic::FatalError
	      false
	  end

$param.diagnostic.finish


# EXIT
exit success ? EXIT_OK : EXIT_FAILED

