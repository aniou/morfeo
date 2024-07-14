
morfeo_args      += --disk0=data/test-fat32.img
morfeo_args      += data/foenixmcp-a2560x.hex

musashi_dir       = external/Musashi
musashi_objects  += $(musashi_dir)/m68kcpu.o
musashi_objects  += $(musashi_dir)/m68kdasm.o
musashi_objects  += $(musashi_dir)/m68kops.o
musashi_objects  += $(musashi_dir)/softfloat/softfloat.o

build_flags      += -o:speed
build_flags      += -collection:emulator=emulator
build_flags      += -collection:lib=lib

# not needed anymore, left for reference only
#build_flags      += -extra-linker-flags:"-L$(musashi_dir) $(musashi_objects)"

all: run

help:
	@echo "make            - build and run a2560x-like version"
	@echo "make release    - build a2560x-like optimized, faster version"
	@echo "make clean      - clean-up binaries"
	@echo "make clean-all  - clean-up binaries and object files"

clean:
	rm -fv morfeo

clean-all: $(musashi_objects)
	rm -fv $^
	rm -fv $(musashi_dir)/m68kconf.h

$(musashi_objects): external/m68kconf.h
	cp -vf $? $(musashi_dir)/
	$(MAKE) -C $(musashi_dir) clean
	$(MAKE) -C $(musashi_dir)

release: $(musashi_objects)
	odin build . -no-bounds-check -disable-assert $(build_flags)

run: $(musashi_objects)
	odin run   . $(build_flags) -- $(morfeo_args)

