# $Id$

# 
# AUTHOR : Stephane D'Alu <sdalu@nic.fr>
# CREATED: 2002/07/19 07:28:13
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS:
#
#

class Config
    ##
    ##
    ##
    class Lexer
	##
	##
	##
	class LexicalError < StandardError
	end

	
	def initialize(io)
	    @io     = io
	    @tokens = []
	    @x = @y = 0
	    fetch_tokens
	end

	# Retrieve 'count' tokens
	def token(count=1)
	    tokens = []
	    while count > 0
		tokens << self.next
		count -= 1
	    end
	    tokens
	end

	# Consume current token
	def next
	    return @tokens[-1] if @tokens[-1].type == Token::EOF
	    tk = @tokens.pop
	    fetch_tokens if @tokens.empty?
	    tk
	end

	# Take a look at the token burried at 'depth'
	def peek(depth=0)
	    fetch_tokens(depth)
	    return @tokens[0] if depth+1 > @tokens.size
	    return @tokens[-(1+depth)]
	end

	# Put token back in the queue
	def push(arg)
	    case arg
	    when Array then arg.each { |t| push(t) }
	    else	    @tokens.unshift(arg)
	    end
	end


	private
	def fetch_tokens(depth=0)
	    while @tokens.size < depth+1
		# Stream is empty?
		return if !@tokens.empty? && (@tokens[0].type == Token::EOF)

		# Fetch new line
		line = @io.gets
		@y += 1
		@x  = 0

		# End of stream?
		if line.nil?
		    @tokens << Token::new(Token::EOF, nil, @x, @y)
		    return
		end
		
		# Tokenize the whole line.
		while line && !line.empty?
		    info = case line
			   when /^(#{Token::KW_case}    |
                                   #{Token::KW_when}    |
                                   #{Token::KW_else}    |
                                   #{Token::KW_end})(?=\W)/x
			       [ $&, $', Token::KEYWORD, $1 ] #'
			   when /^(\w+)/
			       [ $&, $', Token::SYMBOL, $1 ] #'
			   when /^\"((?:[^\\\"]|\\[\"\\])*)\"/
			       r = [ $&, $', Token::STRING, $1 ] #'
			       r[3].gsub!(/\\\"/, "\"")
			       r[3].gsub!(/\\\\/, "\\")
			       r
			   when /^\'((?:[^\']*))\'/
			       [ $&, $', Token::STRING, $1 ] #'
			   when /^([\[\]\{\}=;])/
			       [ $&, $', Token::CHAR, $1 ] #'
			   when /^\s+/
			       [ $&, $', nil ] #'
			   when /^\#.*/
			       [ $&, $', nil ] #'
			   else 
			       raise LexicalError, 
				   "Unexpected character [%i,%i] `%c'" % [ @x, @y, line[0] ]
			   end
		    if info[2]
			@tokens.unshift(Token::new(info[2], info[3], @x, @y))
		    end
		    @x   += info[0].size
		    line  = info[1]
		end
	    end
	end
    end

end
