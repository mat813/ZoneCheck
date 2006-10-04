Ne marche pas : trop d'algorithmique a faire

Utiliser la version Python + DOM


<?xml version='1.0' encoding='ISO-8859-1'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version='1.0'>

  <xsl:output encoding="UTF-8" method="xml"/>

  <xsl:template match="profile">
    <html>
      <h1>Zonecheck profile for <xsl:value-of select="@name"/></h1>
      <p>This is the Zonecheck policy for <em><xsl:value-of select="@name"/></em> (<xsl:value-of select="@longdesc"/>).</p>
    </html>
  </xsl:template>

</xsl:stylesheet>
