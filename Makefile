# $Id$

# 
# AUTHOR : Stephane Bortzmeyer <bortzmeyer@nic.fr>
# CREATED: 2002/10/10 16:38:17
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS:
#
#

PREFIX ?= /usr/local
RUBY   ?= $(shell which ruby)

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

all: zc-bin

zc-bin: 
	@echo "Nothing to make, you can install it right now!"
	@echo ""
	@echo "Default values are:"
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
	$(CP) -r zc     $(LIBEXEC)/zc
	$(RUBY) -p -i \
		-e "\$$_.gsub!(/^#!.*ruby/, '#!$(RUBY)')" \
		-e "\$$_.gsub!(/^(ZC_INSTALL_PATH\s*=\s*).*/, '\1\"$(LIBEXEC)/zc\"')" \
		-e "\$$_.gsub!(/^(ZC_CONFIG_FILE\s*=\s*).*/, '\1\"$(ETCDIR)/zc.conf\"')" \
		-e "\$$_.gsub!(/^(ZC_LOCALIZATION_FILE\s*=\s*).*/, '\1\"$(LIBEXEC)/zc/locale/zc.%s\"')" \
		-e "\$$_.gsub!(/^(ZC_TEST_DIR\s*=\s*).*/, '\1\"$(LIBEXEC)/zc/test\"')" \
		$(LIBEXEC)/zc/zc/zc.rb
	$(CHMOD) 755 $(LIBEXEC)/zc/zc/zc.rb 

	@echo "==> Installing libraries"
	$(CP) -r lib    $(LIBEXEC)/zc

	@echo "==> Installing tests"
	$(CP) -r test   $(LIBEXEC)/zc

	@echo "==> Installing locale"
	$(CP) -r locale $(LIBEXEC)/zc

	@echo "==> Installing default configuration file"
	$(INSTALL) -d $(ETCDIR)
	$(INSTALL) -b -m 0644 etc/zc.conf $(ETCDIR)

install-cgi:
	@echo "==> Installing HTML pages"
	$(CP) -r html   $(LIBEXEC)/zc

	@echo "==> Installing CGI"
	$(INSTALL) -d $(CGIDIR)
	$(LN) -f $(LIBEXEC)/zc/zc/zc.rb $(CGIDIR)/zc.cgi

install-cli:
	@echo "==> Installing CLI"
	$(INSTALL) -d $(BINDIR)
	$(LN) -f $(LIBEXEC)/zc/zc/zc.rb $(BINDIR)/zc

install-doc:
	@echo "==> Installing documentation"
	$(INSTALL) -d $(DOCDIR)/zc
	$(INSTALL) -m 0644 README TODO INSTALL BUGS $(DOCDIR)/zc
