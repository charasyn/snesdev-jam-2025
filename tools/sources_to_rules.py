#!/usr/bin/env python

# This is a gross hack to avoid needing to write this script yet :)
CONTENTS = '''
SOURCES := $(shell tools/sources_from_symbolsasm.py)
OBJECTS := $(patsubst $(CODESRCDIR)/%.asm,$(CODEOBJDIR)/%.o,$(SOURCES))

OBJECTS += $(DATAOBJDIR)/Asset_MapTest.o
OBJECTS += $(DATAOBJDIR)/Asset_TextGraphics.o

$(DATASRCDIR)/Asset_MapTest.asm: | $(DATASRCDIR)
$(DATASRCDIR)/Asset_MapTest.asm: experiments/test.tmj
	tools/tmj_to_bin.py experiments/test.tmj $@

$(DATASRCDIR)/Asset_TextGraphics.asm: | $(DATASRCDIR)
$(DATASRCDIR)/Asset_TextGraphics.asm: assets/text-graphics.png assets/text-graphics_palette.png
	tools/tileimg_to_bin.py --bpp 2 assets/text-graphics.png assets/text-graphics_palette.png $@

'''

with open('build/rules.mk', 'w') as f:
    f.write(CONTENTS)
