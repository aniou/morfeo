
morfeo_args      += --disk0=data/test-fat32.img
morfeo_args      += data/foenixmcp-a2560x.hex

musashi_dir       = external/Musashi
musashi_objects  += $(musashi_dir)/m68kcpu.o
musashi_objects  += $(musashi_dir)/m68kdasm.o
musashi_objects  += $(musashi_dir)/m68kops.o
musashi_objects  += $(musashi_dir)/softfloat/softfloat.o

odin_defs        += -collection:emulator=emulator
odin_defs        += -collection:lib=lib
build_flags      += $(odin_defs) -o:speed

.PHONY: doc a2560x test_w65c02s test_65c816

all: a2560x test_w65c02s test_65c816

help:
	@echo "make release      - build a2560x-like optimized, faster version"
	@echo "make              - build and run a2560x-like version"
	@echo "make morfeo       - build a a2560x emulator"
	@echo "make test_w65c02s - build a test suite for W65C02S"
	@echo "make test_65c816  - build a test suite for 65C816"
	@echo ""
	@echo "make clean        - clean-up binaries"
	@echo "make clean-all    - clean-up binaries and object files"

clean:
	rm -fv a2560x test_w65c02s test_65c816

clean-all: $(musashi_objects)
	rm -fv a2560x test_w65c02s test_65c816
	rm -fv $^
	rm -fv $(musashi_dir)/m68kconf.h

$(musashi_objects): external/m68kconf.h
	cp -vf $? $(musashi_dir)/
	$(MAKE) -C $(musashi_dir) clean
	$(MAKE) -C $(musashi_dir)

release: $(musashi_objects)
	odin build cmd/a2560x -no-bounds-check -disable-assert $(build_flags)

a2560x: $(musashi_objects)
	odin build cmd/a2560x       $(build_flags)

test_65c816:
	odin build cmd/test_65c816  $(build_flags)

test_w65c02s:
	odin build cmd/test_w65c02s $(build_flags)

# two targets for debug purposes
run: $(musashi_objects)
#	odin run cmd/a2560x $(build_flags) -- $(morfeo_args)
#	odin run cmd/test_65c816 $(build_flags)
	odin run cmd/test_w65c02s $(build_flags)

doc:
	odin doc cmd/test_w65c02s/  $(odin_defs)
