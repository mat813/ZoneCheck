# $Id$

require 'diagnostic'

class Param
    attr_reader :configfile, :ipv4, :ipv6, :domainname
    attr_writer :configfile, :ipv4, :ipv6, :domainname

    attr_reader :info, :warning, :fatal
    attr_reader :all_fatal

    def initialize
	@configfile = "zc.conf"
	@ipv4       = true
	@ipv6       = true
	@all_fatal  = false
	@info       = Diagnostic::Info::new
	@warning    = Diagnostic::Warning::new
	@fatal      = Diagnostic::Fatal::new
    end

    def all_fatal=(action)
	@warning.fatal = @all_fatal = action
    end
end
