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

    ##
    ##
    ##
class Config
    class Parser
	##
	##
	##
	class SyntaxError < StandardError
	    def initialize(string=nil, tk=nil)
		super(string) if string
		@token  = tk
	    end
	    
	    def at ; @token ; end
	end

	def initialize(lexer)
	    @lex = lexer
	end



	def parse_cfg_specific
	    $dbg.msg(DBG::CONFIG, "parsing specific")
	    constant = []
	    testseq  = []
	    while (tk = @lex.peek) != Token::EOF
		if  ((tk == Token::SYMBOL) ||
		     (tk == [ Token::KEYWORD, Token::KW_const ]))
		    constant << parse_constant
		elsif tk == [ Token::KEYWORD, Token::KW_testseq ]
		    testseq << parse_testseq
		else 
		    raise_synerr("expect_cfg_specific", tk.pos)
		end
		ensure_token(@lex.next, Token::CHAR, ";")
	    end
	    $dbg.msg(DBG::CONFIG, "parsing specific done")
    	end

	def parse_cfg_main
	    $dbg.msg(DBG::CONFIG, "parsing main")
	    constant = []
	    useconf  = []
	    while (tk = @lex.peek) != Token::EOF
		if  ((tk == Token::SYMBOL) ||
		     (tk == [ Token::KEYWORD, Token::KW_const ]))
		    constant << parse_constant
		elsif tk == [ Token::KEYWORD, Token::KW_useconf ]
		    useconf << parse_useconf
		else
		    raise_synerr("expect_cfg_main", tk.pos)
		end
		ensure_token(@lex.next, Token::CHAR, ";")
	    end
	    $dbg.msg(DBG::CONFIG, "parsing main done")
	    Node::CfgMain::new(nil, constant, useconf)
    	end

	def parse_useconf
	    $dbg.msg(DBG::CONFIG, "parsing: useconf")
	    tk = @lex.token(3)
	    ensure_token(tk[0], Token::KEYWORD, Token::KW_useconf)
	    ensure_token(tk[1], Token::STRING, nil, "config_expect_domain")
	    ensure_token(tk[1], Token::STRING, nil, "config_expect_filename")
	    $dbg.msg(DBG::CONFIG, "parsed: useconf #{tk[1]} #{tk[2]}")
	    Node::Useconf::new(tk[0].pos, tk[1].data, tk[2].data.untaint)
	end

	def parse_constant
	    $dbg.msg(DBG::CONFIG, "parsing: const")
	    @lex.next if @lex.peek == [ Token::KEYWORD, Token::KW_const ]
	    tk = @lex.token(3)
	    ensure_token(tk[0], Token::SYMBOL, nil, "config_expect_constname")
	    ensure_token(tk[1], Token::CHAR, "=")
	    ensure_token(tk[2], Token::STRING, nil, "config_expect_value")
	    $dbg.msg(DBG::CONFIG, "parsed: const #{tk[0]} = #{tk[2]}")
	    Node::Const::new(tk[0].pos, tk[0].data, tk[2].data.untaint)
	end

	def parse_check
	    $dbg.msg(DBG::CONFIG, "parsing: check")
	    tk = @lex.token(3)
	    if (tk[0] != Token::SYMBOL) || (tk[0].data.index("chk_") != 0)
		raise_synerr("config_expect_checkname", tk[0].pos)
	    end
	    if (tk[1] != Token::SYMBOL) || 
	       case tk[1].data
	       when Warning, Fatal, Info, Skip then false
	       else true
	       end
		raise_synerr("config_expect_severity_level", tk[1].pos)
	    end
	    if tk[2] != Token::SYMBOL
		raise_synerr("config_expect_category", tk[2].pos)
	    end
	    $dbg.msg(DBG::CONFIG, "parsed: check #{tk[0]}(#{tk[1]},#{tk[2]})")
	    Node::Check::new(tk[0].pos, tk[0].data, tk[1].data, tk[2].data)
	end

	def parse_testseq
	    $dbg.msg(DBG::CONFIG, "parsing: testseq")
	    tk_first = @lex.peek
	    ensure_token(@lex.next, Token::KEYWORD, Token::KW_testseq)
	    ensure_token(@lex.next, Token::CHAR, "[")
	    tk_type = @lex.next
	    if (tk_type != Token::SYMBOL) ||
	       case tk_type.data
	       when T_Generic, T_Extra, T_Nameserver, T_Address then false
	       else true
	       end
		raise_synerr("config_expect_testtype", tk_type.pos)
	    end
	    ensure_token(@lex.next, Token::CHAR, "]")
	    ensure_token(@lex.next, Token::CHAR, "{")
	    n_tb = parse_test_block
	    ensure_token(@lex.next, Token::CHAR, "}")
	    $dbg.msg(DBG::CONFIG, "parsing: testseq[#{tk_type}]")
	    Node::Testseq::new(tk_first.pos, tk_type.data, n_tb)
	end

	def parse_test_block
	    $dbg.msg(DBG::CONFIG, "parsing: test block")
	    is_ok	= true
	    instruction	= []
	    tk_first	= @lex.peek
	    while is_ok
		tk = @lex.peek
		if tk == Token::SYMBOL
		    instruction << parse_check
		    ensure_token(@lex.next, Token::CHAR, ";")
		elsif tk == [ Token::KEYWORD, Token::KW_case ]
		    instruction << parse_switch
		else is_ok = false
		end
	    end
	    $dbg.msg(DBG::CONFIG, "parsed: test block")
	    Node::Block::new(tk_first.pos, instruction)
	end




	def parse_switch
	    $dbg.msg(DBG::CONFIG, "parsing: switch")
	    tk_first = @lex.peek

	    ensure_token(@lex.next, Token::KEYWORD, Token::KW_case)

	    tk_test = @lex.next
	    ensure_token(tk_test, Token::SYMBOL)

	    while (tk = @lex.peek) != [ Token::KEYWORD, Token::KW_end ]
		if    tk == [ Token::KEYWORD, Token::KW_when ]
		    @lex.next
		    @lex.next
		    parse_test_block
		elsif tk == [ Token::KEYWORD, Token::KW_else ]
		    @lex.next
		    parse_test_block
		else

		end
	    end
	    @lex.next
	end


	def ensure_token(tk, type, data=nil, tag=nil)
	    return if tk == if data.nil?
			    then type
			    else [ type, data ]
			    end

	    raise_synerr(tag, tk.pos) if tag

	    l10n_msg = case type
		       when Token::KEYWORD
			   $mc.get("config_expect_keyword") % [ data ]
		       when Token::CHAR 
			   $mc.get("config_expect_token") % [ data ]
		       when Token::STRING
			   $mc.get("config_expect_string")
		       when Token::SYMBOL
			   $mc.get("config_expect_symbol")
		       else
			   raise RuntimeError
		       end
	    raise  SyntaxError::new(l10n_msg, tk.pos)
	end

	def raise_synerr(tag, pos)
	    raise SyntaxError::new($mc.get(tag), pos)
	end
    end
end
