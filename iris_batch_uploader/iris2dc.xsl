<xsl:stylesheet version="1.0" 
	  xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
	  xmlns:xsd="http://www.w3.org/2001/XMLSchema"
	  xmlns:dcterms="http://purl.org/dc/terms/" 
	  xmlns:dc="http://purl.org/dc/elements/1.1/"  
	  xmlns:str="http://exslt.org/strings"
	  xmlns:xlink="http://www.w3.org/1999/xlink" 
	  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
	  xmlns:iris="http://iris-database.org/iris"
	  xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/"
	  exclude-result-prefixes="iris xsi xlink dcterms xsd">

  <xsl:strip-space elements="*"/>

  <xsl:output method="xml" indent="yes"/>

  <xsl:variable name="commonsDoc" select="document('/var/lib/tomcat6/webapps/iris/Content/xml/datadictionary/commons.xml', /)"/>

  <xsl:template match="/">
	<oai_dc:dc xmlns:dc="http://purl.org/dc/elements/1.1/"
			xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/">
      <xsl:call-template name="title"/>
      <xsl:call-template name="creator"/>
      <xsl:call-template name="subject"/>
      <xsl:call-template name="description"/>
      <!--<xsl:call-template name="publisher"/>-->
      <xsl:call-template name="date"/>
      <xsl:call-template name="type"/>
	    <!--<xsl:call-template name="format"/>-->
      <xsl:call-template name="identifier"/>
      <xsl:call-template name="source"/>
      <xsl:call-template name="language"/>
      <xsl:call-template name="relation"/>
      <!--<xsl:call-template name="coverage"/>-->
      <xsl:call-template name="rights"/>
      <!--xsl:call-template name="dcterms"/-->
    </oai_dc:dc>
  </xsl:template>
  
  <xsl:template name="title">
    <xsl:if test="/iris:iris/iris:instrument/iris:title!=''">
    	<dc:title><xsl:value-of select="/iris:iris/iris:instrument/iris:title"/></dc:title>
    </xsl:if>  
  </xsl:template>
  
  <xsl:template name="creator">
    <xsl:for-each select="/iris:iris/iris:instrument/iris:creator/iris:fullName[.!='']">
      <dc:creator><xsl:value-of select="."/></dc:creator>
    </xsl:for-each>
  </xsl:template>
  
  <xsl:template name="subject">
     <xsl:for-each select="/iris:iris/iris:instrument/iris:researchArea[.!='']">
       <xsl:variable name="newValue" select="@newValue"/>
       <xsl:if test="string(normalize-space(text()))">
         <xsl:variable name="currentValue" select="."/>
         <dc:subject>
           <xsl:if test=".!='999'">
             <xsl:value-of select="$commonsDoc/IRIS_Data_Dict/instrument/researchAreas//researchArea/@label[../@value=$currentValue]"/>
           </xsl:if>
           <xsl:if test=".='999'">
             <xsl:value-of select="$newValue"/>
           </xsl:if>
         </dc:subject>
       </xsl:if>
     </xsl:for-each>
  </xsl:template>

  <xsl:template name="description">
    <xsl:for-each select="/iris:iris/iris:instrument/iris:notes[.!='']">
       <dc:description><xsl:value-of select="."/></dc:description>
    </xsl:for-each>
  </xsl:template>
  
  <xsl:template name="publisher"/>
  
  <xsl:template name="date">
    <xsl:for-each select="/iris:iris/iris:relatedItems/iris:relatedItem/iris:yearOfPublication[.!='']">
      <dc:date><xsl:value-of select="."/></dc:date>
    </xsl:for-each>
  </xsl:template>
  
  <xsl:template name="type">
    <xsl:for-each select="/iris:iris/iris:instrument/iris:instrumentType[.!='']">
      <xsl:variable name="newType" select="@newValue"/>
      <xsl:for-each select="str:tokenize(.,' ')">
        <xsl:variable name="currentValue" select="."/>
        <xsl:if test="string(normalize-space(text()))">
          <dc:type>
            <xsl:if test=".!='999' and .!=''">
              <xsl:value-of select="$commonsDoc/IRIS_Data_Dict/instrument/typeOfInstruments//type/@def[../@value=$currentValue]"/>
            </xsl:if>
            <xsl:if test=".='999' and $newType!=''">
              <xsl:value-of select="$newType"/>
            </xsl:if>
          </dc:type>
        </xsl:if>
      </xsl:for-each> 
    </xsl:for-each>
    <dc:type>http://www.iris-database.org/Instruments</dc:type>
  </xsl:template>
  
  <xsl:template name="format">
    <xsl:for-each select="/iris:iris/iris:instrument/iris:format[.!='']">
        <dc:format><xsl:value-of select="."/></dc:format>
      </xsl:for-each>  
  </xsl:template>
  
  <xsl:template name="identifier">
  </xsl:template>
  
  <xsl:template name="source">
  </xsl:template>
  
  <xsl:template name="language">
    <xsl:for-each select="/iris:iris/iris:instrument/iris:sourceLanguage[.!='']">
      <dc:format><xsl:value-of select="."/></dc:format>
    </xsl:for-each> 
  </xsl:template>
    
  <xsl:template name="relation">
  </xsl:template>
  
  <xsl:template name="coverage"/>

  <xsl:template name="rights">
    <xsl:for-each select="/iris:iris/iris:instrument/iris:rights">
      <!-- 
      <xsl:if test="iris:rightsHolder!=''">
        <dc:rights>  
          <xsl:value-of select="iris:rightsHolder"/>
        </dc:rights>
      </xsl:if>
      <xsl:if test="iris:rightsStatement!=''">
	      <dc:rights>
	        <xsl:value-of select="iris:rightsStatement"/>
	      </dc:rights>
	    </xsl:if>
      -->
      <xsl:if test="iris:licence!=''">
	      <dc:rights>
	        <xsl:value-of select="iris:licence"/>
	      </dc:rights>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>
</xsl:stylesheet>