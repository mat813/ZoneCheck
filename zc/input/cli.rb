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

require 'getoptlong'

class Param
    ##
    ## Processing parameters from CLI (Command Line Interface)
    ##
    class CLI
	def initialize
	    @p    = Param::new
	    @opts = GetoptLong.new(* opts_definition)
	    @opts.quiet = true
	end

	def opts_definition
	    [   [ "--help",	"-h",	GetoptLong::NO_ARGUMENT       ],
		[ "--version",	'-V',	GetoptLong::NO_ARGUMENT       ],
		[ "--quiet",	"-q",	GetoptLong::NO_ARGUMENT       ],
		[ "--debug",	"-d",   GetoptLong::REQUIRED_ARGUMENT ],
		[ "--batch",	"-B",   GetoptLong::REQUIRED_ARGUMENT ],
		[ "--config",	"-c",   GetoptLong::REQUIRED_ARGUMENT ],
		[ "--testdir",	        GetoptLong::REQUIRED_ARGUMENT ],
		[ "--category", "-C",   GetoptLong::REQUIRED_ARGUMENT ],
		[ "--test",     "-T",   GetoptLong::REQUIRED_ARGUMENT ],
		[ "--testlist",         GetoptLong::NO_ARGUMENT       ],
		[ "--testdesc",         GetoptLong::REQUIRED_ARGUMENT ],
		[ "--resolver",	"-r",   GetoptLong::REQUIRED_ARGUMENT ],
		[ "--ns",	"-n",   GetoptLong::REQUIRED_ARGUMENT ],
		[ "--ipv4",	"-4",	GetoptLong::NO_ARGUMENT       ],
		[ "--ipv6",	"-6",	GetoptLong::NO_ARGUMENT       ],
		[ "--one",	"-1",	GetoptLong::NO_ARGUMENT       ],
		[ "--tagonly",	"-g",   GetoptLong::NO_ARGUMENT       ],
		[ "--error",	"-e",	GetoptLong::REQUIRED_ARGUMENT ],
		[ "--transp",	"-t",	GetoptLong::REQUIRED_ARGUMENT ],
		[ "--verbose",	"-v",   GetoptLong::OPTIONAL_ARGUMENT ],
		[ "--output",	"-o",   GetoptLong::REQUIRED_ARGUMENT ],
		[ "--makecoffee",       GetoptLong::NO_ARGUMENT       ],
		[ "--coffee",           GetoptLong::NO_ARGUMENT       ] ]
        end

	def opts_analyse
	    @opts.each do |opt, arg|
		case opt
		when "--help"      then usage(EXIT_USAGE, $stdout)
		when "--version"
		    puts $mc.get("param_version").gsub("PROGNAME", PROGNAME) % 
			[ $zc_version ]
		    exit EXIT_OK
		when "--debug"     then $dbg.level	    = arg
		when "--batch"     then @p.batch	    = arg
		when "--config"    then @p.fs.cfgfile       = arg
		when "--testdir"   then @p.fs.testdir       = arg
		when "--category"  then @p.test.categories  = arg
		when "--test"      then @p.test.tests       = arg
		when "--testlist"  then @p.test.list        = true
		when "--testdesc"  then @p.test.desctype    = arg
		when "--resolver"  then @p.network.resolver = arg
		when "--ns"        then @p.domain.ns        = arg
		when "--ipv6"      then @p.network.ipv6     = true
		when "--ipv4"      then @p.network.ipv4     = true
		when "--one"       then @p.rflag.one	    = true
		when "--tagonly"   then @p.rflag.tagonly    = true
		when "--quiet"     then @p.rflag.quiet      = true
		when "--error"     then @p.error            = arg
		when "--transp"    then @p.transp           = arg
		when "--verbose"   then @p.verbose	    = arg
		when "--output"    then @p.output           = arg
		when "--makecoffee"
		    print <<EOT
#{PROGNAME}: I'm not currently designed for that task.
\tBut if you really want this option added in future version, 
\tyou should see with the maintainer: \"#{ZC_MAINTAINER}\".
EOT
		    exit EXIT_OK
		when "--coffee"
		    puts "#{PROGNAME}: I'll take one too. thank you."
		    exit EXIT_OK
		end
	    end
	end
	
	def args_analyse
	    if @p.batch
		if !ARGV.empty?
		    raise ParamError, $mc.get("xcp_param_batch_nodomain")
		end
	    else
		if !(ARGV.length == 1)
		    raise ParamError, $mc.get("xcp_param_domain_expected") 
		end
		@p.domain.name = ARGV[0]
	    end
	end

	def parse
	    begin
		opts_analyse
		args_analyse unless @p.test.list || @p.test.desctype
	    rescue GetoptLong::InvalidOption, GetoptLong::MissingArgument
		return nil
	    end
	    @p
	end

	def interact(param)
	    true
	end

	def usage(errcode, io=$stderr)
	    io.print $mc.get("param_usage").gsub("PROGNAME", PROGNAME)
	    exit errcode unless errcode.nil?
	end

	def error(str, errcode=nil, io=$stderr)
	    l10n_error = $mc.get("w_error").upcase
	    io.puts "#{l10n_error}: #{str}"
	    exit errcode unless errcode.nil?
	end
    end
end
