Ne plus utiliser, utiliser la version Python et le Makefile

#!/bin/ash

STYLESHEET=profile2html.xsl
XSLTPROCOPTS=--novalid
# GNU sed or another one?
SED_EXTENDED=`if sed -r s/foobar/dummy/ < /dev/null 2> /dev/null; then echo -r; else echo -E; fi`

process_with_xsltproc() { 
   profile=$1
   webpage=`echo $profile | sed $SED_EXTENDED 's/\.[a-z0-9]*$/.html/'`
   xsltproc ${XSLTPROCOPTS} -o ${webpage} ${STYLESHEET} $profile
}

if [ -z "$1" ]; then
   echo "Usage: $0 zonecheck-profile" > /dev/stderr 
   exit 1
fi
profile=$1

process_with_xsltproc $profile