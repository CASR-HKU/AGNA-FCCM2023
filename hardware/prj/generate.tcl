set bd_name chip_bd
set synth_name synth_1
set impl_name impl_1
set clk_freq 100

open_project agna.xpr
upgrade_ip [get_ips agna_aux_0 core_controller_0 layout_convert_0]
open_bd_design [get_files ${bd_name}.bd]

set_property -dict [list CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ ${clk_freq}] [get_bd_cells zynq_ultra_ps_e_0]
validate_bd_design
save_bd_design

reset_target all [get_ips -exclude_bd_ips]
reset_target all [get_files ${bd_name}.bd]
reset_runs ${synth_name}
launch_runs ${impl_name} -to_step write_bitstream -jobs 8
wait_on_run ${impl_name}


file copy -force [get_files ${bd_name}.hwh] ./agna.hwh
file copy -force [get_property DIRECTORY [get_runs ${impl_name}]]/[get_property top [current_fileset]].bit ./agna.bit
