# RTL Script to run Basic Synthesis Flow
set_db init_lib_search_path /home/installs/FOUNDRY/digital/90nm/dig/lib   
#set_db hdl_search_path /home/cadence/Desktop/ECE_AP134_133/EXP6

set_db library slow.lib
read_hdl counter.v
elaborate 
read_sdc /home/cadence/Desktop/ECE_AP134_133/EXP6/constraints_sdc.sdc
set_db syn_generic_effort medium
syn_generic
set_db syn_map_effort medium
syn_map
set_db syn_opt_effort medium
syn_opt


write_hdl > counter_netlist.v
write_sdc > counter_block.sdc
report_area > counter_area.rep
report_gates > counter_gate.rep
report_power > counter_power.rep
report_timing > counter_timing.rep
gui_show

