# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/07/19 07:28:13
#
# COPYRIGHT: AFNIC (c) 2003
# CONTACT  : 
# LICENSE  : RUBY
#
# $Revision$ 
# $Date$
#
# INSPIRED BY:
#   Austin Ziegler ruby version of the perl version of Text::Format
#
# CONTRIBUTORS: (see also CREDITS file)
#
#

module Text
    class Format
        LEFT_ALIGN  = 0
        RIGHT_ALIGN = 1
        FILLED      = 2
        JUSTIFY     = 3

        attr_accessor :width
        attr_accessor :tag
	attr_accessor :style

        def build_line(line, width, tag="", last=false)
	    case @style
	    when JUSTIFY
		return line if     last || line.empty?
		return line unless line =~ /\S+\s+\S+/
		spaces = width - line.size - tag.size
		words  = line.split(/(\s+)/)
		ws     = spaces / (words.size / 2)
		spaces = spaces % (words.size / 2) if ws > 0
		words.reverse.each { |rw|
		    next if rw =~ /^\S/
		    if spaces > 0
		    then rw.replace((" " * (ws+1)) + rw) ; spaces -= 1
		    else rw.replace((" " * (ws)  ) + rw)
		    end
		}
		tag + words.join('') + "\n"
	    when FILLED
		"#{tag}#{line}".ljust(width) + "\n"
	    when RIGHT_ALIGN
		"#{tag}#{line}".rjust(width) + "\n"
	    else 
		tag + line + "\n"
	    end
        end

        def format(text)
	    out   = [ ]
            words = text.split(/\s+/)
            words.shift if words[0].empty?

            first_width = @width - @tag.size
            line  = words.shift
            while w = words.shift
                break unless (w.size + line.size) < (first_width - 1)
		line << " " << w
            end
            out << build_line(line, @width, @tag, w.nil?) unless line.nil?

            line  = w
            while w = words.shift
                if (w.size + line.size < (@width - 1))
		    line << " " << w
                else
                    out << build_line(line, @width,"", w.nil?) unless line.nil?
                    line = w
                end
            end
	    out << build_line(line, @width, "", true) unless line.nil?

            out.join('')
        end

        def initialize
            @width	= 78
            @tag	= "    "
            @style	= LEFT_ALIGN
        end
    end
end
