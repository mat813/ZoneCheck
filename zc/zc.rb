#!/usr/local/bin/ruby
# $Id$

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
require 'infocache'
require 'testmanager'

require 'test/generic'
require 'test/ns_specific'
require 'test/soa'
require 'test/ns'

# Constants
EXIT_OK		=  0
EXIT_USAGE	= -1
EXIT_ABORTED	=  2
EXIT_FAILED	=  1
EXIT_ERROR      =  3

# Internationnalisation
$mc = MessageCatalog::new("zc.en")


# Parse command line
begin
    Param::cmdline_usage(EXIT_USAGE) if ($param = Param::cmdline_parse).nil?
    $param.autoconf
rescue Param::ParamError => e
    $stderr.puts "ERROR: #{e}."
    exit EXIT_ERROR
end

puts "Domainname: #{$param.domainname}"
$param.ns.each { |n| puts "NS        : #{n[0]} [#{n[1].join(", ")}]" }


# Loading all the classes implementing tests
test_manager = TestManager::new($param)
test_manager << CheckGeneric::DomainNameSyntax
test_manager << CheckGeneric::NameServers
test_manager << CheckGeneric::ServerAddress
test_manager << CheckNameServer::ServerAccess
test_manager << CheckNetworkAddress::SOA
test_manager << CheckNetworkAddress::NS


# Read the configuration file
config = Config::new
config.read(test_manager, $param.configfile)

# Initialise and run the tests
test_manager.init(config)
success = begin
	      test_manager.test
	  rescue Diagnostic::FatalError
	      false
	  end
warnings = $param.warning.count

# Print status summary
if success
    tag = (warnings > 0) ? "res_succeed_but" : "res_succeed"
else
    if $param.all_fatal
	tag = "res_failed_on"
    else
	tag = (warnings > 0) ? "res_failed_and" : "res_failed"
    end
end
printf $mc.get(tag), warnings


# EXIT
exit success ? EXIT_OK : EXIT_FAILED

