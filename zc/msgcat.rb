# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/08/02 13:58:17
#
# COPYRIGHT: AFNIC (c) 2003
# CONTACT  : zonecheck@nic.fr
# LICENSE  : GPL v2.0 (or MIT/X11-like after agreement)
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS: (see also CREDITS file)
#
#

require 'dbg'


##
## Message catalog for I18N/L10N
##
## The format of the message catalog is as follow:
## line       : '#' comment              # a comment
##            | tag ':' definition       # a tag definition
##            | tag '=' tag              # a link to another tag
##            | '[' prefix ']'           # a prefix to append to other tags
##
## prefix     : tag                      # the tag to use as prefix
##            | '*'                      # don't use a prefix
##
## definition : string                   # a string
##            | string '\' definition    # with posibility of continuation '\'
##
## tag        : [a-zA-Z0-9_/]+
##
##
## WARN: this file is not localized
##
## BUGFIX:
##  - method readfile: inode is always 0 on Windows
##      we replace the inode number by the filename if the inode is 0
##
class MessageCatalog
    TagRegex	= /[\w\/]+/
    LANGRegex	= /^(\w+?)(?:_(\w+))?(?:\.([\w\-]+))?$/

    ##
    ## Exception: the corresponding message catalog is not installed
    ##
    class NoCatalogFound < StandardError
    end


    ##
    ## Exception: Syntax error, while parsing the file
    ##
    class SyntaxError < StandardError
    end


    ##
    ## Exception: no message for the 'tag'
    ##
    class EntryNotFound < StandardError
    end


    #
    # Normalize lang
    #  (and raise exception is the parameter is suspicious)
    #  The settings are based on: LanguageCode_CountryCode.Encoding
    #
    def self.normlang(lng)
	unless lng =~ LANGRegex
	    raise ArgumentError, "Suspicious language selection: #{lng}"
	end
	lang  = $1.downcase
        lang += "_" + $2.upcase if $2
        lang += "." + $3.downcase if $3
        lang
    end


    #
    # Split lang between Language, Country, Encoding
    #
    def self.splitlang(lng)
	unless lng =~ LANGRegex
	    raise ArgumentError, "Suspicious language selection: #{lng}"
	end
        [ $1, $2, $3 ]
    end


    #
    # Initializer
    #
    def initialize(directory)
	$dbg.msg(DBG::LOCALE, "creating message catalogue")
	@directory	= directory
	@catalog	= {}
	@loaded		= {}
	@catfiles	= []
	@lang		= nil
        @language	= nil
        @country	= nil
        @encoding	= nil
    end
    
    #
    # READER
    #
    attr_reader :lang, :language, :country, :encoding


    #
    # WRITER: Set lang
    #
    def lang=(lng)
	@lang = self.class::normlang(lng).clone.untaint
        @language, @country, @encoding = self.class::splitlang(@lang)
    end


    #
    # Test if a file catalog is available
    #
    def available?(where, lng=@lang)
	lng = lng.clone.untaint if lng.tainted?
        filepath(where, lng).each { |fp| return true if File::readable?(fp) }
        false
    end


    #
    # Clear all messages
    #
    def clear
	$dbg.msg(DBG::LOCALE, "clearing message catalogue")
	@catalog	= {}
	@loaded		= {}
	@catfiles	= []
	@lang		= nil
    end


    #
    # Read catalog (from the template filename)
    #  (the occurence of %s is replaced by the language name)
    #
    def read(where)
        filepath(where).each { |fp|
	    if File::readable?(fp)
                if res = readfile(fp)
                    @catfiles << where
                end
                return res
            end
	}
        raise NoCatalogFound, "No valid catalog found for #{@lang}"
    end
	

    #
    # Get message associated with the 'tag'
    #
    def get(tag)
	if (str = @catalog[tag]).nil?
	    raise EntryNotFound, "Tag '#{tag}' has not been localized"
	end
	str
    end


    #
    # Reload the message catalogs
    #  (allowing to take into account a new locale)
    #
    def reload
	$dbg.msg(DBG::LOCALE, "reloading message catalogue")
	@catalog	= {}
	@loaded		= {}
	@catfiles.each { |where| 
            ok = false
            filepath(where).each { |fp|
		if File::readable?(fp)
                    readfile(fp) ; ok = true ; break
                end
            }
            unless ok
                raise NoCatalogFound, "No valid catalog found for #{@lang}"
            end
        }
    end

    ## PRIVATE ##
    private

    #
    # Establish the possible filepaths from the template file
    #  - %s is replace by lang
    #  - if not fullpath the default directory is prepend
    # 
    # WARN: An array is returned has for exemple we could need to
    #       test for fr_CA and next fr
    #
    def filepath(where, lng=@lang)
	lng   = self.class::normlang(lng) unless lng == @lang
        language, country, encoding = self.class::splitlang(lng)
	where = "#{@directory}/#{where}"  unless where[0] == ?/
	fp = [ where % [ language ] ]
        fp << where % [ "#{language}_#{country}" ] if country
        fp
    end


    #
    # Read catalog file
    #  (return false if the file was already loaded, true otherwise)
    #
    def readfile(msgfile)
	# Check for already loaded catalog
	file_stat = File::stat(msgfile)
	file_id   = [ file_stat.dev, file_stat.ino != 0 ? file_stat.ino \
	                                                : msgfile ]
	if @loaded.has_key?(file_id)
	    $dbg.msg(DBG::LOCALE, "file already loaded: #{msgfile}")
	    return false
	end


	# Read message catalogue
	$dbg.msg(DBG::LOCALE, "reading file: #{msgfile}")

	prefix   = nil
	lineno   = 0

	File::open(msgfile) { |io|
	    while line = io.gets
		lineno += 1
		line.chomp!
		next if line =~ /^\s*\#/
		next if line.empty?

		case line
		# Prefix section
		when /^\[(#{TagRegex}|\*)\]\s*$/
		    prefix = $1 == "*" ? nil : $1 
		    if prefix.nil?
		    then $dbg.msg(DBG::LOCALE, "removing prefix")
		    else $dbg.msg(DBG::LOCALE, "using prefix: #{prefix}")
		    end

		# Definition
		when /^(#{TagRegex})\s*:\s*(.*?)\s*$/
		    tag, msg = $1, $2
		    tag = "#{prefix}_#{tag}" if prefix

		    if @catalog.has_key?(tag)
			raise SyntaxError,
			    "Line #{lineno}: Tag '#{tag}' already defined (in #{msgfile})"
		    end

		    while msg.gsub!(/\\$/, "")
			if (line = io.gets).nil?
			    raise SyntaxError,
				"Line #{lineno}: line expected after '\\' (in #{msgfile})"
			end
			lineno += 1
			line.chomp!
			msg << line
		    end

		    msg.gsub!(/\\n/, "\n")
		    @catalog[tag] = msg
		    $dbg.msg(DBG::LOCALE, "adding locale: #{tag}")

		# Link
		when /^(#{TagRegex})\s*=\s*(#{TagRegex})\s*$/
		    tag, link = $1, $2
		    tag = "#{prefix}_#{tag}" if prefix
		    @catalog[tag] = @catalog[link]
		    $dbg.msg(DBG::LOCALE, "linking #{tag} -> #{link}")

		# ERROR
		else
		    raise SyntaxError, "Line #{lineno}: malformed line (in #{msgfile})"
		end
	    end
	}

	# Consider the file loaded
	@loaded[file_id] = true

	return true
    end
end
