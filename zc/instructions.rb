# $Id$

# 
# CONTACT     : zonecheck@nic.fr
# AUTHOR      : Stephane D'Alu <sdalu@nic.fr>
#
# CREATED     : 2002/07/19 07:28:13
# REVISION    : $Revision$ 
# DATE        : $Date$
#
# CONTRIBUTORS: (see also CREDITS file)
#
#
# LICENSE     : GPL v2 (or MIT/X11-like after agreement)
# COPYRIGHT   : AFNIC (c) 2003
#
# This file is part of ZoneCheck.
#
# ZoneCheck is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# ZoneCheck is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ZoneCheck; if not, write to the Free Software Foundation,
# Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#

require 'dbg'


##
##
##
module Instruction
    class InstructionError < StandardError
    end

    class PreevalError < InstructionError
    end


    ##
    ## Abstract Node class
    ##
    class Node
    end


    ##
    ## Instruction block
    ##
    class Block < Node
	def initialize(instr=[])
	    @instr		= instr
	end
	attr_reader :instr
	
	def [](idx)   ; @instr[idx]     ; end
	def size      ; @instr.size     ; end
	def <<(instr) ; @instr << instr ; end
	
	def validate(testmanager)
	    @instr.each { |i| i.validate(testmanager) }
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
	def initialize(checkname, severity, category)
	    @checkname		= checkname
	    @severity		= severity
	    @category		= category
	end
	attr_reader :checkname, :severity, :category
	
	def validate(testmanager)
	    unless testmanager.has_check?(@checkname)
		raise StandardError, $mc.get('config_method_unknown') % [
		    @checkname ]
	    end
	end
	
	def preeval(testmanager, args)
	    testmanager.wanted_check?(@checkname, category) ? 1 : 0;
	end
	
	def eval(testmanager, args)
	    if testmanager.wanted_check?(@checkname, category)
		testmanager.check1(@checkname, severity, *args)
	    end
	end
    end
    
    
    ##
    ## Case switch
    ##
    class Switch < Node
	def initialize(testname, when_stmt, else_stmt)
	    @testname		= testname
	    @when		= when_stmt
	    @else		= else_stmt
	end
	attr_reader :testname, :when, :else
	
	def validate(testmanager)
	    unless testmanager.has_test?(@testname)
		raise StandardError, $mc.get('config_method_unknown') % [
		    @testname ]
	    end
	    @when.each_value { |b| b.validate(testmanager) }
	    @else.validate(testmanager) if @else
	end
	
	def preeval(testmanager, args)
	    choice = testmanager.test1(@testname, false, *args)
	    raise PreevalError if choice.kind_of?(Exception)

	    $dbg.msg(DBG::TESTS) { "preeval: #{@testname} = #{choice}" }
	    block = @when[choice] || @else
	    block.nil? ? 0 : block.preeval(testmanager, args) 
	end
	
	def eval(testmanager, args)
	    choice = testmanager.test1(@testname, true, *args)
	    $dbg.msg(DBG::TESTS) {"switching to: #{@testname} = #{choice}"}
	    block = @when[choice] || @else
	    if block
		$dbg.msg(DBG::TESTS) { "leaving switch: #{@testname}" }
		block.eval(testmanager, args)
	    else
		$dbg.msg(DBG::TESTS) {
		    "switch no choice: #{@testname} = #{choice}" }
	    end
	end
    end
end
