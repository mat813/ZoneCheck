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
	class Resource
	    @@hash_resource = {}

	    def rclass
		self.class::RClass
	    end
	    
	    def rtype
		self.class::RType
	    end
	    
	    def self.rclass
		self::RClass
	    end
	    
	    def self.rtype
		self::RType
	    end

	    def self.fetch_class(rclass, rtype)
		@@hash_resource.fetch([rclass, rtype])
	    end

	    def self.add_resource(klass)
		@@hash_resource[[klass.rclass, klass.rtype]] = klass
	    end

	    def eql?(other)
		return false unless self.type == other.type
		siv = self.instance_variables
		oiv = other.instance_variables
		return false unless siv == oiv
		siv.collect {|name| self.instance_eval name } ==
		    oiv.collect {|name| other.instance_eval name}
	    end
	    alias == eql?

	    module Generic
		class CNAME < Resource
		    attr_reader :cname

		    def initialize(cname)
			@cname = cname
		    end

		    def self.from_s(str)
			self::new(DNS::Name::from_s(str))
		    end

		    def to_s
			@cname.to_s
		    end
		end

		class SOA < Resource
		    attr_reader :mname, :rname
		    attr_reader :serial, :refresh, :retry, :expire, :minimum
		    def initialize(mname, rname, 
				   serial, refresh, retry_, expire, minimum)
			@mname   = mname
			@rname   = rname
			@serial  = serial
			@refresh = refresh
			@retry   = retry_
			@expire  = expire
			@minimum = minimum
		    end
		end

		class NS < Resource
		    attr_reader :name

		    def initialize(name)
			@name = name
		    end

		    def self.from_s(str)
			self::new(DNS::Name::from_s(str))
		    end

		    def to_s
			@name.to_s
		    end
		end

		class MX < Resource
		    attr_reader :preference, :exchange
		    def initialize(preference, exchange)
			@preference = preference
			@exchange   = exchange
		    end
		end
		    
		class PTR < Resource
		    attr_reader :ptrdname
		    def initialize(ptrdname)
			@ptrdname = ptrdname
		    end
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

		    attr_reader :address
		    
		    def initialize(addr)
			@address = addr
		    end

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

		    attr_reader :address

		    def initialize(addr)
			@address = addr
		    end

		    def self.from_s(str)
			AAAA::new(Address::IPv6::create(str))
		    end

		    def to_s
			@address.to_s
		    end

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

		class ANY < Generic::ANY
		    RClass = RClass::IN
		    RType  = RType::ANY
		    add_resource(self)
		end
	    end
	end
    end
end
