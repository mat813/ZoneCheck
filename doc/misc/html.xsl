<?xml version='1.0' encoding="utf-8"?>
<xsl:stylesheet  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"  
                 version="1.0">
  
  <xsl:import href="/html/docbook.xsl"/>

  <xsl:param name="html.stylesheet"            select="'docbook.css'"/>
  <xsl:param name="shade.verbatim"             select="1"/>
  <xsl:param name="use.id.as.filename"         select="0"/>
  <xsl:param name="suppress.navigation"        select="1"/>
  <xsl:param name="chunk.tocs.and.lots"        select="1"/>
  <xsl:param name="generate.section.toc.level" select="0"/>
</xsl:stylesheet>
