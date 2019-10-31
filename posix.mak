DMD_DIR = ../dmd
BUILD = release
DMD = $(DMD_DIR)/generated/$(OS)/$(BUILD)/$(MODEL)/dmd
CC = gcc
INSTALL_DIR = ../install
DRUNTIME_PATH = ../druntime
PHOBOS_PATH = ../phobos
DUB=dub

WITH_DOC = no
DOC = ../dlang.org

include osmodel.mak

# Build folder for all binaries
GENERATED = generated
ROOT = $(GENERATED)/$(OS)/$(MODEL)

# Set DRUNTIME name and full path
ifeq (,$(findstring win,$(OS)))
	DRUNTIME = $(DRUNTIME_PATH)/lib/libdruntime-$(OS)$(MODEL).a
	DRUNTIMESO = $(DRUNTIME_PATH)/lib/libdruntime-$(OS)$(MODEL)so.a
else
	DRUNTIME = $(DRUNTIME_PATH)/lib/druntime.lib
endif

# Set PHOBOS name and full path
ifeq (,$(findstring win,$(OS)))
	PHOBOS = $(PHOBOS_PATH)/generated/$(OS)/$(BUILD)/$(MODEL)/libphobos2.a
	PHOBOSSO = $(PHOBOS_PATH)/generated/$(OS)/$(BUILD)/$(MODEL)/libphobos2.so
endif

# default to warnings and deprecations as errors, override via e.g. make -f posix.mak WARNINGS=-wi
WARNINGS = -w -de
# default include/link paths, override by setting DFLAGS (e.g. make -f posix.mak DFLAGS=-I/foo)
DFLAGS = -I$(DRUNTIME_PATH)/import -I$(PHOBOS_PATH) \
		 -L-L$(PHOBOS_PATH)/generated/$(OS)/$(BUILD)/$(MODEL) $(MODEL_FLAG) -fPIC -dip25
DFLAGS += $(WARNINGS)

# Default DUB flags (DUB uses a different architecture format)
DUBFLAGS = --arch=$(subst 32,x86,$(subst 64,x86_64,$(MODEL)))

TOOLS = \
    $(ROOT)/catdoc \
    $(ROOT)/checkwhitespace \
    $(ROOT)/contributors \
    $(ROOT)/ddemangle \
    $(ROOT)/detab \
    $(ROOT)/rdmd \
    $(ROOT)/tolf \
    $(ROOT)/updatecopyright

CURL_TOOLS = \
    $(ROOT)/changed \
    $(ROOT)/dget

DOC_TOOLS = \
    $(ROOT)/dman

TEST_TOOLS = \
    $(ROOT)/rdmd_test

all: $(TOOLS) $(CURL_TOOLS) $(ROOT)/dustmite

rdmd:      $(ROOT)/rdmd
ddemangle: $(ROOT)/ddemangle
catdoc:    $(ROOT)/catdoc
detab:     $(ROOT)/detab
tolf:      $(ROOT)/tolf
dget:      $(ROOT)/dget
changed:   $(ROOT)/changed
dman:      $(ROOT)/dman
dustmite:  $(ROOT)/dustmite

$(ROOT)/dustmite: DustMite/dustmite.d DustMite/splitter.d
	$(DMD) $(DFLAGS) -version=Dlang_Tools DustMite/dustmite.d DustMite/splitter.d -of$(@)

$(TOOLS) $(DOC_TOOLS) $(CURL_TOOLS) $(TEST_TOOLS): $(ROOT)/%: %.d
	$(DMD) $(DFLAGS) -of$(@) $(<)

d-tags.json:
	@echo 'Build d-tags.json and copy it here, e.g. by running:'
	@echo "    make -C ../dlang.org -f posix.mak d-tags-latest.json && cp ../dlang.org/d-tags-latest.json d-tags.json"
	@echo 'or:'
	@echo "    make -C ../dlang.org -f posix.mak d-tags-prerelease.json && cp ../dlang.org/d-tags-prerelease.json d-tags.json"
	@exit 1

$(ROOT)/dman: d-tags.json
$(ROOT)/dman: override DFLAGS += -J.

install: $(TOOLS) $(CURL_TOOLS) $(ROOT)/dustmite
	mkdir -p $(INSTALL_DIR)/bin
	cp $^ $(INSTALL_DIR)/bin

clean:
	rm -rf $(GENERATED)

$(ROOT)/tests_extractor: tests_extractor.d
	mkdir -p $(ROOT)
	DFLAGS="$(DFLAGS)" $(DUB) build \
		   --single $< --force --compiler=$(DMD) $(DUBFLAGS) \
		   && mv ./tests_extractor $@

################################################################################
# Build & run tests
################################################################################

test_tests_extractor: $(ROOT)/tests_extractor
	for file in ascii iteration ; do \
		$< -i "./test/tests_extractor/$${file}.d" | diff -p - "./test/tests_extractor/$${file}.d.ext"; \
	done
	$< -a betterc -i "./test/tests_extractor/attributes.d" | diff -p - "./test/tests_extractor/attributes.d.ext";
	$< --betterC -i "./test/tests_extractor/betterc.d" | diff -p - "./test/tests_extractor/betterc.d.ext";

RDMD_TEST_COMPILERS = $(DMD)
RDMD_TEST_EXECUTABLE = $(ROOT)/rdmd
RDMD_TEST_DEFAULT_COMPILER = $(basename $(DMD))

VERBOSE_RDMD_TEST=0
ifeq ($(VERBOSE_RDMD_TEST), 1)
	override VERBOSE_RDMD_TEST_FLAGS:=-v
endif

test_rdmd: $(ROOT)/rdmd_test $(RDMD_TEST_EXECUTABLE)
	$< $(RDMD_TEST_EXECUTABLE) -m$(MODEL) \
	   --rdmd-default-compiler=$(RDMD_TEST_DEFAULT_COMPILER) \
	   --test-compilers=$(RDMD_TEST_COMPILERS) \
	   $(VERBOSE_RDMD_TEST_FLAGS)
	$(DMD) $(DFLAGS) -unittest -main -run rdmd.d

test: test_tests_extractor test_rdmd

ifeq ($(WITH_DOC),yes)
all install: $(DOC_TOOLS)
endif

.PHONY: all install clean

.DELETE_ON_ERROR: # GNU Make directive (delete output files on error)
