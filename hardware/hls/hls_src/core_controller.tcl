open_project -reset core_controller
add_files core_controller.cpp
add_files -tb core_controller_tb.cpp
set_top core_controller

open_solution solution_1 -flow_target vivado
set_part xczu9eg-ffvb1156-2-e
create_clock -period 4 -name default
config_export -format ip_catalog -rtl verilog -ipname core_controller -output core_controller.zip -version 1.0

csim_design -clean
csynth_design
cosim_design -rtl verilog
export_design
