
CA65 := build/cc65/bin/ca65
LD65 := build/cc65/bin/ld65

CA65_FLAGS := --cpu 65816 -s -U -I include

CA65_FLAGS += -DDEBUG

TARGET := out/build.sfc

INCLUDES := $(wildcard include/*.asm) 
SOURCES := $(wildcard src/*.asm)
OBJECTS := $(patsubst src/%.asm,build/obj/%.o,$(SOURCES))

all: $(TARGET)

$(TARGET): misc/lorom.cfg $(OBJECTS)
	$(LD65) -o $@ -C $(filter %.cfg,$^) $(filter %.o,$^)

build/obj/%.o: src/%.asm $(INCLUDES)
	$(CA65) $(CA65_FLAGS) -o $@ $<

.PHONY: all clean

clean:
	rm -f $(OBJECTS) $(TARGET)
