open_project -reset agna_aux
add_files agna_aux.cpp
add_files -tb agna_aux_tb.cpp
set_top agna_aux

open_solution solution_1 -flow_target vivado
set_part xczu9eg-ffvb1156-2-e
create_clock -period 4 -name default
config_export -format ip_catalog -rtl verilog -ipname agna_aux -output agna_aux.zip -version 1.0

csim_design -clean
csynth_design
cosim_design -rtl verilog
export_design
