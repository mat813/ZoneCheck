#!/bin/sh

export SGML_CATALOG_FILES=/nicdoc/DocMaker/catalog.sgml
export XML_CATALOG_FILES=/nicdoc/DocMaker/catalog.xml
PATH=$PATH:/nicdoc/DocMaker/bin:/nicdoc/DocMaker/sysdeps/i386-FreeBSD/bin

warn() { echo "WARN: $1"  ; return 1; }
die()  { echo "ERROR: $1" ; exit   1; }
info() { echo "$1"        ; return 1; }

# Arguments
[ -z "$1" ] && die "version requiered (ex: 2.0.0)"

dest=${2:-/dev/null}
[ "${dest#/}" != ${dest} ] || dest=`pwd`/$dest


release=$1
tmp=/tmp/zcrelease.$$

cvstag=ZC-`echo $release | sed 's/\./_/g'`
module=zonecheck
tarname=$module-$release.tgz
tarlatest=$module-latest.tgz


info "Making ZoneCheck release $release"

info "- creating temporary directory $tmp"
mkdir -p $tmp
cd $tmp || die "unable to change directory to $tmp"

info "- exporting from CVS with tag $cvstag"
cvs -q -d subversions.gnu.org:/cvsroot/zonecheck export -r $cvstag $module ||
    die "unable to export release tagged $cvstag"

info "- generating documentation"
(   mkdir -p $module/doc/html
    cd $module/doc/html || die "unable to change directory to zc/doc/html"
    xml2doc -q ../xml/FAQ.xml --output=html
    xml2doc -q ../xml/zc.xml  --output=htmlchunk
)
(   cd $module
    elinks -dump doc/html/FAQ.html > FAQ
)

info "- creating RPM spec"
sed s/@VERSION@/$release/ < $module/contrib/distrib/rpm/zonecheck.spec.in > $module/contrib/distrib/rpm/zonecheck.spec



info "- creating tarball: $tarname"
tar cfz $tarname $module

info "- copy on ${dest}"
cp $tarname ${dest}

info "- copy on savannah"
#ln -s $tarname $tarlatest
rsync -e "ssh -i $HOME/.ssh/zonecheck_savannah" -av $tarname $tarlatest zonecheck@subversions.gnu.org:/upload/zonecheck/

info "- cleaning"
rm -Rf $tmp

exit 0
