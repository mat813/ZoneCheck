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

LIBEXEC=$(PREFIX)/libexec/zc
BINDIR=$(PREFIX)/bin
DOCDIR=$(PREFIX)/share/doc/zc
INSTALL=install
CP=cp
LN=ln
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


install:
	echo $(PREFIX)
	echo $(RUBY)
	if [ ! -d $(DOCDIR) ]; then \
		$(INSTALL) -d $(DOCDIR); \
	fi
	if [ ! -d $(BINDIR) ]; then \
		$(INSTALL) -d $(BINDIR); \
	fi
	if [ ! -d $(LIBEXEC) ]; then \
		$(INSTALL) -d $(LIBEXEC); \
	fi


	$(CP) -r zc  $(LIBEXEC)
	$(CP) -r lib $(LIBEXEC)

	$(RUBY) -p -i.bak \
		-e "\$$_.gsub!('INSTALLPATHTOPATCH', '$(LIBEXEC)')" \
		-e "\$$_.gsub!('#!ruby', '#!$(RUBY)')" \
		$(LIBEXEC)/zc/zc.rb
	$(CHMOD) 755 $(LIBEXEC)/zc/zc.rb 
	$(LN) -s -f $(LIBEXEC)/zc/zc.rb $(BINDIR)/zc

	$(INSTALL) TODO INSTALL BUGS $(DOCDIR)
