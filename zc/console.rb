# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2003/03/17 10:54:53
#
# COPYRIGHT: AFNIC (c) 2003
# LICENSE  : GPL v2.0 (or MIT/X11-like after agreement)
# CONTACT  : zonecheck@nic.fr
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS: (see also CREDITS file)
#
#

class Console
    ##
    ## Exception: requested encoding is not possible (conversion lose)
    ##
    class EncodingError < StandardError
    end


    ##
    ##
    ##
    class IOConv
	def initialize(console, io, ctl=nil)
	    @io		= io
	    @console	= console
	end

	def puts(*args)
	    @io.puts   *args.collect { |e| @console.conv_to(e.to_s) }
	end

	def print(*args)
	    @io.print  *args.collect { |e| @console.conv_to(e.to_s) }
	end

	def printf(*args)
	    @io.printf *args.collect { |e| 
		case e
		when String then @console.conv_to(e)
		else e
		end 
	    }
	end

	def method_missing(method, *args)
	    @io.method(method).call(*args)
	end
    end


    attr_reader :stdin, :stdout, :stderr
    attr_reader :encoding
    attr_reader :ctl

    def initialize(stdin=$stdin, stdout=$stdout, stderr=$stderr)
	# Initialize conversion enconding engine
        @iconv = nil
	begin
	    require 'iconv'
	rescue LoadError => e
            @iconv = false
        end

	#
	@ctl = {
	    "ve" => "\033[?25h",		# show cursor
	    "vi" => "\033[?25l",		# hide cursor
	    "ce" => "\033[K"			# clear end of line
	}

	#
	@stdin  = IOConv::new(self, stdin)
	@stdout = IOConv::new(self, stdout, @ctl)
	@stderr = IOConv::new(self, stderr, @ctl)
    end


    def encoding=(encoding)
	return true  if @encoding == encoding	# Nothing to change
	return false if @iconv    == false	# Don't support convertion

	@iconv		= case encoding
			  when NilClass, "utf8" then nil
			  else Iconv::new(encoding, "utf8")
			  end
	@encoding	= encoding
    end

    def conv_to(msg)
	begin
	    return @iconv ? @iconv.iconv(msg) : msg
	rescue Iconv::Failure, Iconv::InvalidCharacter => e
	    raise EncodingError, "Can't do full conversion to #{@encoding}"
	end
    end
end
