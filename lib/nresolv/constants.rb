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


##
## See RFC 2929
##
##
class NResolv
    class ValueHolder
	attr_reader :name, :value

	@@maxlen	= {}
	@@hash_by_name	= {}
	@@hash_by_value = {}

	def initialize(name, value)
	    # Sanity check
	    if ! name.instance_of?(String)
		raise ArgumentError, 'Constant name should be a String'
	    end

	    # Define attributes
	    @name  = name.frozen? ? name : name.dup.freeze
	    @value = value

	    # Store itself in class attribute hashes
	    #  so it can easily be retrieved
	    klass = self.class

	    @@hash_by_name [klass] = {} unless @@hash_by_name [klass]
	    @@hash_by_value[klass] = {} unless @@hash_by_value[klass]
	    @@maxlen[klass]        =  0 unless @@maxlen[klass] 

	    @@hash_by_name [klass][name ] = self
	    @@hash_by_value[klass][value] = self
	    @@maxlen[klass] = @name.length if @@maxlen[klass] < @name.length
	end

	def to_s
	    @name
	end

	def eql?(other)
	    (self.class == other.class) && (self.value == other.value)
	end
	alias == eql?

	def hash
	    self.value.hash
	end

	def self.fetch_by_name(name)
	    begin
		@@hash_by_name[self].fetch(name)
	    rescue IndexError
		raise IndexError, "name '#{name}' not found in #{self}"
	    end
	end
	
	def self.fetch_by_value(value)
	    begin
		@@hash_by_value[self].fetch(value)
	    rescue IndexError
		raise IndexError, "value '#{value}' not found in #{self}"
	    end
	end
	
	def self.maxlen        ; @@maxlen[self]      ; end
	def self.filler(token) ; token * self.maxlen ; end
    end


    
    class DNS
	##
	## Op. code
	##
	class OpCode < ValueHolder
	    QUERY	= OpCode::new('Query' , 0)	# RFC 1035
	    IQUERY	= OpCode::new('IQuery', 1)	# RFC 1035
	    STATUS	= OpCode::new('Status', 2)	# RFC 1035
	    NOTIFY	= OpCode::new('Notidy', 4)	# RFC 1996
	    UPDATE	= OpCode::new('Update', 5)	# RFC 2136
	end


	##
	## Return code
	##
	class RCode < ValueHolder
	    NOERROR	= RCode::new('NoError',     0)	# RFC 1035
	    FORMERR	= RCode::new('FormErr',     1)	# RFC 1035
	    SERVFAIL	= RCode::new('ServFail',    2)	# RFC 1035
	    NXDOMAIN	= RCode::new('NXDomain',    3)	# RFC 1035
	    NOTIMP	= RCode::new('NotImp',      4)	# RFC 1035
	    REFUSED	= RCode::new('Refused',     5)	# RFC 1035
	    YXDOMAIN	= RCode::new('YXDomain',    6)	# RFC 2136
	    YXRRSET	= RCode::new('YXRRSet',     7)	# RFC 2136
	    NXRRSET	= RCode::new('NXRRSet',     8)	# RFC 2136
	    NOTAUTH	= RCode::new('NotAuth',     9)	# RFC 2136
	    NOTZONE	= RCode::new('NotZone',	   10)	# RFC 2136
#	    RESERVED15	= RCode::new('Reserved15', 15)
#	    BADVERS	= RCode::new('BADVERS',    16)	# RFC 2671 (in OPT RR)
	    BADSIG	= RCode::new('BADSIG',     16)	# RFC 2845
	    BADKEY	= RCode::new('BADKEY',     17)	# RFC 2845
	    BADTIME	= RCode::new('BADTIME',    18)	# RFC 2845
	    BADMODE	= RCode::new('BADMODE',    19)	# RFC 2930
	    BADNAME	= RCode::new('BADNAME',    20)	# RFC 2930
	    BADALG	= RCode::new('BADALG',     21)	# RFC 2930
	end


	##
	## Resource class
	##
	class RClass < ValueHolder
	    IN		= RClass::new('IN',      1)
	    CHAOS	= RClass::new('CH',      3)	# Moon 1981
	    HS		= RClass::new('HS',      4)	# Dyer 1987
	    NONE	= RClass::new('NONE',  254)	# RFC 2136
	    ANY		= RClass::new('ANY',   255)	# RFC 1035
	end
	

	##
	## Resource type
	##
	class RType < ValueHolder
	    NONE	= RType::new('NONE',      0)
	    A		= RType::new('A',         1)
	    NS		= RType::new('NS',        2)
	    MD		= RType::new('MD',        3)
	    MF		= RType::new('MF',        4)
	    CNAME	= RType::new('CNAME',     5)
	    SOA		= RType::new('SOA',       6)
	    MB		= RType::new('MB',        7)
	    MG		= RType::new('MG',        8)
	    MR		= RType::new('MR',        9)
	    NULL	= RType::new('NULL',     10)
	    WKS		= RType::new('WKS',      11)
	    PTR		= RType::new('PTR',      12)
	    HINFO	= RType::new('HINFO',    13)
	    MINFO	= RType::new('MINFO',    14)
	    MX		= RType::new('MX',       15)
	    TXT		= RType::new('TXT',      16)
	    RP		= RType::new('RP',       17)
	    AFSDB	= RType::new('AFSDB',    18)
	    X25		= RType::new('X25',      19)
	    ISDN	= RType::new('ISDN',     20)
	    RT		= RType::new('RT',       21)
	    NSAP	= RType::new('NSAP',     22)
	    NSAP_PTR	= RType::new('NSAP_PTR', 23)
	    SIG		= RType::new('SIG',      24)
	    KEY		= RType::new('KEY',      25)
	    PX		= RType::new('PX',       26)
	    GPOS	= RType::new('GPOS',     27)
	    AAAA	= RType::new('AAAA',     28)
	    LOC		= RType::new('LOC',      29)
	    NXT		= RType::new('NXT',      30)
	    SRV		= RType::new('SRV',      33)
	    NAPTR	= RType::new('NAPTR',    35)
	    KX		= RType::new('KX',       36)
	    CERT	= RType::new('CERT',     37)
	    A6		= RType::new('A6',       38)
	    DNAME	= RType::new('DNAME',    39)
	    OPT		= RType::new('OPT',      41)
	    UNSPEC	= RType::new('UNSPEC',  103)
	    TKEY	= RType::new('TKEY',    249)
	    TSIG	= RType::new('TSIG',    250)
	    IXFR	= RType::new('IXFR',    251)
	    AXFR	= RType::new('AXFR',    252)
	    MAILB	= RType::new('MAILB',   253)
	    MAILA	= RType::new('MAILA',   254)
	    ANY		= RType::new('ANY',     255)
	end
    end
end
