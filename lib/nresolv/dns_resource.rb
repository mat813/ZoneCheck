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


class NResolv
    class DNS
	class Resource # --> Abstract <--
	    @@hash_resource = {}

	    # Constant shortcut
	    def rclass      ; self.class::RClass             ; end
	    def rtype       ; self.class::RType              ; end
	    def rdesc       ; "#{rclass}/#{rtype}"           ; end
	    def self.rclass ; self::RClass                   ; end
	    def self.rtype  ; self::RType                    ; end
	    def self.rdesc  ; "#{self.rclass}/#{self.rtype}" ; end

	    def self.fetch_class(rclass, rtype)
		begin
		    @@hash_resource.fetch([rclass, rtype])
		rescue IndexError
		    raise IndexError, "unimplemented record #{rclass}/#{rtype}"
		end
	    end

	    def self.add_resource(klass)
		@@hash_resource[[klass.rclass, klass.rtype]] = klass
	    end

	    def _fields
		self.class.class_eval('@@fields').collect { |field|
		    [ field, instance_variable_get("@#{field.id2name}") ] }
	    end

	    def self.has_fields(*attrs)
		# add fields to the list
		class_eval <<-EOS
		@@fields ||= [ ]
		attrs.each { |attr|
		    if @@fields.include?(attr)
			raise "field \#{attr} already present"
		    end
		    @@fields << attr
		}
		EOS

		# (re)create attribute reader and initializer
		initializer_args = []
		initializer_body = []
		all_attrs = class_eval '@@fields'
		all_attrs.each_index { |index| attr = all_attrs[index]
		    initializer_args << "_res_#{index}"
		    initializer_body << "@#{attr} = _res_#{index}"

		    class_eval "attr_reader :#{attr}"
		}

		class_eval <<-EOS
		def _res_initializer(#{initializer_args.join(', ')})
		    #{initializer_body.join('; ')}
		end
	        alias initialize _res_initializer
	        private :_res_initializer
		EOS
	    end

	    def eql?(other)
		return false unless self.class == other.class
		self._fields == other._fields
	    end
	    alias == eql?

	    module Generic
		class TXT < Resource
		    has_fields :txtdata
		end

		class CNAME < Resource
		    has_fields :cname
		end

		class SOA < Resource
		    has_fields :mname,  :rname
		    has_fields :serial, :refresh, :retry, :expire, :minimum
		end

		class NS < Resource
		    has_fields :name
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

		class LOC < Resource
		    has_fields :version
		    has_fields :size, :horizpre, :vertpre
		    has_fields :latitude, :longitude, :altitude
		end

		class AXFR < Resource
		    has_fields # none
		    def initialize
			raise "#{self.class} can't be instanciated"
		    end
		end

		class ANY < Resource
		    has_fields # none
		    def initialize
			raise "#{self.class} can't be instanciated"
		    end
		end
	    end
	    
	    


	    module IN
		# Add all the generic resources
		Generic.constants.each { |name|
		    next unless Generic.const_get(name).class == Class
		    module_eval <<-EOS
		    class #{name} < Generic::#{name}
		        RClass, RType = RClass::IN, RType::#{name}
			add_resource(self)
		    end
		    EOS
		}

		class A < Resource
		    RClass, RType = RClass::IN, RType::A
		    has_fields :address
		    add_resource(self)
		end

		class AAAA < Resource
		    RClass, RType = RClass::IN, RType::AAAA
		    has_fields :address
		    add_resource(self)
		end
	    end
	end
    end
end
