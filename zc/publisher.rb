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


module Formatter
    class Text
	def explanation(xpl)
	    return unless xpl
	    xpl.split(/\n/).each { |e|
		puts " | #{e}"
	    }
	    puts " \\-----"
	end
	
	def message(msg, tag=" =>")
	    return unless msg
	    lines  = msg.split(/\n/)
	    spacer = " " * (tag.length + 1)
	    
	    if !lines.empty?
		puts "#{tag} #{lines[0]}"
		lines[1..-1].each { |e|
		    puts "#{spacer} #{e}"
		}
	    end
	end

	def headline(fmt, desc)
	    printf fmt, desc
	end
	

	def fatal(answer)
	    headline($mc.get("error_fmt"), answer.tag)
	    message(answer.msg)
	    explanation(answer.explanation)
	    puts
	end

	def warning(answer)
	    headline($mc.get("fatal_fmt"), answer.tag)
	    message(answer.msg)
	    explanation(answer.explanation)
	    puts
	end
	
	def info(answer)
	    headline($mc.get("info_fmt"), answer.tag)
	    message(answer.msg)
	    puts
	end
    end
end
