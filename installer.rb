# $Id$

# 
# CONTACT     : zonecheck@nic.fr
# AUTHOR      : Stephane D'Alu <sdalu@nic.fr>
#
# CREATED     : 2003/10/23 21:04:09
# REVISION    : $Revision$ 
# DATE        : $Date$
#


require 'fileutils'
include FileUtils


class Installer
    CVS_NAME	= %q$Name$
    VERSION	= (Proc::new { 
		       n = CVS_NAME.split[1]
		       n = /^ZC-(.*)/.match(n) unless n.nil?
		       n = n[1]                unless n.nil?
		       n = n.gsub(/_/, '.')    unless n.nil?
		       
		       n || Time::now.strftime("snapshot-%Y%d%m")
		   }).call

    def initialize
	interpreter = ENV['SUDO_COMMAND'] || ENV['_']
	if RUBY_PLATFORM =~ /mswin32/ 
	    require 'Win32API'
	    getcli = Win32API::new('kernel32', "GetCommandLine", [], 'P')
	    getcli.call() =~ /^\"([^\"]+)\"/
	    interpreter = $1
	end

	ARGV.delete_if { |arg|
	    case arg
	    when /^-D(\w+)(?:=(.*))?$/ then ENV[$1] = $2   ; true
	    when /^-U(\w+)$/           then ENV.delete($1) ; true
	    else false
	    end
	}

	ENV['RUBY'      ] ||= interpreter || 'ruby'
	ENV['PREFIX'    ] ||= '/usr/local'
	ENV['PROGNAME'  ] ||= 'zonecheck'
	ENV['HTML_PATH' ] ||= "/#{ENV['PROGNAME']}"
	ENV['ETCDIST'   ] ||= ''
	ENV['CHROOT'    ] ||= ''

	ENV['LIBEXEC'   ] ||= "#{ENV['PREFIX']}/libexec"
	ENV['BINDIR'    ] ||= "#{ENV['PREFIX']}/bin"
	ENV['MANDIR'    ] ||= "#{ENV['PREFIX']}/man"
	ENV['DOCDIR'    ] ||= "#{ENV['PREFIX']}/share/doc"
	ENV['ETCDIR'    ] ||= "#{ENV['PREFIX']}/etc"
	ENV['CGIDIR'    ] ||= "#{ENV['LIBEXEC']}/#{ENV['PROGNAME']}/cgi-bin"
        ENV['WWWDIR'    ] ||= "#{ENV['PREFIX']}/www"

	ENV['VERSION'	] ||= VERSION

	@installdir    = "#{ENV['LIBEXEC']}/#{ENV['PROGNAME']}"
	@confdir       = "#{ENV['ETCDIR']}/#{ENV['PROGNAME']}#{ENV['ETCDIST']}"
	@zc            = "#{@installdir}/zc/zc.rb"
	@wwwdir        = "#{ENV['WWWDIR']}/#{ENV['PROGNAME']}"

	@ch_installdir = "#{ENV['CHROOT']}#{@installdir}"
	@ch_confdir    = "#{ENV['CHROOT']}#{@confdir}"
	@ch_zc         = "#{ENV['CHROOT']}#{@zc}"
	@ch_wwwdir     = "#{ENV['CHROOT']}#{@wwwdir}"

	@verbose       = true
    end


    def configure
	puts "==> Configure"
	[   'www/zonecheck.conf.in', 
	    'contrib/distrib/rpm/zonecheck.spec.in' ].each { |in_filename|
	    out_filename = in_filename.gsub(/\.in$/, "")
	    puts "Generating: #{out_filename}"
	    content = File.readlines(in_filename)
	    ENV.each { |k, v|
		content.each { |line|
		    line.gsub!(/@#{k}@/, v)
		}
	    }
	    File::open(out_filename, "w") { |io| io.puts content } 
	}
	puts
    end



    def configinfo
	puts "Default values are:"
	[ 'RUBY', 'PREFIX', 'PROGNAME', 'HTML_PATH' ].each { |k|
	    puts "  #{k}=#{ENV[k]}" }
    end



    def inst_doc
	puts "==> Installing documentation"
	mkdir_p "#{ENV['CHROOT']}#{ENV['DOCDIR']}/#{ENV['PROGNAME']}",
	    						:verbose => @verbose
	install ['README', 'TODO', 'BUGS', 'HISTORY', 'CREDITS'], 
	    "#{ENV['CHROOT']}#{ENV['DOCDIR']}/#{ENV['PROGNAME']}",
	    :mode => 0644,				:verbose => @verbose
	puts
    end


    def patch_common
	puts "==> Patching core components"
	zc_content = File.readlines(@ch_zc)
	[   [ /^\#!.*ruby/, "#!#{ENV['RUBY']}" ],
	    [ 'ZC_INSTALL_PATH', "\\1\"#{@installdir}\"" ],
	    [ 'ZC_CONFIG_DIR', "\\1\"#{ENV['ETCDIR']}/#{ENV['PROGNAME']}\"" ],
	    [ 'ZC_LOCALIZATION_DIR', "\\1\"#{@installdir}/locale\"" ],
	    [ 'ZC_TEST_DIR',  "\\1\"#{@installdir}/test\"" ],
	    [ 'ZC_HTML_PATH', "\\1\"#{ENV['HTML_PATH']}\"" ] ].each { |pattern, value|
	    zc_content.each { |line|
		case pattern
		when Regexp
		    line.gsub!(pattern, value)
		when String
		    line.gsub!(/^(#{pattern}\s*=\s*(?:ENV\[[^\]]+\]\s*\|\|\s*)?).*/, value)
		end
	    }
	}
	File::open(@ch_zc, "w") { |io| io.puts zc_content } 
	chmod 0755, @ch_zc,				:verbose => @verbose
	puts
    end

    def inst_common
	puts "==> Installing core components"
	mkdir_p	@ch_installdir,				:verbose => @verbose
	cp_r	"zc", @ch_installdir,			:verbose => @verbose
	chmod 0755, @ch_zc,				:verbose => @verbose
	puts

	puts "==> Installing libraries"
	cp_r 'lib', @ch_installdir,			:verbose => @verbose
	puts

	puts "==> Installing tests"
	cp_r 'test', @ch_installdir,			:verbose => @verbose
	puts

	puts "==> Installing locale"
	cp_r 'locale', @ch_installdir,			:verbose => @verbose
	puts

	puts "==> Installing default configuration file"
	mkdir_p @ch_confdir,				:verbose => @verbose
	cp 'etc/zonecheck/zc.conf',        @ch_confdir,	:verbose => @verbose
	cp 'etc/zonecheck/rootservers',    @ch_confdir,	:verbose => @verbose
	cp Dir['etc/zonecheck/*.profile'], @ch_confdir,	:verbose => @verbose
	puts
    end


    def inst_cli
	puts "==> Installing CLI"
	mkdir_p "#{ENV['CHROOT']}#{ENV['BINDIR']}",	:verbose => @verbose
	ln_s @zc, "#{ENV['CHROOT']}#{ENV['BINDIR']}/#{ENV['PROGNAME']}",
	    :force => true,				:verbose => @verbose
	mkdir_p "#{ENV['CHROOT']}#{ENV['MANDIR']}/man1",:verbose => @verbose
	install "man/zonecheck.1",
	    "#{ENV['CHROOT']}#{ENV['MANDIR']}/man1/#{ENV['PROGNAME']}.1",
	    :mode => 0644,				:verbose => @verbose
	puts
    end


    def patch_cgi
	puts "==> Patching HTML pages"
	Dir["#{@ch_wwwdir}/www/html/*.html.*"].each { |page|
	    page_content = File.readlines(page)
	    page_content.each { |line| 
		line.gsub!(/HTML_PATH/, ENV['HTML_PATH']) }
	    File::open(page, "w", 0644) { |io| io.puts page_content }
	}
	puts
    end

    def inst_cgi
	puts "==> Installing HTML pages"
	mkdir_p @ch_wwwdir,				:verbose => @verbose
	cp_r "www", @ch_wwwdir,				:verbose => @verbose
	puts

	puts "==> Installing CGI"
	mkdir_p "#{ENV['CHROOT']}#{ENV['CGIDIR']}",	:verbose => @verbose
	ln_s @zc, "#{ENV['CHROOT']}#{ENV['CGIDIR']}/zc.cgi",
	    :force => true,				:verbose => @verbose
	puts
    end



    def info
	puts "==> Info"
	unless ENV['ETCDIST'].empty?
print <<EOT
- ZoneCheck configuration files have been installed in a distribution
   specific directory, so that you can merge them with your current
   configuration.
  If it is the first time you install ZoneCheck you can simply do:
   mv #{@confdir} #{ENV['ETCDIR']}/#{ENV['PROGNAME']}
EOT
	end
	puts ""
        puts "!!! Before using ZoneCheck, please edit the file: zc.conf"
	puts ""
    end



    #-- [RULES] -----------------------------------------------------------

    def rule_all
	inst_common ; patch_common 
	inst_cli
	inst_cgi    ; patch_cgi
	inst_doc
	true
    end
    def rule_cli
	inst_cli
	true
    end
    def rule_common
	inst_common ; patch_common
	true
    end
    def rule_cgi
	inst_cgi    ; patch_cgi
	true
    end
    def rule_doc
	inst_doc
	true
    end
    def rule_configinfo
	configinfo
	false
    end
    def rule_configure
	configure
	false
    end
end 


#----------------------------------------------------------------------


#
# Sanity check
#
m = /^(\d+)\.(\d+)\./.match(RUBY_VERSION)
if (m[1].to_i <= 1) && (m[2].to_i < 8)
    $stderr.puts "WARNING: ruby version 1.8.0 at least is required"
    $stderr.puts "WARNING: Hopping that the one defined in RUBY is more recent"
end


inst = Installer::new
info = false

if ARGV.empty?
    inst.configinfo 
else
    ARGV.each { |rule|
	unless inst.respond_to?("rule_#{rule}")
	    puts "ERROR: No rule '#{rule}' available"
	    exit 1
	end
    }

    ARGV.each { |rule|
	info |= inst.send "rule_#{rule}" 
    }
    
    inst.info if info
end
