open_project -reset __ipname__
add_files __ipname__.cpp
add_files -tb __ipname___tb.cpp
set_top __ipname__

open_solution solution_1 -flow_target vivado
set_part xczu9eg-ffvb1156-2-e
create_clock -period 4 -name default
config_export -format ip_catalog -rtl verilog -ipname __ipname__ -output __ipname__.zip -version 1.0

csim_design -clean
csynth_design
cosim_design -rtl verilog
export_design
