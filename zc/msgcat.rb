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

require 'dbg'



##
## Message catalog for L10N
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
    TagRegex = /[\w\/]+/

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
    #  and raise exception is the parameter is suspicious
    #
    def self.normlang(lng)
	unless lng =~ /^\w+(:?\.[\w\-]+)?$/
	    raise ArgumentError, "Suspicious language selection: #{lng}"
	end
	lng
    end


    #
    # Initializer
    #
    def initialize(directory)
	$dbg.msg(DBG::LOCALE, "creating message catalogue")
	@directory	= directory
	@catalog	= {}
	@loaded		= {}
	@lang		= nil
    end

    
    #
    # READER
    #
    attr_reader :lang


    #
    # WRITER: Set lang
    #
    def lang=(lng)
	@lang = MessageCatalog::normlang(lng).clone.untaint
    end


    #
    # Establish the filepath from the template file
    #  - %s is replace by lang
    #  - if not fullpath the default directory is prepend
    #
    def filepath(where, lng=@lang)
	lng   = MessageCatalog::normlang(lng) unless lng == @lang
	where = "#{@directory}/#{where}"      unless where[0] == ?/
	where % [ lng ]
    end


    #
    # Test if a file catalog is available
    #
    def available?(where, lng=@lang)
	lng = lng.clone.untaint if lng.tainted?
	File::readable?(filepath(where, lng))
    end


    #
    # Read catalog (from the template filename, see 'filepath')
    #
    def read(where)
	readfile(filepath(where))
    end
	

    #
    # Read catalog file
    #
    def readfile(msgfile)
	# Check for already loaded catalog
	file_stat = File::stat(msgfile)
	file_id   = [ file_stat.dev, file_stat.ino != 0 ? file_stat.ino \
	                                                : msgfile ]
	if @loaded.has_key?(file_id)
	    $dbg.msg(DBG::LOCALE, "file already loaded: #{msgfile}")
	    return
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
		when /^\[(#{TagRegex}|\*)]\s*$/
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
			    "Line #{lineno}: Tag '#{tag}' already defined"
		    end

		    while msg.gsub!(/\\$/, "")
			if (line = io.gets).nil?
			    raise SyntaxError,
				"Line #{lineno}: line expected after '\\'"
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
		    raise SyntaxError, "Line #{lineno}: malformed line"
		end
	    end
	}

	# Consider the file loaded
	@loaded[file_id] = true
    end


    #
    # Clear all messages
    #
    def clear
	$dbg.msg(DBG::LOCALE, "clearing message catalogue")
	@catalog = {}
	@loaded  = {}
	@lang    = nil
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
end
