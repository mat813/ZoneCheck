# $Id$

# 
# AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
# CREATED  : 2002/08/02 13:58:17
#
# COPYRIGHT: AFNIC (c) 2003
# CONTACT  : 
# LICENSE  : RUBY
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS: (see also CREDITS file)
#
#


#
# 
#
#
#
#

class NResolv
    class DNS
	class Name
	    class Label
		##
		## Ordinary DNS Label
		##  (String are not case sensitive)
		##
		class Ordinary < Label
		    attr_reader :downcase

		    def initialize(str)
			@string   = str.to_s.freeze
			@downcase = @string.downcase.freeze
			freeze
		    end

                    def data        ; @string                        ; end

		    def self.from_s(str)
			self.new(str.to_s.gsub(/\\\./, '.'))
		    end
		    def to_s        ; @downcase.gsub(/\./, '\.')     ; end
		  
		    def root?       ; @string.empty?                 ; end
		    def wildcard?   ; @string == "*"                 ; end
		    def depth       ; 1                              ; end
		    
		    def hash        ; @downcase.hash                 ; end
		    def eql?(other) ; @downcase.eql?(other.downcase) ; end
		    alias == eql?
                end
		Root = Label::Ordinary::new("")
	    end

	    attr_reader :labels

            def self.is_valid_hostname?(name)
		name.labels.each { |lbl|
		    return false unless lbl.instance_of?(Label::Ordinary)
                    return false if ((lbl =~ /^-|-$/)  || 
                                     (lbl =~ /[^A-Za-z0-9\-]/))
                }
                true
            end

            def self.is_valid_mbox_address?(name)
                return false unless name.depth > 1
                mbox  = name[0].data	# to_s would have put a '\' before '.'
                self.is_valid_hostname?(name.domain)			&&
		    (mbox !~ /[^A-Za-z0-9\._\-~\#]/)			&&
		    (mbox !~ /^\.|\.$/)
            end

	    def initialize(labels, origin=nil)
		# Sanity check
		unless labels.instance_of?(Array)
		    raise "Label Array expected as labels" 
		end
		labels.each { |lbl|
		    unless lbl.kind_of?(Label)
			raise ArgumentError, "Label Array expected as labels"
		    end
		}

		case origin
		when NilClass, Name
		else raise ArgumentError, "DNS Name expected as origin"
		end

		#
		@labels = labels.dup
		if origin && (@labels.empty? || ! @labels[-1].root?)
		    origin.labels.each { |lbl| @labels << lbl }
		end
		@labels.freeze
		freeze
	    end

	    def self.create(obj, make_absolute=false)
		case obj
		when Name
		    if make_absolute && !obj.absolute?
		    then self::new(obj.labels, Root)
		    else obj
		    end
		when String
		    begin
			obj = Address::create(obj).to_name
		    rescue Address::InvalidAddress
		    end
		    self::from_s(obj,         make_absolute)
		when Address
		    self::from_s(obj.to_name, make_absolute)
		else
		    self::from_s(obj.to_s,    make_absolute)
		end
	    end

	    def self.from_s(str, make_absolute=false)
		return Root if str == "."
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

	    def prepend(obj)
		prefix = Name::create(obj, false)
		Name::new(prefix.labels, self)
	    end

	    # XXX: not BitString ready
	    def domain(skip=1)
		_depth = depth
		return Root if (skip >= _depth)
		case @labels[0]
		when Label::Ordinary
		    Name::new(@labels[1..-1])
		else
		    raise "XXX: NOT IMPLEMENTED YET"
		end
	    end

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

	    # XXX: not BitString ready
	    def wildcard?
		@labels[0].wildcard?
	    end

	    # XXX: not BitString ready
	    def to_s
		if self == Root
		then "."
		else @labels.join('.')
		end
	    end

	    def depth
		d = 0 ; @labels.each { |lbl| d += lbl.depth } ; d
	    end

	    def length
		@labels.length
	    end

	    def hash
		h = 0 ; @labels.each { |lbl| h ^= lbl.hash } ; h
	    end

	    def eql?(other)
		(self.class == other.class) && (self.labels == other.labels)
	    end
	    alias == eql?

	    def tld
		if @labels.length < 1
		then nil
		else if @labels[-1] == Label::Root
		     then if @labels.length > 1
			  then Name::new(@labels[-2, 2])
			  else nil
			  end
		     else Name::new(@labels[-1, 1])
		     end
		end
	    end

	    # XXX: not BitString ready
	    def [](idx)
		@labels[idx]
	    end

	    Root = Name::new([ Label::Root ])
	end
    end
end
