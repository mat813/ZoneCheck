# $Id$

# 
# CONTACT     : zonecheck@nic.fr
# AUTHOR      : Stephane D'Alu <sdalu@nic.fr>
#
# CREATED     : 2002/07/18 10:29:53
# REVISION    : $Revision$ 
# DATE        : $Date$
#
# CONTRIBUTORS: (see also CREDITS file)
#
#
# LICENSE     : GPL v2 (or MIT/X11-like after agreement)
# COPYRIGHT   : AFNIC (c) 2003
#
# This file is part of ZoneCheck.
#
# ZoneCheck is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# ZoneCheck is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ZoneCheck; if not, write to the Free Software Foundation,
# Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#

require 'config'
require 'param'
require 'cachemanager'
require 'testmanager'



##
##
##
class ZoneCheck
    #
    # Input method
    #   (pseudo parameter: --INPUT=xxx)
    #
    def self.input_method
	im = nil	# Input Method

	# Check meta argument
	ARGV.delete_if { |a|
	    im = $1 if remove = a =~ /^--INPUT=(.*)/
	    remove
	}

	# Check environment variable ZC_INPUT
	im ||= ENV['ZC_INPUT']

	# Try autoconfiguration
	im ||= if ((ZC_CGI_ENV_KEYS.collect {|k| ENV[k]}).nitems > 0) ||
		  (PROGNAME =~ /\.#{ZC_CGI_EXT}$/)
	       then 'cgi'
	       elsif (ZC_GTK_ENV_KEYS.collect {|k| ENV[k]}).nitems > 0
	       then 'gtk'
	       else ZC_DEFAULT_INPUT
	       end

	# Sanity check on Input Method
	if ! (im =~ /^\w+$/)
	    l10n_error = $mc.get('word:error').upcase
	    l10n_input = $mc.get('input:suspicious_method') % [ im ]
	    $console.stderr.puts "#{l10n_error}: #{l10n_input}"
	    exit EXIT_ERROR
	end
	im = im.dup.untaint	# object can be frozen, so we need to dup it

	# Instanciate input method
	begin
	    require "input/#{im}"
	rescue LoadError => e
	    l10n_error = $mc.get('word:error').upcase
	    l10n_input = $mc.get('input:unsupported_method') % [ im ]
	    $console.stderr.puts "#{l10n_error}: #{l10n_input}"
	    exit EXIT_ERROR
	end
	eval "Input::#{im.upcase}::new"
    end


    def initialize
	@input		= nil
	@param		= nil
	@test_manager	= nil
	@testlist	= nil
    end


    def start 
	begin
	    # Input method selection
	    @input = ZoneCheck.input_method
	    
	    # Initialize parameters (from command line parsing)
	    argv_backup = ARGV.clone
	    @param = Param::new
	    @input.usage(EXIT_USAGE) unless @input.parse(@param)
	    @param.preconf.autoconf

	    # Load the test implementation
	    TestManager.load(@param.preconf.testdir)

	    # Create test manager
	    @test_manager = TestManager::new
	    @test_manager.add_allclasses

	    # Load configuration
	    @config = ZC_Config::new(@test_manager)
	    @config.load(@param.preconf.cfgfile)
	    @config.validate(@test_manager)
	    @config.profilename = @param.preconf.profile
	    
	    # Preset
	    if @input.allow_preset
		presetname = @param.preconf.preset
		if !presetname.nil? && @config.presets[presetname].nil?
		    raise ZC_Config::ConfigError,
			$mc.get('config:unknown_preset') % presetname
		end
		presetname ||= ZC_Config::Preset_Default

		if preset = @config.presets[presetname]
		    $dbg.msg(DBG::INIT) { 
			"Using preset '#{preset.name}' (reloading parameters)"}

		    # Create new argument
		    @param = Param::new

		    # Load preset
		    begin
			# Can be reverted
			[ 'verbose', 'transp',
			    'output', 'error' ].each { |opt|
			    @param.send("#{opt}=",preset[opt]) if preset[opt]
			}

			# Cannot be reverted
			@param.rflag.quiet = true if preset['quiet']
			@param.rflag.one   = true if preset['one'  ]
		    rescue Param::ParamError => e
			raise ZC_Config::ConfigError,
			    ($mc.get('config:error_in_preset') % presetname) +
			    " (#{e.message})"
		    end

		    # Restart argument parsing
		    ARGV.replace(argv_backup)
		    @input.restart
		    @input.usage(EXIT_USAGE) unless @input.parse(@param)
		end
	    end

	    # Interaction
	    unless @input.interact(@param, @config, @test_manager)
		exit EXIT_ABORTED 
	    end

	    # Test selection
	    @config.overrideconf(@param.test.tests) if @param.test.tests

	    # Do the job
	    success = if    @param.test.list		then do_testlist
		      elsif @param.test.desctype	then do_testdesc
		      else				     do_check
		      end

	    # Everything fine?
	    return success
	rescue Param::ParamError   => e
	    @input.error(e.to_s, EXIT_ERROR)
	rescue ZC_Config::SyntaxError => e
	    @input.error("%s %d: %s\n\t(%s)" % [ 
			     $mc.get('word:line').capitalize, e.line, e.to_s,
			     e.path ], EXIT_ERROR)
	rescue ZC_Config::ConfigError => e
	    @input.error(e.to_s, EXIT_ERROR)
	rescue => e
	    raise if $dbg.enabled?(DBG::DONT_RESCUE)
	    @input.error(e.to_s, EXIT_ERROR)
	ensure
	    # exit() raise an exception ensuring that the following code
	    #   is executed
	    destroy
	end
	# NOT REACHED
    end

    def destroy
    end


    #-- zonecheck ---------------------------------------------------------

    def do_check
	param_config_preamble

	# Begin formatter
	@param.publisher.engine.begin
	
	# 
	success = true
	begin
	    cm = CacheManager::create(@param.resolver.local,
				      @param.network.query_mode)
	    if ! @param.batch
		param_config_data
		success = zc(cm)
	    else
		batchio = case @param.batch
			  when '-'              then $stdin
			  when String           then File::open(@param.batch) 
			  when Param::BatchData then @param.batch
			  end
		batchio.each_line { |line|
		    next if line =~ /^\s*$/
		    next if line =~ /^\#/
		    if ! parse_batch(line)
			@input.error($mc.get('xcp_zc_batch_parse'), EXIT_ERROR)
		    end
		    param_config_data
		    success = false unless zc(cm)
		}
		batchio.close unless @param.batch == '-'
	    end
	rescue Param::ParamError => e
	    @param.publisher.engine.error(e.message)
	    success = false
	end

	# End formatter
	@param.publisher.engine.end

	#
	return success
    end

    def param_config_preamble
	@param.rflag.autoconf
	@param.option.autoconf
	@param.publisher.autoconf(@param.rflag, @param.option)
	@param.network.autoconf
	@param.resolver.autoconf
	@param.test.autoconf
    end

    def param_config_data
	@param.info.clear
	@param.info.autoconf
	@param.publisher.engine.info   = @param.info
	@param.domain.autoconf(@param.resolver.local)
	@param.report.autoconf(@param.domain, 
			       @param.rflag, @param.publisher.engine)
    end

    def parse_batch(line)
	case line
	when /^DOM=(\S+)\s+NS=(\S+)\s*$/
	    @param.domain = Param::Domain::new($1, $2)
	when /^DOM=(\S+)\s*$/
	    @param.domain = Param::Domain::new($1)
	else return false
	end
	true
    end

    def zc(cm)
	starttime = Time::now

	# Setup publisher (for the domain)
	@param.publisher.engine.setup(@param.domain.name)

	# Retrieve specific configuration
	if (cfg = @config.profile(@param.domain.name)).nil?
	    l10n_error = $mc.get('input:unsupported_domain')
	    @param.publisher.engine.error(l10n_error % @param.domain.name)
	    return false
	end

	@param.info.profile = [ cfg.name, cfg.longdesc ]
	@param.publisher.engine.constants = cfg.constants

	# Display intro (ie: domain and nameserver summary)
	@param.publisher.engine.intro(@param.domain)
	
	# Initialise and check
	@test_manager.init(cfg, cm, @param)
	status = @test_manager.check
	
	# Finish diagnostic (in case of pending output)
	@param.report.finish

	# Lastaction hook
	lastaction(status)

	# Return status
	return status
    end


    def lastaction(status)
    end


    #-- testlist ----------------------------------------------------------

    #
    # Print the list of available tests
    # XXX: should use publisher
    #
    def do_testlist
	@param.test.autoconf
	@test_manager.list.sort.each { |testname|
	    $console.stdout.puts testname }
	true
    end


    #-- testdesc ----------------------------------------------------------

    #
    # Print the description of the tests
    #  If no selection is done (option -T), the description is
    #  printed for all the available tests
    # XXX: should use other publisher than text
    #
    def do_testdesc
	require 'publisher/text'
	@param.publisher.engine = ::Publisher::Text

	param_config_preamble

	list		= @param.test.tests || @test_manager.list.sort
	publisher	= @param.publisher.engine
	profilename	= @config.profilename

	publisher.constants = (@config.profiles[profilename] || 
			       @config).constants

	publisher.begin
	list.each { |test| publisher.testdesc(test, @param.test.desctype) }
	publisher.end
	true
    end
end
