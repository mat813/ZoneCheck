# $Id$

# 
# AUTHOR   : Stephane Bortzmeyer <bortzmeyer@nic.fr>
# CREATED  : 2002/10/10 16:38:17
#
# COPYRIGHT: AFNIC (c) 2003
# CONTACT  : zonecheck@nic.fr
# LICENSE  : GPL v2.0 (or MIT/X11-like after agreement)
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS: (see also CREDITS file)
#
#

#
# TODO: don't do install-cgi if INPUT_METHODS doesn't support cgi ??
#

PREFIX    ?= /usr/local
RUBY      ?= $(shell which ruby)
HTML_PATH ?= /zc

LIBEXEC=$(PREFIX)/libexec
BINDIR=$(PREFIX)/bin
DOCDIR=$(PREFIX)/share/doc
ETCDIR=$(PREFIX)/etc
CGIDIR=$(LIBEXEC)/zc/cgi-bin

INSTALL=install
#LN=ln -s		# Apache doesn't like symlink for CGI
LN=ln			# Doesn't cross partition boundary
#LN=install		# Duplicate file
CP=cp
CHMOD=chmod
FIND=find

HTML2TXT=elinks -dump


TOPDIR := $(shell if [ "$$PWD" != "" ]; then echo $$PWD; else pwd; fi)

ifndef XML_CATALOG_FILES
XML_CATALOG_FILES=$(TOPDIR)/doc/misc/catalog.xml
export XML_CATALOG_FILES
endif


all: zc-bin

zc-bin: 
	@echo "Nothing to make, you can install it right now!"
	@echo ""
	@echo "Default values are:"
	@echo "  HTML_PATH=$(HTML_PATH)"
	@echo "  PREFIX=$(PREFIX)"
	@echo "  RUBY=$(RUBY)"
	@echo "  WITH_ERB=$(WITH_ERB)"
	@echo ""
	@echo "You can change them by using the syntax:"
	@echo "  $(MAKE) key=value"

zc-cgi:
	@echo "Not automatized yet"


install: install-common install-cli install-cgi install-doc


install-common:
	@echo "==> Installing core components"
	$(INSTALL) -d $(LIBEXEC)/zc
	$(CP) -r zc     $(LIBEXEC)/zc
	$(RUBY) -p -i \
		-e "\$$_.gsub!(/^#!.*ruby/, '#!$(RUBY)')" \
		-e "\$$_.gsub!(/^(ZC_INSTALL_PATH\s*=\s*).*/, '\1\"$(LIBEXEC)/zc\"')" \
		-e "\$$_.gsub!(/^(ZC_CONFIG_DIR\s*=\s*).*/,   '\1\"$(ETCDIR)\"')" \
		-e "\$$_.gsub!(/^(ZC_LOCALIZATION_DIR\s*=\s*).*/, '\1\"$(LIBEXEC)/zc/locale\"')" \
		-e "\$$_.gsub!(/^(ZC_TEST_DIR\s*=\s*).*/,  '\1\"$(LIBEXEC)/zc/test\"')" \
		-e "\$$_.gsub!(/^(ZC_HTML_PATH\s*=\s*).*/, '\1\"$(HTML_PATH)\"')" \
		$(LIBEXEC)/zc/zc/zc.rb
	$(CHMOD) 755 $(LIBEXEC)/zc/zc/zc.rb 

	@echo "==> Installing libraries"
	$(CP) -r lib    $(LIBEXEC)/zc
	@echo

	@echo "==> Installing tests"
	$(CP) -r test   $(LIBEXEC)/zc
	@echo

	@echo "==> Installing locale"
	$(CP) -r locale $(LIBEXEC)/zc
	@echo

	@echo "==> Installing default configuration file"
	$(INSTALL) -d $(ETCDIR)
	$(INSTALL) -b -m 0644 etc/zc.conf $(ETCDIR)
	$(INSTALL) -b -m 0644 etc/zc.conf.fr $(ETCDIR)
	@echo "*************************"
	@echo "** If you already had a zc.conf file it has been renamed"
	@echo "**   to zc.conf.old"
	@echo "** Don't forget to edit the zc.conf to reflect your system"
	@echo "**   configuration"
	@echo "*************************"
	@echo

install-cgi:
	@echo "==> Installing HTML pages"
	$(CP) -r www   $(LIBEXEC)/zc
	@echo "==> Patching HTML pages"
	$(FIND) $(LIBEXEC)/zc/www -name '*.html' -exec $(RUBY) -p -i -e "\$$_.gsub!(/HTML_PATH/, '$(HTML_PATH)')" {} \;
ifndef WITH_ERB
	$(FIND) $(LIBEXEC)/zc/www -name '*.html' -exec $(RUBY) -p -i -e "\$$_.gsub!(/<%.*%>/, '')" {} \;
endif
	@echo

	@echo "==> Installing CGI"
	$(INSTALL) -d $(CGIDIR)
	$(LN) -f $(LIBEXEC)/zc/zc/zc.rb $(CGIDIR)/zc.cgi
	@echo

install-cli:
	@echo "==> Installing CLI"
	$(INSTALL) -d $(BINDIR)
	$(LN) -f $(LIBEXEC)/zc/zc/zc.rb $(BINDIR)/zc
	@echo

install-doc:
	@echo "==> Installing documentation"
	$(INSTALL) -d $(DOCDIR)/zc
	$(INSTALL) -m 0644 README TODO INSTALL BUGS $(DOCDIR)/zc
	@echo




realclean:
	find . -type f -name '*~' -exec rm {} \;
	rm -Rf $(TOPDIR)/doc/tmp
	rm -Rf $(TOPDIR)/doc/html

FAQ: doc/xml/FAQ.xml doc/xml/common/faq.xml doc/misc/html.xsl
	rm -Rf $(TOPDIR)/doc/tmp/FAQ
	mkdir -p $(TOPDIR)/doc/tmp/FAQ
	(cd $(TOPDIR)/doc/tmp/FAQ && xsltproc -nonet $(TOPDIR)/doc/misc/html.xsl $(TOPDIR)/doc/xml/FAQ.xml > FAQ.html)
	$(HTML2TXT) doc/tmp/FAQ/FAQ.html > FAQ

distrib: FAQ

doc-html: doc/xml/zc.xml doc/xml/common/faq.xml doc/misc/html.xsl
	rm -Rf $(TOPDIR)/doc/html
	mkdir -p $(TOPDIR)/doc/html
	(cd $(TOPDIR)/doc/html && xsltproc -nonet $(TOPDIR)/doc/misc/html.xsl $(TOPDIR)/doc/xml/zc.xml)
	cp doc/misc/docbook.css doc/html/
