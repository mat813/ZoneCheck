#!/usr/local/bin/ruby

ZC_INSTALL_PATH		= ENV["ZC_INSTALL_PATH"].untaint || (ENV["HOME"].untaint || "/homes/sdalu") + "/ZC.CVS/zc"

ZC_LIB			= "#{ZC_INSTALL_PATH}/lib"

$LOAD_PATH << ZC_LIB

require 'nresolv'

resolver = NResolv::DNS::Client::TCP::new


name = NResolv::DNS::Name::create("sdalu.com.")
puts name
resolver.each_resource(name, NResolv::DNS::Resource::IN::AXFR, false) { |r,t,n,rpl|

    puts "#{r.to_dig}"
}
