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


    attr_reader :stdin, :stdout, :stderr
    attr_reader :encoding

    def intialize
	# Initialize conversion enconding engine
        @iconv = nil
	begin
	    require 'iconv'
	rescue LoadError => e
            @iconv = false
        end
    end

    def ve ; "\033[?25h" ; end		# show cursor
    def vi ; "\033[?25l" ; end		# hide cursor
    def ce ; "\033[K"    ; end		# clear end of line

    def encoding=(encoding)
	return true  if @encoding == encoding	# Nothing to change
	return false if @iconv == false		# Don't support convertion

	@iconv		= encoding.nil? ? nil : Iconv::new(@encoding, "utf8")
	@encoding	= encoding
    end

    def conv(msg)
	begin
	    return @iconv ? @iconv.iconv(msg) : msg
	rescue Iconv::Failure, Iconv::InvalidCharacter => e
	    raise EncodingError, "Can't do full conversion to #{@encoding}"
	end
    end
end
