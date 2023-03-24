open_project -reset layout_convert
add_files layout_convert.cpp
add_files -tb layout_convert_tb.cpp
set_top layout_convert

open_solution solution_1 -flow_target vivado
set_part xczu9eg-ffvb1156-2-e
create_clock -period 4 -name default
config_export -format ip_catalog -rtl verilog -ipname layout_convert -output layout_convert.zip -version 1.0

csim_design -clean
csynth_design
cosim_design -rtl verilog
export_design
