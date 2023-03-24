PLATFORM ?= zcu102_128_8
MODEL ?= resnet50

.PHONY: all schedule substitute

all: schedule substitute

schedule:
	python run_schedule.py --platform $(PLATFORM) --model $(MODEL)

substitute:
	python generate_param_header.py  results/$(PLATFORM)-$(MODEL)/arch_search.json
	