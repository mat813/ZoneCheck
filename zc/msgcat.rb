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

##
## Message catalog for L10N
##
## The format of the message catalog is as follow:
## line       : '#' comment              # a comment
##            | tag ':' definition       # a tag definition
##            | tag '=' tag              # a link to another tag
##            | '[' prefix ']'           # a prefic to append to other tags
##
## prefix     : tag                      # the tag to use as prefix
##            | '*'                      # don't use a prefix
##
## definition : string                   # a string
##            | string '\' definition    # with posibility of continuation '\'
##
## tag        : [a-zA-Z0-9_]
##
##
## WARN: this file is not localized (due to chicken and egg problem)
##
class MessageCatalog
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
    # Initializer
    #
    def initialize
	$dbg.msg(DBG::LOCALE, "creating message catalogue")
	@catalog = {}
    end

    #
    # Read catalog file
    #
    def read(msgfile)
	$dbg.msg(DBG::LOCALE, "reading file: #{msgfile}")

	prefix   = nil
	lineno   = 0

	# Read message catalogue
	File.open(msgfile) { |io|
	    while line = io.gets
		lineno += 1
		line.chomp!
		next if line =~ /^\s*\#/
		next if line.empty?

		case line
		# Prefix section
		when /^\[(\w+|\*)]\s*$/
		    prefix = $1 == "*" ? nil : $1 
		    if prefix.nil?
		    then $dbg.msg(DBG::LOCALE, "removing prefix")
		    else $dbg.msg(DBG::LOCALE, "using prefix: #{prefix}")
		    end

		# Definition
		when /^(\w+)\s*:\s*(.*?)\s*$/
		    tag, msg = $1, $2
		    tag = "#{prefix}_#{tag}" if prefix

		    if @catalog.has_key?(tag)
			raise SyntaxError, fmt_line(lineno,
				"Tag '#{tag}' already defined")
		    end

		    while msg.gsub!(/\\$/, "")
			if (line = io.gets).nil?
			    raise SyntaxError, fmt_line(lineno, 
				"new line expected after continuation mark")
			end
			lineno += 1
			line.chomp!
			msg << line
		    end

		    msg.gsub!(/\\n/, "\n")
		    @catalog[tag] = msg
		    $dbg.msg(DBG::LOCALE, "adding locale: #{tag}")

		# Link
		when /^(\w+)\s*=\s*(\w+)\s*$/
		    tag, link = $1, $2
		    tag = "#{prefix}_#{tag}" if prefix
		    @catalog[tag] = @catalog[link]
		    $dbg.msg(DBG::LOCALE, "linking #{tag} -> #{link}")

		else
		    raise SyntaxError, 
			fmt_line(lineno, "malformed line")
		end
	    end
	}
    end

    #
    #
    #
    def clear
	$dbg.msg(DBG::LOCALE, "clearing message catalogue")
	@catalog = {}
    end

    #
    # Get message associated with the 'tag'
    #
    def get(tag)
	if (str = @catalog[tag]).nil?
	    # WARN: not localized (programming error)
	    raise EntryNotFound, "Tag '#{tag}' has not been localized"
	end
	str
    end

    ## [private] #########################################################

    private
    #
    # Shortcut for formating text with line number prefixed
    #
    def fmt_line(lineno, txt)
	"Line #{lineno}: #{txt}"
    end
end
