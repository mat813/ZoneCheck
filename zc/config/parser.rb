# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/07/19 07:28:13
#
# COPYRIGHT: AFNIC (c) 2003
# CONTACT  : zonecheck@nic.fr
# LICENSE  : GPL v2.0 (or MIT/X11-like after agreement)
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS:
#
#

require 'instructions'

##
##
##
class Config
    ##
    ##
    ##
    class Parser
	KnownParam = [ "transp", "output", "verbose", "error" ]

	def initialize(lexer)
	    @lex = lexer
	end


	def parse_cfg_specific
	    $dbg.msg(DBG::PARSER, "parsing specific")
	    constant = []
	    testseq  = { }
	    while (tk = @lex.peek) != Token::EOF
		ensure_token(tk, Token::SYMBOL)
		case tk.data
		when "constant"
		    constant = parse_section_constant
		when "testseq"
		    tag, ts = parse_section_testseq
		    testseq[tag] = ts
		else
		    raise_synerr("config_section_unknown", tk.pos, tk.data)
		end
		ensure_token(@lex.next, Token::CHAR, ";")
	    end
	    $dbg.msg(DBG::PARSER, "parsing specific done")
	    [ constant, testseq ]
    	end

	def parse_cfg_main
	    config   = {}
	    constant = nil
	    useconf  = nil

	    exists = nil

	    tk_first = @lex.peek
	    $dbg.msg(DBG::PARSER, "parsing main")
	    while (tk = @lex.peek) != Token::EOF
		ensure_token(tk, Token::SYMBOL)
		case tk.data
		when "constant"
		    exists = tk.data if constant
		    constant = parse_section_constant
		when "config"
		    cfg, tag = parse_section_config
		    if config.has_key?(tag)
			exists = tag.nil? ? tk.data : "#{tk.data} \"#{tag}\""
		    end
		    config[tag] = cfg
		when "useconf"
		    exists = tk.data if useconf
		    useconf = parse_section_useconf
		else
		    raise_synerr("config_section_unknown", tk.pos, tk.data)
		end
		ensure_token(@lex.next, Token::CHAR, ";")
		raise_synerr("config_section_exists", tk.pos, exists) if exists
	    end
	    $dbg.msg(DBG::PARSER, "parsing main done")
	    [ config, constant, useconf ]
    	end


	def parse_section_config
	    config = {}
	    tag    = nil
	    $dbg.msg(DBG::PARSER, "parsing: config section")
	    ensure_token(@lex.next, Token::SYMBOL, "config")
	    tag = @lex.next.data if @lex.peek == Token::STRING
	    ensure_token(@lex.next, Token::CHAR, "{")
	    while (@lex.peek) != [ Token::CHAR, "}" ]
		pos, name, value = parse_affectation
		if config.has_key?(name)
		    raise_synerr("config_param_exists", pos, name)
		end
		unless KnownParam.include?(name)
		    raise_synerr("config_param_unknown", pos, name)
		end
		config[name] = value
		ensure_token(@lex.next, Token::CHAR, ";")
	    end
	    ensure_token(@lex.next, Token::CHAR, "}")
	    $dbg.msg(DBG::PARSER, "parsed: config section")
	    [ config, tag ]
	end

	def parse_section_constant
	    constant = {}
	    $dbg.msg(DBG::PARSER, "parsing: constant section")
	    ensure_token(@lex.next, Token::SYMBOL, "constant")
	    ensure_token(@lex.next, Token::CHAR, "{")
	    while (@lex.peek) != [ Token::CHAR, "}" ]
		pos, name, value = parse_affectation
		if constant.has_key?(name)
		    raise_synerr("config_constant_exists", pos, name)
		end
		constant[name] = value
		ensure_token(@lex.next, Token::CHAR, ";")
	    end
	    ensure_token(@lex.next, Token::CHAR, "}")
	    $dbg.msg(DBG::PARSER, "parsed: constant section")
	    constant
	end

	def parse_section_useconf
	    map  = {}
	    $dbg.msg(DBG::PARSER, "parsing: useconf section")
	    ensure_token(@lex.next, Token::SYMBOL, "useconf")
	    ensure_token(@lex.next, Token::CHAR, "{")
	    while (@lex.peek) != [ Token::CHAR, "}" ]
		pos, name, args = parse_declaration
		case name
		when "map"
		    raise_synerr("config_wrong_arg_number", pos,
				 args.length, 2, name) if args.length != 2

		    if map.has_key?(args[0])
			raise_synerr("config_dcl_map_exists", pos, args[0])
		    end
		    map[args[0]] = args[1].untaint
		else
		    raise_synerr("config_dcl_unknown", pos, name)
		end
		ensure_token(@lex.next, Token::CHAR, ";")
	    end
	    ensure_token(@lex.next, Token::CHAR, "}")
	    $dbg.msg(DBG::PARSER, "parsed: useconf section")
	    map
	end


	def parse_section_testseq
	    $dbg.msg(DBG::PARSER, "parsing: testseq section")
	    ensure_token(@lex.next, Token::SYMBOL, "testseq")
	    ensure_token(@lex.peek, Token::STRING)
	    tk_tag = @lex.next
	    ensure_token(@lex.next, Token::CHAR, "{")
	    testseq = parse_check_block
	    ensure_token(@lex.next, Token::CHAR, "}")
	    tag = case tk_tag.data
		  when "generic"	then CheckGeneric
		  when "nameserver"	then CheckNameServer
		  when "address" 	then CheckNetworkAddress
		  when "extra"  	then CheckExtra
		  else
		  end
	    $dbg.msg(DBG::PARSER, "parsed: testseq section")
	    [ tag, testseq ]
	end



	def parse_affectation
	    $dbg.msg(DBG::PARSER, "parsing: affectation")
	    tk = @lex.token(3)
	    ensure_token(tk[0], Token::SYMBOL, nil, "config_expect_constname")
	    ensure_token(tk[1], Token::CHAR, "=")
	    ensure_token(tk[2], Token::STRING, nil, "config_expect_value")
	    $dbg.msg(DBG::PARSER, "parsed: affectation #{tk[0]} = #{tk[2]}")
	    [ tk[0].pos, tk[0].data, tk[2].data.untaint ]
	end

	def parse_declaration
	    $dbg.msg(DBG::PARSER, "parsing: declaration")
	    tk_sym = @lex.next
	    args = []
	    ensure_token(tk_sym, Token::SYMBOL);
	    while (tk = @lex.peek) != [ Token::CHAR, ";" ]
		ensure_token(tk, Token::STRING)
		args << @lex.next.data
	    end
	    $dbg.msg(DBG::PARSER, "parsed: declaration #{tk_sym}")
	    [ tk_sym.pos, tk_sym.data, args ]
	end



	def parse_check
	    $dbg.msg(DBG::PARSER, "parsing: check")
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
	    $dbg.msg(DBG::PARSER, "parsed: check #{tk[0]}(#{tk[1]},#{tk[2]})")
	    Instruction::Node::Check::new(tk[0].data, tk[1].data, tk[2].data)
	end

	def parse_check_block
	    $dbg.msg(DBG::PARSER, "parsing: test block")
	    is_ok	= true
	    items	= []
	    tk_first	= @lex.peek
	    while is_ok
		tk = @lex.peek
		if tk == Token::SYMBOL
		    items << parse_check
		    ensure_token(@lex.next, Token::CHAR, ";")
		elsif tk == [ Token::KEYWORD, Token::KW_case ]
		    items << parse_switch
		else is_ok = false
		end
	    end
	    $dbg.msg(DBG::PARSER, "parsed: test block")
	    Instruction::Node::Block::new(items)
	end




	def parse_switch
	    else_stmt = nil
	    when_stmt = {}

	    $dbg.msg(DBG::PARSER, "parsing: switch")



	    tk_first = @lex.peek

	    ensure_token(@lex.next, Token::KEYWORD, Token::KW_case)

	    tk_test = @lex.next
	    ensure_token(tk_test, Token::SYMBOL)

	    while (tk = @lex.peek) != [ Token::KEYWORD, Token::KW_end ]
		if    tk == [ Token::KEYWORD, Token::KW_when ]
		    @lex.next
		    ensure_token(@lex.peek, Token::SYMBOL)
		    tk_cond = @lex.next
		    when_stmt[tk_cond.data] = parse_check_block
		elsif tk == [ Token::KEYWORD, Token::KW_else ]
		    @lex.next
		    else_stmt = parse_check_block
		else

		end
	    end
	    @lex.next
	    $dbg.msg(DBG::PARSER, "parsed: switch")
	    Instruction::Node::Switch::new(tk_test.data, when_stmt, else_stmt)
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

	def raise_synerr(tag, pos, *args)
	    raise SyntaxError::new($mc.get(tag) % args, pos)
	end
    end
end
