# $Id$

# 
# AUTHOR : Stephane D'Alu <sdalu@nic.fr>
# CREATED: 2002/08/02 13:58:17
#
# $Revivion$ 
# $Date$
#
# CONTRIBUTORS:
#
#

module NResolv
    class DNS
	class Name
	    class Label
		class Ordinary < Label
		    attr_reader :downcase
		    def initialize(str)
			@string   = str.to_s.freeze
			@downcase = @string.downcase.freeze
		    end

		    def self.from_s(str)
			self.new(str.to_s.gsub(/\\\./, '.'))
		    end
		    
		    def to_s
			@string.gsub(/\./, '\.')
		    end
		  
		    def root?
			@string.empty?
		    end
		    
		    def wildcard?
			@string == "*"
		    end
		    
		    def eql?(other)
			@downcase.eql?(other.downcase)
		    end
		    alias == eql?
			
		    def hash
			@downcase.hash
		    end
		    
		    def depth
			1
		    end
		end
		Root = Label::Ordinary::new("")
	    end

	    attr_reader :labels

	    def initialize(labels, origin=nil)
		@labels = labels.dup
		if origin && (@labels.empty? || ! @labels[-1].root?)
		    origin.labels.each { |lbl| @labels << lbl }
		end
		@labels.freeze
	    end

	    def self.create(obj, make_absolute=false)
		case obj
		when Name
		    if make_absolute && !obj.absolute?
			self::new(obj.labels, Root)
		    else
			obj
		    end
		when String
		    self::from_s(obj, make_absolute)
		else
		    self::from_s(obj.to_s, make_absolute)
		end
	    end

	    def self.from_s(str, make_absolute=false)
		labels = []
		lbl = nil
		str.scan(/(?:(?:\\.|[^\.])+|\.)/) {|m| 
		    lbl = if m == "."
			      labels << Label::Ordinary::from_s(lbl ? lbl : "")
			      nil
			  else
			      m
			  end
		}
		labels << Label::Ordinary::from_s(lbl ? lbl : "")
		if make_absolute && !labels[-1].root?
		    labels << Label::Root
		end
		self.new(labels)
	    end

	    def absolute?
		@labels[-1].root?
	    end
	    alias fqdn? absolute?

	    def in_domain?(domain)
		if self.absolute? ^ domain.absolute?
		    raise ArgumentError, 
			"both name should be both absolutly qualified or not" 
		end
		return false if self.depth < domain.depth
                s_idx = self  .depth - 1
                d_idx = domain.depth - 1
                while d_idx >= 0
                    return false unless domain[d_idx] == self[s_idx]
                    d_idx -= 1
                    s_idx -= 1
                end
                return true
	    end

	    def wildcard?
		@labels[0].wildcard?
	    end

	    def to_s
		@labels.join('.')
	    end

	    def depth
		d = 0
		@labels.each { |lbl| d += lbl.depth }
		d
	    end

	    def length
		@labels.length
	    end

	    def eql?(other)
		(self.type == other.type) && (self.labels == other.labels)
	    end
	    alias == eql?

	    def [](idx)
		@labels[idx]
	    end

	    Root = Name::new([ Label::Root ])
	end
    end
end

