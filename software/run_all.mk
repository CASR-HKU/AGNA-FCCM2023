PLATFORM_LIST := ultra96_128_8 ultra96_128_16 zcu102_128_8 zcu102_128_16 u200_512_8 u200_512_16
MODEL_LIST := alexnet mbnetv2_192 mbnetv2 resnet50 vgg16 yolov2_448
PLATFORM_MODEL_COMB_LIST := $(foreach P,${PLATFORM_LIST},$(addprefix agna-${P}-,${MODEL_LIST}))

.PHONY: all clean ${PLATFORM_MODEL_COMB_LIST}

all:
	@rm -rf .tmp
	@mkdir .tmp
	@cd .tmp/ && echo "ready" | tee ${PLATFORM_MODEL_COMB_LIST} > /dev/null
	$(MAKE) -k -f $(lastword $(MAKEFILE_LIST)) ${PLATFORM_MODEL_COMB_LIST}

clean:
	@rm -rf results/*

${PLATFORM_MODEL_COMB_LIST}:
	@echo "running" > .tmp/$@
	$(MAKE) schedule PLATFORM=$(word 2,$(subst -, ,$@)) MODEL=$(word 3,$(subst -, ,$@)) || (echo "error" > .tmp/$@; exit 1)
	@echo -n "done" > .tmp/$@
