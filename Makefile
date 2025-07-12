
CA65 := build/cc65/bin/ca65
LD65 := build/cc65/bin/ld65

CA65_FLAGS := --cpu 65816 -s -g -U -I include

CA65_FLAGS += -DDEBUG

TARGET := out/build.sfc

LD65_FLAGS := --dbgfile $(patsubst %.sfc,%.dbg,$(TARGET))

INCLUDES := $(wildcard include/*.asm) 
SOURCES := $(shell tools/sources_from_symbolsasm.py)
OBJECTS := $(patsubst src/%.asm,build/obj/%.o,$(SOURCES))
OBJECTS += build/data-obj/test.o
OBJECTS += build/data-obj/text_graphics.o

all: $(TARGET)

$(TARGET): misc/lorom.cfg $(OBJECTS)
	$(LD65) $(LD65_FLAGS) -o $@ -C $(filter %.cfg,$^) $(filter %.o,$^)

build/obj/%.o: src/%.asm $(INCLUDES)
	$(CA65) $(CA65_FLAGS) -o $@ $<

build/data-obj/%.o: build/data-src/%.asm
	$(CA65) $(CA65_FLAGS) -o $@ $<

build/data-src/test.asm: experiments/test.tmj experiments/test.tsj experiments/four-seasons-tileset.png tools/tmj_to_bin.py
	tools/tmj_to_bin.py $< $@

build/data-src/text_graphics.asm: assets/text-graphics.png assets/text-graphics_palette.png tools/tileimg_to_bin.py
	tools/tileimg_to_bin.py --bpp=2 assets/text-graphics.png assets/text-graphics_palette.png $@

.PHONY: all clean

clean:
	rm -f $(OBJECTS) $(TARGET)
