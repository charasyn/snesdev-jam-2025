
CA65 := build/cc65/bin/ca65
LD65 := build/cc65/bin/ld65

CA65_FLAGS := --cpu 65816 -s -U -I include

CA65_FLAGS += -DDEBUG

TARGET := out/build.sfc

INCLUDES := $(wildcard include/*.asm) 
SOURCES := $(shell tools/sources_from_symbolsasm.py)
OBJECTS := $(patsubst src/%.asm,build/obj/%.o,$(SOURCES))
OBJECTS += build/data-obj/test.o

all: $(TARGET)

$(TARGET): misc/lorom.cfg $(OBJECTS)
	$(LD65) -o $@ -C $(filter %.cfg,$^) $(filter %.o,$^)

build/obj/%.o: src/%.asm $(INCLUDES)
	$(CA65) $(CA65_FLAGS) -o $@ $<

build/data-obj/test.o: build/data-src/test.asm
	$(CA65) $(CA65_FLAGS) -o $@ $<

build/data-src/test.asm: experiments/test.tmj experiments/test.tsj experiments/four-seasons-tileset.png tools/tmj_to_bin.py
	tools/tmj_to_bin.py $< $@

.PHONY: all clean

clean:
	rm -f $(OBJECTS) $(TARGET)
