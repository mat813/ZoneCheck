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
    class ValueHolder
	attr_reader :name, :value

	@@maxlen	= {}
	@@hash_by_name	= {}
	@@hash_by_value = {}

	def initialize(name, value)
	    klass = self.class

	    @name  = name.dup.freeze
	    @value = value

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
	    (self.type == other.type) && (self.value == other.value)
	end
	alias == eql?

	def hash
	    type.hash
	end

	def self.fetch_by_name(name)
	    @@hash_by_name[self].fetch(name)
	end
	
	def self.fetch_by_value(value)
	    @@hash_by_value[self].fetch(value)
	end
	
	def self.maxlen
	    @@maxlen[self]
	end
	
	def self.filler(token)
	    token * self.maxlen
	end
    end

    class DNS
	class OpCode < ValueHolder
	    QUERY  = OpCode::new("QUERY" , 0)
	    IQUERY = OpCode::new("IQUERY", 1)
	    STATUS = OpCode::new("STATUS", 2)
	    NOTIFY = OpCode::new("NOTIDY", 4)
	    UPDATE = OpCode::new("UPDATE", 5)
	end

	class RCode < ValueHolder
	    NOERROR  = RCode::new("NOERROR",  0)
	    FORMERR  = RCode::new("FORMERR",  1)
	    SERVFAIL = RCode::new("SERVFAIL", 2)
	    NXDOMAIN = RCode::new("NXDOMAIN", 3)
	    NOTIMP   = RCode::new("NOTIMP",   4)
	    REFUSED  = RCode::new("REFUSED",  5)
	    YXDOMAIN = RCode::new("YXDOMAIN", 6)
	    YXRRSET  = RCode::new("YXRRSET",  7)
	    NXRRSET  = RCode::new("NXRRSET",  8)
	    NOTAUTH  = RCode::new("NOTAUTH",  9)
	    NOTZONE  = RCode::new("NOTZONE", 10)
	end

	class RClass < ValueHolder
	    IN       = RClass::new("IN",      1)
	    CH       = RClass::new("CH",      2)
	    CHAOS    = RClass::new("CHAOS",   3)
	    HS       = RClass::new("HS",      4)
	    NONE     = RClass::new("NONE",  254)
	    ANY      = RClass::new("ANY",   255)
	end
	
	class RType < ValueHolder
	    NONE     = RType::new("NONE",      0)
	    A        = RType::new("A",         1)
	    NS       = RType::new("NS",        2)
	    MD       = RType::new("MD",        3)
	    MF       = RType::new("MF",        4)
	    CNAME    = RType::new("CNAME",     5)
	    SOA      = RType::new("SOA",       6)
	    MB       = RType::new("MB",        7)
	    MG       = RType::new("MG",        8)
	    MR       = RType::new("MR",        9)
	    NULL     = RType::new("NULL",     10)
	    WKS      = RType::new("WKS",      11)
	    PTR      = RType::new("PTR",      12)
	    HINFO    = RType::new("HINFO",    13)
	    MINFO    = RType::new("MINFO",    14)
	    MX       = RType::new("MX",       15)
	    TXT      = RType::new("TXT",      16)
	    RP       = RType::new("RP",       17)
	    AFSDB    = RType::new("AFSDB",    18)
	    X25      = RType::new("X25",      19)
	    ISDN     = RType::new("ISDN",     20)
	    RT       = RType::new("RT",       21)
	    NSAP     = RType::new("NSAP",     22)
	    NSAP_PTR = RType::new("NSAP_PTR", 23)
	    SIG      = RType::new("SIG",      24)
	    KEY      = RType::new("KEY",      25)
	    PX       = RType::new("PX",       26)
	    GPOS     = RType::new("GPOS",     27)
	    AAAA     = RType::new("AAAA",     28)
	    LOC      = RType::new("LOC",      29)
	    NXT      = RType::new("NXT",      30)
	    SRV      = RType::new("SRV",      33)
	    NAPTR    = RType::new("NAPTR",    35)
	    KX       = RType::new("KX",       36)
	    CERT     = RType::new("CERT",     37)
	    A6       = RType::new("A6",       38)
	    DNAME    = RType::new("DNAME",    39)
	    OPT      = RType::new("OPT",      41)
	    UNSPEC   = RType::new("UNSPEC",  103)
	    TKEY     = RType::new("TKEY",    249)
	    TSIG     = RType::new("TSIG",    250)
	    IXFR     = RType::new("IXFR",    251)
	    AXFR     = RType::new("AXFR",    252)
	    MAILB    = RType::new("MAILB",   253)
	    MAILA    = RType::new("MAILA",   254)
	    ANY      = RType::new("ANY",     255)
	end
    end
end
