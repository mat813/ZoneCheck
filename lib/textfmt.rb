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
    module Formater
        LEFT_ALIGN  = 0
        RIGHT_ALIGN = 1
        FILLED      = 2
        JUSTIFY     = 3
	MaxLineLength = 79


	#
	# Draw an L-shapped box (as below) arround the text
	#
	# | 
	# | 
	# `----- -- -- - -  -
	#
	def self.lbox(text, decoration=[ '|', '`', '-', ' ' ])
	    finalline = decoration[1] + 
		decoration[2]*5 + decoration[3] + 
		decoration[2]*2 + decoration[3] + 
		decoration[2]*2 + decoration[3] + 
		decoration[2]   + decoration[3] + 
		decoration[2]   + decoration[3]*2 + 
		decoration[2]

	    (text.split(/\n/).collect { |l| 
		 "#{decoration[0]} #{l}" } << finalline << '').join("\n")
	end

	#
	# Draw a title box as below
	#        _____________
	#      ,-------------.|
	# ~~~~ |    title    || ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	#      `-------------'
	#
	def self.title(title, maxlen=MaxLineLength)
	    txtlen = [title.length, maxlen-20].min
	    txt    = title[0..txtlen]
	    [   '       ' + '_'*(8+txtlen),
		'     ,' +  '-'*(8+txtlen) + '.|',
		'~~~~ |    '  +  txt  +  '    || ' + '~'*(maxlen-19-txtlen),
		'     `'+ '-' * (8+txtlen) + "'",
		'' ].join("\n")
	end


	#
	# Itemize a text as below
	#
	# => item1 on
	#    several lines
	# => item2
	#
	def self.item(text, bullet="=> ", offset=bullet.size)
	    lines  = text.split(/\n/)
	    spacer = " " * offset

	    ([   bullet + lines[0] ] + 
	     lines[1..-1].collect { |line| spacer + line } + 
	     ['']).join("\n")
	end

	
        def self.paragraph(text, width=78, tag='    ', style=LEFT_ALIGN)
	    out   = [ ]
            words = text.split(/\s+/)
            words.shift if words[0].empty?

            first_width = width - tag.size
            line  = words.shift
            while w = words.shift
                break unless (w.size + line.size) < (first_width - 1)
		line << ' ' << w
            end
            out << build_line(line, width, tag, style, w.nil?) unless line.nil?

            line  = w
            while w = words.shift
                if (w.size + line.size < (width - 1))
		    line << ' ' << w
                else
                    out << build_line(line, width,'', style, w.nil?) unless line.nil?
                    line = w
                end
            end
	    out << build_line(line, width, '', style, true) unless line.nil?

            out.join('')
        end


        def self.build_line(line, width, tag='', style=LEFT_ALIGN, last=false)
	    case style
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
		    then rw.replace((' ' * (ws+1)) + rw) ; spaces -= 1
		    else rw.replace((' ' * (ws)  ) + rw)
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
    end
end
