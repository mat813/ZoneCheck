# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2003/03/27 13:16:29
#
# COPYRIGHT: AFNIC (c) 2003
# LICENSE  : RUBY
# CONTACT  : 
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS: (see also CREDITS file)
#
#


class NResolv
    ##
    ## Debugging
    ##
    class DBG
	# Debugging types
	WIRE		= 0x0002	# encoding/decoding
	TRANSPORT	= 0x0004	# raw handling of messages
	RESOLVER	= 0x0008	# resolver behaviour
	CONFIG		= 0x0010	# config

	# Tag associated with some types
	Tag = { 
	    WIRE	=> 'wire',
	    TRANSPORT	=> 'transport',
	    RESOLVER	=> 'resolver',
	    CONFIG	=> 'config'
	}
	
	# Initializer
	def initialize(lvl, output=$stderr)
	    @output = output
	    @lvl    = lvl
	end

	# Test if debug is enabled for that type
	def enabled?(type) 
	    @lvl & type != 0
	end
	alias [] enabled?
	
	# Enable debugging for the specified type
	def []=(type, enable)
	    self.level = enable ? @lvl | type : @lvl & ~type
	end
	
	# Change debugging level
	def level=(lvl)
	    case lvl
	    when String then @lvl = lvl =~ /^0x/ ? lvl.hex : lvl.to_i
	    when Fixnum then @lvl = lvl
	    else raise ArgumentError, "unable to interprete: #{lvl}"
	    end
	end
	
	#
	# Print debugging message
	# WARN: It is adviced to use a block instead of the string 
	#       second argument, as this will provide a lazy evaluation
	#
	def msg(type, str=nil)
	    return unless enabled?(type)
	    
	    unless block_given? ^ !str.nil?
		raise ArgumentError, 'either string or block should be given'
	    end
	    str = yield if block_given?
	    @output.puts "NResolv[#{Tag[type]}]: #{str}"
	end
    end

    Dbg = DBG::new($nresolv_dbg.nil? ? 0xffff: $nresolv_dbg)
end
