# $Id$

# 
# CONTACT     : zonecheck@nic.fr
# AUTHOR      : Stephane Bortzmeyer <bortzmeyer@nic.fr>
#
# CREATED     : 2002/10/10 16:38:17
# REVISION    : $Revision$ 
# DATE        : $Date$
#
# CONTRIBUTORS: (see also CREDITS file)
#   Stephane D'Alu <sdalu@nic.fr>
#
#
# LICENSE     : GPL v2 (or MIT/X11-like after agreement)
# COPYRIGHT   : AFNIC (c) 2003
#
# This file is part of ZoneCheck.
#
# ZoneCheck is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# ZoneCheck is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ZoneCheck; if not, write to the Free Software Foundation,
# Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#

#
# TODO: don't do install-cgi if INPUT_METHODS doesn't support cgi ??
#

PREFIX    ?= /usr/local
RUBY      ?= $(shell which ruby)
HTML_PATH ?= /zc

LIBEXEC=$(PREFIX)/libexec
BINDIR=$(PREFIX)/bin
MANDIR=$(PREFIX)/man
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
TAR=tar

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
	@echo ""
	@echo "You can change them by using the syntax:"
	@echo "  $(MAKE) key=value"

zc-cgi:
	@echo "Not automatized yet"


install: install-common install-cli install-cgi install-doc


install-common:
	@echo "==> Installing core components"
	$(INSTALL) -d $(LIBEXEC)/zc
	$(TAR) cf - zc     | (cd $(LIBEXEC)/zc && $(TAR) xvf -)
	$(RUBY) -p -i \
		-e "\$$_.gsub!(/^#!.*ruby/, '#!$(RUBY)')" \
		-e "\$$_.gsub!(/^(ZC_INSTALL_PATH\s*=\s*).*/, '\1\"$(LIBEXEC)/zc\"')" \
		-e "\$$_.gsub!(/^(ZC_CONFIG_DIR\s*=\s*).*/,   '\1\"$(ETCDIR)/zonecheck\"')" \
		-e "\$$_.gsub!(/^(ZC_LOCALIZATION_DIR\s*=\s*).*/, '\1\"$(LIBEXEC)/zc/locale\"')" \
		-e "\$$_.gsub!(/^(ZC_TEST_DIR\s*=\s*).*/,  '\1\"$(LIBEXEC)/zc/test\"')" \
		-e "\$$_.gsub!(/^(ZC_HTML_PATH\s*=\s*).*/, '\1\"$(HTML_PATH)\"')" \
		$(LIBEXEC)/zc/zc/zc.rb
	$(CHMOD) 755 $(LIBEXEC)/zc/zc/zc.rb 

	@echo "==> Installing libraries"
	$(TAR) cf - lib    | (cd $(LIBEXEC)/zc && $(TAR) xvf -)
	@echo

	@echo "==> Installing tests"
	$(TAR) cf - test   | (cd $(LIBEXEC)/zc && $(TAR) xvf -)
	@echo

	@echo "==> Installing locale"
	$(TAR) cf - locale | (cd $(LIBEXEC)/zc && $(TAR) xvf -)
	@echo

	@echo "==> Installing default configuration file"
	$(INSTALL) -d $(ETCDIR)/zonecheck
	$(INSTALL) -b -m 0644 etc/zc.conf $(ETCDIR)/zonecheck
	$(INSTALL) -b -m 0644 etc/zc.conf.fr $(ETCDIR)/zonecheck
	$(INSTALL) -b -m 0644 etc/zc.conf.arpa $(ETCDIR)/zonecheck
	$(INSTALL) -b -m 0644 etc/rootservers $(ETCDIR)/zonecheck
	@echo "*************************"
	@echo "** If you already had a zc.conf file it has been renamed"
	@echo "**   to zc.conf.old"
	@echo "** Don't forget to edit the zc.conf to reflect your system"
	@echo "**   configuration"
	@echo "*************************"
	@echo

install-cgi:
	@echo "==> Installing HTML pages"
	$(TAR) cf - www   | (cd $(LIBEXEC)/zc && $(TAR) xvf -)
	@echo "==> Patching HTML pages"
	$(FIND) $(LIBEXEC)/zc/www -name '*.html.*' -exec $(RUBY) -p -i -e "\$$_.gsub!(/HTML_PATH/, '$(HTML_PATH)')" {} \;
	$(FIND) $(LIBEXEC)/zc/www -name '*.html' -exec $(RUBY) -p -i -e "\$$_.gsub!(/HTML_PATH/, '$(HTML_PATH)')" {} \;
	@echo

	@echo "==> Installing CGI"
	$(INSTALL) -d $(CGIDIR)
	$(LN) -f $(LIBEXEC)/zc/zc/zc.rb $(CGIDIR)/zc.cgi
	@echo

install-cli:
	@echo "==> Installing CLI"
	$(INSTALL) -d $(BINDIR)
	$(LN) -f $(LIBEXEC)/zc/zc/zc.rb $(BINDIR)/zc
	$(LN) -f $(LIBEXEC)/zc/zc/zc.rb $(BINDIR)/zonecheck
	$(INSTALL) -d $(MANDIR)/man1
	$(INSTALL) -m 0644 man/zonecheck.1 $(MANDIR)/man1/zc.1
	$(INSTALL) -m 0644 man/zonecheck.1 $(MANDIR)/man1/zonecheck.1
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
