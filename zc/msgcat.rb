# $Id$

# 
# AUTHOR : Stephane D'Alu <sdalu@nic.fr>
# CREATED: 2002/08/02 13:58:17
#
# $Revivion$ 
# $Date$
#
# CONTRIBUTORS:
#
#

##
## Message catalog for L10N
##
class MessageCatalog
    class EntryNotFound < StandardError
    end

    #
    def initialize(msgfile)
	@catalog = {}
	prefix   = nil

	# Read message catalogue
	File.open(msgfile) { |io|
	    while line = io.gets
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
		    msg.gsub!(/\\n/, "\n")
		    @catalog[tag] = msg

		# Link
		when /^(\w+)\s*=\s*(\w+)\s*$/
		    tag, link = $1, $2
		    tag = "#{prefix}_#{tag}" if prefix
		    @catalog[tag] = @catalog[link]
		end
	    end
	}
    end

    #
    def get(tag)
	if (str = @catalog[tag]).nil?
#	    raise EntryNotFound, "Tag '#{tag}' has not been localized"
	end
	str
    end
end
