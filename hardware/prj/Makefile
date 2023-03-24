all: clean
	$(MAKE) prj
	$(MAKE) gen

prj:
	vivado -mode batch -source project.tcl > /dev/null 

gen:
	vivado -mode batch -source generate.tcl > /dev/null

clean:
	rm -rf agna* vivado* .Xil