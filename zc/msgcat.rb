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
## line   : '#' comment              # a comment
##        | tag ':' definition       # a tag definition
##        | tag '=' tag              # a link to another tag
##        | '[' prefix ']'           # a prefic to append to other tags
##
## prefix : tag                      # the tag to use as prefix
##        | '*'                      # don't use a prefix
##
## tag    : [a-zA-Z0-9_]
##
class MessageCatalog
    ##
    ## Syntax error, while parsing the file
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
    def initialize(msgfile)
	@catalog = {}
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

		# Definition
		when /^(\w+)\s*:\s*(.*?)\s*$/
		    tag, msg = $1, $2
		    tag = "#{prefix}_#{tag}" if prefix
		    while msg.gsub!(/\\$/, "")
			if (line = io.gets).nil?
			    raise SyntaxError, 
				"New line expected after continuation mark"
			end
			lineno += 1
			line.chomp!
			msg << line
		    end

		    msg.gsub!(/\\n/, "\n")
		    @catalog[tag] = msg

		# Link
		when /^(\w+)\s*=\s*(\w+)\s*$/
		    tag, link = $1, $2
		    tag = "#{prefix}_#{tag}" if prefix
		    @catalog[tag] = @catalog[link]

		else
		    raise SyntaxError, "#{lineno}: Unexpected token"
		end
	    end
	}
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
