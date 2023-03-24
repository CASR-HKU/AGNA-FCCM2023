IP_LIST = agna_aux core_controller layout_convert
IP_ZIP_LIST = $(addsuffix .zip,$(IP_LIST))
IP_TCL_LIST = $(addsuffix .tcl,$(IP_LIST))

.PHONY: all clean $(IP_LIST)

all: $(IP_LIST)

clean:
	rm -rf $(IP_LIST)
	rm -f $(IP_ZIP_LIST)

$(IP_LIST): %: %.tcl
	@echo "Generating $@..."
	vitis_hls $@.tcl -l $@.log > /dev/null
	rm -rf ../hls_ip/$@/*
	unzip -q $@.zip -d ../hls_ip/$@
	@echo "$@ done."

$(IP_TCL_LIST): template.tcl
	@echo "Generating $@..."
	sed 's/__ipname__/$(basename $@)/g' template.tcl > $@
	@echo "$@ done."
