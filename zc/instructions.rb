# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/07/19 07:28:13
#
# COPYRIGHT: AFNIC (c) 2003
# LICENSE  : GPL v2.0 (or MIT/X11-like after agreement)
# CONTACT  : zonecheck@nic.fr
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS:
#
#

require 'dbg'


##
##
##
module Instruction
    class InstructionError < StandardError
    end

    class Node
	##
	## Block
	##
	class Block < Node
	    def initialize(instr=[])
		@instr		= instr
	    end
	    attr_reader :instr

	    def [](idx)   ; @instr[idx]     ; end
	    def size      ; @instr.size     ; end
	    def <<(instr) ; @instr << instr ; end

	    def semcheck(testmanager)
		@instr.each { |i| i.semcheck(testmanager) }
	    end

	    def preeval(testmanager, args)
		count = 0
		@instr.each { |i| count += i.preeval(testmanager, args) }
		count
	    end

	    def eval(testmanager, args)
		@instr.each { |i| i.eval(testmanager, args) }
	    end
	end


	##
	## Check
	##
	class Check < Node
	    def initialize(name, severity, category)
		@name		= name
		@severity	= severity
		@category	= category
	    end
	    attr_reader :name, :severity, :category

	    def semcheck(testmanager)
		unless testmanager.has_check?(@name)
		    raise StandardError, $mc.get("config_method_unknown") % [
			@name ]
		end
	    end

	    def preeval(testmanager, args)
		testmanager.wanted_check?(name, category) ? 1 : 0;
	    end

	    def eval(testmanager, args)
		if testmanager.wanted_check?(name, category)
		    testmanager.check1(name, severity, *args)
		end
	    end
	end


	##
	## Switch
	##
	class Switch < Node
	    def initialize(testname, when_stmt, else_stmt)
		@testname	= testname
		@when		= when_stmt
		@else		= else_stmt
	    end
	    attr_reader :testname, :when, :else

	    def semcheck(testmanager)
		unless testmanager.has_test?(@testname)
		    raise StandardError, $mc.get("config_method_unknown") % [
			@testname ]
		end
		@when.each_value { |b| b.semcheck(testmanager) }
		@else.semcheck(testmanager) if @else
	    end

	    def preeval(testmanager, args)
		choice = testmanager.test1(testname, *args)
		$dbg.msg(DBG::TESTS, "preeval: #{testname} = #{choice}")
		block = @when[choice] || @else
		block.nil? ? 0 : block.preeval(testmanager, args) 
	    end

	    def eval(testmanager, args)
		choice = testmanager.test1(testname, *args)
		$dbg.msg(DBG::TESTS, "switching to: #{testname} = #{choice}")
		block = @when[choice] || @else
		if block
		    $dbg.msg(DBG::TESTS, "leaving switch: #{testname}")
		    block.eval(testmanager, args)
		else
		    $dbg.msg(DBG::TESTS, 
			     "switch no choice: #{testname} = #{choice}")
		end
	    end
	end
    end
end
