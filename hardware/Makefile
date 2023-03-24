.PHONY: all clean

all:
	$(MAKE) -C hls/hls_src -j 3 all
	$(MAKE) -C prj all

clean:
	$(MAKE) -C hls/hls_src clean
	$(MAKE) -C prj clean
	