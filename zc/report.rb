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

module Report
    class FatalError < StandardError
    end


    ##
    ## Straight interpretation of messages.
    ##
    class Straight
	def tagonly_supported? ; true ; end
	def one_supported?     ; true ; end
	
	class Processor # ABSTRACT
	    def initialize(rflag, publisher)
		@rflag		= rflag
		@publisher	= publisher
		@list		= []
	    end

	    def empty? ; @list.empty? ; end

	    def count  ; @list.length ; end

	    def add_answer(answer)
		@list << answer unless answer.ok?
	    end
	    
	    def name
		self.class.to_s =~ /([^:]+)$/
		$1
	    end

	    def one
		@list.nil? ? nil : @list.first
	    end

	    def has_unexpected?
		@list.each { |ans| return true if ans.is_unexpected? }
		false
	    end

	    def display
		nlist = @list.dup

		while ! nlist.empty?
		    tags = [ ]
		    
		    ans = nlist.shift
		    if !@rflag.tagonly
			@publisher.msg1(ans.msg) 
		    else
			if ans.is_unexpected?
			    @publisher.msg1("#{name}[Unexpected]: #{ans.testname}")
			else
			    @publisher.msg1("#{name}: #{ans.testname}")
			end
		    end
		    if @rflag.explain && !@rflag.tagonly
			@publisher.explanation(ans.explanation) 
		    end
		    tags << ans.tag

		    nlist.delete_if { |a|
			if (a.msg == ans.msg && 
			    a.explanation == ans.explanation)
			    tags << a.tag
			end
		    }
		    
		    @publisher.list(tags)
		    @publisher.vskip
		end
	    end
	end
	
	class Fatal   < Processor
	    def add_answer(answer)
		super(answer)
		raise FatalError unless answer.ok?
	    end
	end
	
	class Warning < Processor
	end
	
	class Info    < Processor
	end


	def initialize(domain, rflag, publisher)
	    @domain	= domain
	    @rflag	= rflag
	    @publisher	= publisher
	    @fatal	= Fatal::new(rflag, publisher)
	    @warning	= Warning::new(rflag, publisher)
	    @info	= Info::new(rflag, publisher)
	end

	def finish
	    if @rflag.one
		ans   = @info.one
		ans ||= @warning.one
		ans ||= @fatal.one

		
		i_tag = @rflag.tagonly ? "i" : $mc.get("i_tag")
		w_tag = @rflag.tagonly ? "w" : $mc.get("w_tag")
		f_tag = @rflag.tagonly ? "f" : $mc.get("f_tag")

		i_tag = i_tag.upcase if @info.has_unexpected?
		w_tag = w_tag.upcase if @warning.has_unexpected?
		f_tag = f_tag.upcase if @fatal.has_unexpected?


		@publisher.one(@domain.name, 
			       @info.count,
			       @warning.count,
			       @fatal.count)


#		@publisher.msg1("%-62s   %s" % [ 
#				    @param.domain.name, summary])
#		@publisher.msg1("  Warning: #{ans.tag}")
#		@publisher.msg1("  #{ans.msg}")


		return
	    end



	    @publisher.h1("Test results")
	    if ! @info.empty?
		@publisher.h2($mc.get("info")) if !@rflag.tagonly
		@info.display
	    end
	    if ! @warning.empty?
		@publisher.h2($mc.get("warning")) if !@rflag.tagonly
		@warning.display
	    end
	    if ! @fatal.empty?
		@publisher.h2($mc.get("fatal")) if !@rflag.tagonly
		@fatal.display
	    end


	    warnings = @warning.count
	    fatals   = @fatal.count
	    
	    if fatals == 0
		tag = (warnings > 0) ? "res_succeed_but" : "res_succeed"
	    else
		if ! @rflag.stop_on_fatal # XXX: bad $
		    tag = "res_failed_on"
		else
		    tag = (warnings > 0) ? "res_failed_and" : "res_failed"
		end
	    end
	    printf $mc.get(tag), warnings
	end

	attr_reader :fatal, :warning, :info
	attr_reader :param
    end
end
