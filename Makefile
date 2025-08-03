### User config
CA65 := cc65/bin/ca65
LD65 := cc65/bin/ld65
# Comment out to disable debug build
DEBUG := 1

### Variables and other stuff
OUTDIR := out
BUILDDIR := build
CODESRCDIR := src
CODEOBJDIR := $(BUILDDIR)/obj-code
DATASRCDIR := $(BUILDDIR)/src-data
DATAOBJDIR := $(BUILDDIR)/obj-data
TARGET := $(OUTDIR)/build.sfc

CA65_FLAGS := --cpu 65816 -s -g -U -I include
CA65_FLAGS += --feature string_escapes --feature underline_in_numbers
LD65_FLAGS := --dbgfile $(patsubst %.sfc,%.dbg,$(TARGET))

ifneq (,$(DEBUG))
CA65_FLAGS += -DDEBUG
endif

INCLUDES := $(wildcard include/*.asm)
SOURCES := $(shell tools/sources_from_symbolsasm.py)
OBJECTS := $(patsubst $(CODESRCDIR)/%.asm,$(CODEOBJDIR)/%.o,$(SOURCES))

### "Meta" rules, not creating a useful build artifact
all: $(TARGET)

.PHONY: all clean

ifneq (,$(filter clean,$(MAKECMDGOALS)))
  ifneq (clean,$(MAKECMDGOALS))
    $(error Cannot make clean target as well as other targets)
  endif
endif

clean:
	rm -rf $(OUTDIR) $(BUILDDIR)

# This rule adds a dependency from all object files to both directories.
# It must be listed before the rule which actually makes the object, as
# the last recipe listed for a target will be the one used.
$(OBJECTS): | $(OBJDIR) $(DATAOBJDIR)

$(OUTDIR) $(BUILDDIR) $(CODEOBJDIR) $(DATASRCDIR) $(DATAOBJDIR):
	mkdir -p $@

# We will create this included Makefile using a Python script
$(BUILDDIR)/rules.mk: sources.yaml Makefile tools/sources_to_rules.py | $(BUILDDIR)
	tools/sources_to_rules.py --input=$< --output=$@

# Ensure this is only included if we aren't doing `make clean`.
# Ensure this is included before the hardcoded rules, as otherwise it will
# overwrite their recipes.
ifeq (,$(filter clean,$(MAKECMDGOALS)))
  -include $(BUILDDIR)/rules.mk
endif

### Hardcoded rules

$(TARGET): misc/lorom.cfg $(OBJECTS) | $(OUTDIR)
	$(LD65) $(LD65_FLAGS) -o $@ -C $(filter %.cfg,$^) $(filter %.o,$^)

# Code source files depend on includes
$(CODEOBJDIR)/%.o: $(CODESRCDIR)/%.asm $(INCLUDES) | $(CODEOBJDIR)
	$(CA65) $(CA65_FLAGS) -o $@ $<

# Data source files do not depend on includes
$(DATAOBJDIR)/%.o: $(DATASRCDIR)/%.asm | $(DATAOBJDIR)
	$(CA65) $(CA65_FLAGS) -o $@ $<
