# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/08/02 13:58:17
#
# COPYRIGHT: AFNIC (c) 2003
# CONTACT  : zonecheck@nic.fr
# LICENSE  : GPL v2.0 (or MIT/X11-like after agreement)
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS: (see also CREDITS file)
#
#


require 'thread'


module Publisher
    ##
    ##
    ##
    class Template # --> ABSTRACT <--
	attr_reader :progress
	attr_reader :rflag

	def initialize(rflag, ostream=$stdout)
	    @rflag	= rflag
	    @o		= ostream
	    @mutex	= Mutex::new
	end

	def output ; @o ; end

	def synchronize(&block)
	    @mutex.synchronize(&block)
	end

	def setup(domain_name)
	end

	def status(domainname, i_count, w_count, f_count)
	    if f_count == 0
		tag = (w_count > 0) ? "res_succeed_but" : "res_succeed"
	    else
		if ! @rflag.stop_on_fatal # XXX: bad $
		    tag = "res_failed_on"
		else
		    tag = (w_count > 0) ? "res_failed_and" : "res_failed"
		end
	    end
	    $mc.get(tag) % [ w_count ]
	end

	def begin ; end
	def end   ; end

	protected
	def xpl_split(xpl)
	    return nil if xpl.nil?
	    xpl_lst = [ ]
	    xpl_elt = nil
	    xpl.split(/\n/).each { |e|
		if e =~ /^\[(\w+)\]:\s*/
		    xpl_elt     = [ $1, $', [] ]	#' <-- emacs
		    xpl_lst << xpl_elt
		else
		    xpl_elt[2] << e
		end
	    }
	    xpl_lst
	end
    end
end
