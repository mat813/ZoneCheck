# $Id$

# 
# AUTHOR : Stephane D'Alu <sdalu@nic.fr>
# CREATED: 2002/08/02 13:58:17
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS:
#
#

class Array
    def unsorted_eql?(other)
	unless (self.class == other.class) && (self.size == other.size)
	    return false 
	end

	oc = other.clone
	self.each { |e|
	    return false unless i = oc.index(e)
	    oc.delete_at(i)
	}
	return oc.empty?
    end
end
