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
# CONTRIBUTORS:
#
#


module NResolv
    class DNS
	class Resource
	    @@hash_resource = {}

	    # Constant shortcut
	    def rclass      ; self.class::RClass ; end
	    def rtype       ; self.class::RType  ; end
	    def self.rclass ; self::RClass       ; end
	    def self.rtype  ; self::RType        ; end


	    def self.fetch_class(rclass, rtype)
		@@hash_resource.fetch([rclass, rtype])
	    end

	    def self.add_resource(klass)
		@@hash_resource[[klass.rclass, klass.rtype]] = klass
	    end

	    def self.has_fields(*attrs)
		initializer_args = []
		initializer_body = []

		attrs.each_index { |index| attr = attrs[index]
		    initializer_args << "_res_#{index}"
		    initializer_body << "@#{attr} = _res_#{index}"

		    class_eval "attr_reader :#{attr}"
		}

		class_eval <<-EOS
		def _res_initializer(#{initializer_args.join(", ")})
		    #{initializer_body.join("; ")}
		end
	        alias initialize _res_initializer
	        private :_res_initializer
		EOS
	    end

#	    def self.build_resource(klass, rtype)
#		klass =~ /::([^:]+)/
#		puts "class #{r
#		puts klass
#	    end

	    def eql?(other)
		return false unless self.class == other.class
		siv = self.instance_variables
		oiv = other.instance_variables
		return false unless siv == oiv
		siv.collect {|name| self.instance_eval name } ==
		    oiv.collect {|name| other.instance_eval name}
	    end
	    alias == eql?

	    module Generic
		class TXT < Resource
		    has_fields :txtdata

		    def self::from_s(str)
			self::new(str)
		    end

		    def to_s
			@txtdata
		    end
		end

		class CNAME < Resource
		    has_fields :cname

		    def self.from_s(str)
			self::new(DNS::Name::from_s(str))
		    end

		    def to_s
			@cname.to_s
		    end
		end

		class SOA < Resource
		    has_fields :mname, :rname, :serial, :refresh, :retry, :expire, :minimum
		end

		class NS < Resource
		    has_fields :name

		    def self.from_s(str)
			self::new(DNS::Name::from_s(str))
		    end

		    def to_s
			@name.to_s
		    end
		end

		class MX < Resource
		    has_fields :preference, :exchange
		end
		    
		class PTR < Resource
		    has_fields :ptrdname
		end

		class RP < Resource
		    has_fields :mailbox, :txtdname
		end

		class HINFO < Resource
		    has_fields :cpu, :os
		end

		class ANY < Resource
		    def initialize
			raise RuntimeError, 
			    "#{self.class} can't be instanciated"
		    end
		end
	    end
	    
	    


	    module IN
		class A < Resource
		    RClass = RClass::IN
		    RType  = RType::A

		    has_fields :address
		    
		    def self.from_s(str)
			A::new(Address::IPv4::create(str))
		    end

		    def to_s
			@address.to_s
		    end

		    add_resource(self)
		end

		class AAAA < Resource
		    RClass = RClass::IN
		    RType  = RType::AAAA

		    has_fields :address

		    def self.from_s(str)
			AAAA::new(Address::IPv6::create(str))
		    end

		    def to_s
			@address.to_s
		    end

		    add_resource(self)
		end
		
		class TXT < Generic::TXT
		    RClass = RClass::IN
		    RType  = RType::TXT
		    add_resource(self)
		end

		class NS < Generic::NS
		    RClass = RClass::IN
		    RType  = RType::NS
		    add_resource(self)
		end    


		class MX < Generic::MX
		    RClass = RClass::IN
		    RType  = RType::MX
		    add_resource(self)
		end    

		class SOA < Generic::SOA
		    RClass = RClass::IN
		    RType  = RType::SOA
		    add_resource(self)
		end

		class CNAME < Generic::CNAME
		    RClass = RClass::IN
		    RType  = RType::CNAME
		    add_resource(self)
		end

		class PTR < Generic::PTR
		    RClass = RClass::IN
		    RType  = RType::PTR
		    add_resource(self)
		end

		class RP < Generic::RP
		    RClass = RClass::IN
		    RType  = RType::RP
		    add_resource(self)
		end

		class HINFO < Generic::HINFO
		    RClass = RClass::IN
		    RType  = RType::HINFO
		    add_resource(self)
		end

		class ANY < Generic::ANY
		    RClass = RClass::IN
		    RType  = RType::ANY
		    add_resource(self)
		end
	    end
	end
    end
end
