#!/usr/local/bin/ruby

ZC_INSTALL_PATH		= (ENV["ZC_INSTALL_PATH"] || (ENV["HOME"] || "/homes/sdalu") + "/Repository/zonecheck").dup.untaint

ZC_LIB			= "#{ZC_INSTALL_PATH}/lib"

$LOAD_PATH << ZC_LIB

require 'nresolv'

resolver = NResolv::DNS::Client::TCP::new(NResolv::DNS::Config::new("ns1.nic.fr"))


name = NResolv::DNS::Name::create("fr.")
puts name
resolver.each_resource(name, NResolv::DNS::Resource::IN::AXFR, false) { |r,t,n,rpl|

    puts "#{r.to_dig}"
}
