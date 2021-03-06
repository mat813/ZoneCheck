<?xml version='1.0' encoding='UTF-8'?>
<!DOCTYPE config PUBLIC "-//ZoneCheck//DTD Config V1.0//EN" "config.dtd">
<config>
<!-- $Id$ -->

  <profile name="afnic"
           longdesc="delegation under .fr/.re done by AFNIC registry">
    <const name="registry" value="AFNIC"/>

    <!-- Minimum and maximum for SOA fields -->
    <!--  min: 0  / max: 2147483647         -->
    <const name="soa:expire:min"  value="604800"/>
    <const name="soa:expire:max"  value="60480000"/>
    <const name="soa:minimum:min" value="180"/>
    <const name="soa:minimum:max" value="604800"/>
    <const name="soa:refresh:min" value="3600"/>
    <const name="soa:refresh:max" value="172800"/>
    <const name="soa:retry:min"   value="900"/>
    <const name="soa:retry:max"   value="86400"/>

    <rules class="generic">
      <!-- Domain name check -->
      <check name="dn_sntx"     severity="f" category="dns:sntx"/>
      <check name="dn_orp_hyph" severity="f" category="dns:sntx"/>
      <check name="dn_dbl_hyph" severity="w" category="dns:sntx"/>
      <check name="one_ns"      severity="f" category="dns"/>
      <check name="several_ns"  severity="f" category="dns"/>

      <!-- IP address check -->
      <check name="ip_distinct"     severity="f" category="ip"/>
      <check name="ip_all_same_net" severity="w" category="ip"/>
    </rules>

    <rules class="nameserver">
      <!-- IP address check -->
      <check name="ip_private" severity="w" category="ip"/>
      <check name="ip_bogon"   severity="w" category="ip"/>
    </rules>


    <rules class="address">
      <!-- Connectivity -->
      <check name="icmp" severity="w" category="connectivity:l3"/>
      <check name="udp"  severity="f" category="connectivity:l4"/>
      <check name="tcp"  severity="f" category="connectivity:l4"/>

      <!-- Interoperability -->
      <check name="aaaa" severity="f" category="dns:interop"/>

      <!-- SOA -->
      <check name="soa"                       severity="f" category="dns"/>
      <check name="soa_auth"                  severity="f" category="dns"/>
      <check name="given_nsprim_vs_soa"       severity="w" category="dns"/>
      <check name="soa_master_fq"             severity="w" category="dns:soa"/>
      <check name="soa_master_sntx"           severity="f" category="dns:soa"/>
      <check name="soa_contact_sntx_at"       severity="f" category="dns:soa"/>
      <check name="soa_contact_sntx"          severity="f" category="dns:soa"/>
      <check name="soa_serial_fmt_YYYYMMDDnn" severity="w" category="dns:soa"/>
      <check name="soa_expire"                severity="f" category="dns:soa"/>
      <check name="soa_minimum"               severity="w" category="dns:soa"/>
      <check name="soa_refresh"               severity="w" category="dns:soa"/>
      <check name="soa_retry"                 severity="w" category="dns:soa"/>
      <check name="soa_retry_refresh"         severity="f" category="dns:soa"/>
      <check name="soa_expire_7refresh"       severity="f" category="dns:soa"/>
      <check name="soa_ns_cname"              severity="w" category="dns:soa"/>
      <check name="soa_vs_any"                severity="f" category="dns:soa"/>
      <check name="soa_coherence_serial"      severity="w" category="dns:soa"/>
      <check name="soa_coherence_contact"     severity="f" category="dns:soa"/>
      <check name="soa_coherence_master"      severity="f" category="dns:soa"/>
      <check name="soa_coherence"             severity="w" category="dns:soa"/>

      <!-- NS -->
      <check name="ns"                  severity="f" category="dns:ns"/>
      <check name="ns_auth"             severity="f" category="dns:ns"/>
      <check name="given_ns_vs_ns"      severity="f" category="dns"/>
      <check name="ns_sntx"             severity="f" category="dns:ns"/>
      <check name="ns_cname"            severity="f" category="dns:ns"/>
      <check name="ns_vs_any"           severity="f" category="dns:ns"/>
      <check name="ns_ip"               severity="f" category="dns:ns"/>
      <check name="ns_reverse"          severity="w" category="dns:ns"/>
      <check name="ns_matching_reverse" severity="w" category="dns:ns"/>

      <case test="mail_by_mx_or_a">
        <when value="MX">
          <check name="mx"             severity="f" category="dns:mx"/>
          <check name="mx_auth"        severity="f" category="dns:mx"/>
          <check name="mx_sntx"        severity="f" category="dns:mx"/>
          <check name="mx_cname"       severity="f" category="dns:mx"/>
          <check name="mx_no_wildcard" severity="i" category="dns:mx"/>
          <check name="mx_ip"          severity="f" category="dns:mx"/>
          <check name="mx_vs_any"      severity="f" category="dns:mx"/>
        </when>
      </case>

      <check name="correct_recursive_flag" severity="f" category="dns"/>

      <check name="not_recursive" severity="w" category="dns"/>

      <case test="recursive_server">
        <when value="true">
          <!-- Loopback -->
          <check name="loopback_delegation" severity="w" category="dns:loopback"/>
          <check name="loopback_host"       severity="w" category="dns:loopback"/>

          <!-- Root servers -->
          <check name="root_servers"             severity="f" category="dns:root"/>
          <check name="root_servers_ns_vs_icann" severity="f" category="dns:root"/>
          <check name="root_servers_ip_vs_icann" severity="w" category="dns:root"/>
        </when>
      </case>
    </rules>

    <rules class="extra">
    <!-- Mail -->
      <check name="mail_mx_or_addr" severity="w" category="mail"/>
      <case test="mail_delivery">
        <when value="nodelivery"/>
        <else>
          <check name="mail_delivery_postmaster" severity="w" category="mail:delivery"/>
        </else>
      </case>
      <check name="mail_hostmaster_mx_cname" severity="f" category="mail"/>
    </rules>
  </profile>

  <!-- Local Variables: -->
  <!-- mode: xml        -->
  <!-- End:             -->
</config>
