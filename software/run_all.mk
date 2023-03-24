PLATFORM_LIST := ultra96_128_8 zcu102_128_8 zcu102_256_8
MODEL_LIST := alexnet resnet50 mbnetv2 vgg16 yolov2_416
PLATFORM_MODEL_COMB_LIST := $(foreach P,${PLATFORM_LIST},$(addprefix comb-${P}-,${MODEL_LIST}))

.PHONY: all clean ${PLATFORM_MODEL_COMB_LIST}

all:
	@rm -f .tmp/*
	@cd .tmp/ && echo "ready" | tee ${PLATFORM_MODEL_COMB_LIST} > /dev/null
	$(MAKE) -k -f $(lastword $(MAKEFILE_LIST)) ${PLATFORM_MODEL_COMB_LIST}

clean:
	@rm -rf results/*

${PLATFORM_MODEL_COMB_LIST}:
	@echo "running" > .tmp/$@
	$(MAKE) all PLATFORM=$(word 2,$(subst -, ,$@)) MODEL=$(word 3,$(subst -, ,$@)) || (echo "error" > .tmp/$@; exit 1)
	@echo -n "done" > .tmp/$@
