# $Id$

#  
# CONTACT     : zonecheck@nic.fr 
# AUTHOR      : Stephane D'Alu <sdalu@nic.fr> 
# 
# CREATED     : 2003/10/23 21:04:09 
# REVISION    : $Revision$  
# DATE        : $Date$ 
# 

RUBY ?=ruby
ZC_INSTALLER=$(RUBY) ./installer.rb


all: configinfo

configinfo: 
	@echo "Nothing to make, you can install it right now!"
	@echo " => but ensure that you have the full path for the ruby interpreter!"
	@echo ""
	@$(ZC_INSTALLER) configinfo
	@echo ""
	@echo "You can change them by using the syntax:"
	@echo "  $(MAKE) key=value"

install: install-all

install-all:
	@$(ZC_INSTALLER) all

install-cli:
	@$(ZC_INSTALLER) common cli

install-cgi:
	@$(ZC_INSTALLER) common cgi

install-doc:
	@$(ZC_INSTALLER) doc
