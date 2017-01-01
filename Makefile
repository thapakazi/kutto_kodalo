WD:=$(PWD)
DATE:=$(shell date +%Y.%m.%d.%H:%M:%S)

SHELLRC_F:=shellrc
SHELLRC_D:=$(SHELLRC_F).d

SHELLRC:=$(HOME)/.$(SHELLRC_F)
SHELLRCD:=$(HOME)/.$(SHELLRC_D)

all: clean_before
	ln -s $(WD)/$(SHELLRC_F) $(SHELLRC)
	ln -s $(WD)/$(SHELLRC_D) $(SHELLRCD)

clean_before:
	 @[ -h $(SHELLRC) ] && mv $(SHELLRC) $(SHELLRC).bak_$(DATE) || echo "nothing to do here"
	 @[ -h $(SHELLRCD) ] &&  mv -vf $(SHELLRCD) $(SHELLRCD).bak_$(DATE) || echo "nothing to do here"
