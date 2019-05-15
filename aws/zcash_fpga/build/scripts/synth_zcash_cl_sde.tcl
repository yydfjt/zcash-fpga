# Amazon FPGA Hardware Development Kit
#
# Copyright 2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Amazon Software License (the "License"). You may not use
# this file except in compliance with the License. A copy of the License is
# located at
#
#    http://aws.amazon.com/asl/
#
# or in the "license" file accompanying this file. This file is distributed on
# an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
# implied. See the License for the specific language governing permissions and
# limitations under the License.

#Param needed to avoid clock name collisions
set_param sta.enableAutoGenClkNamePersistence 0
set CL_MODULE $CL_MODULE

create_project -in_memory -part [DEVICE_TYPE] -force

########################################
## Generate clocks based on Recipe 
########################################

puts "AWS FPGA: ([clock format [clock seconds] -format %T]) Calling aws_gen_clk_constraints.tcl to generate clock constraints from developer's specified recipe.";

source $HDK_SHELL_DIR/build/scripts/aws_gen_clk_constraints.tcl

#############################
## Read design files
#############################

#Convenience to set the root of the RTL directory
set ENC_SRC_DIR $CL_DIR\\build\\src_post_encryption

puts "AWS FPGA: ([clock format [clock seconds] -format %T]) Reading developer's Custom Logic files post encryption.";

#---- User would replace this section -----

# Reading the .sv and .v files, as proper designs would not require
# reading .v, .vh, nor .inc files

read_verilog -sv [glob ../src_post_encryption/*.v]
read_verilog -sv [glob ../src_post_encryption/*.sv]

#---- End of section replaced by User ----

puts "AWS FPGA: Reading AWS Shell design";

#Read AWS Design files
read_verilog [ list \
  $HDK_SHELL_DESIGN_DIR/lib/lib_pipe.sv \
  $HDK_SHELL_DESIGN_DIR/lib/bram_2rw.sv \
  $HDK_SHELL_DESIGN_DIR/lib/flop_fifo.sv \
  $HDK_SHELL_DESIGN_DIR/sh_ddr/synth/sync.v \
  $HDK_SHELL_DESIGN_DIR/sh_ddr/synth/flop_ccf.sv \
  $HDK_SHELL_DESIGN_DIR/sh_ddr/synth/ccf_ctl.v \
  $HDK_SHELL_DESIGN_DIR/sh_ddr/synth/mgt_acc_axl.sv  \
  $HDK_SHELL_DESIGN_DIR/sh_ddr/synth/mgt_gen_axl.sv  \
  $HDK_SHELL_DESIGN_DIR/sh_ddr/synth/sh_ddr.sv \
  $HDK_SHELL_DESIGN_DIR/interfaces/cl_ports.vh 
]

puts "AWS FPGA: Reading IP blocks";

# User IP
read_ip [ list \
  $CL_DIR/ip/axis_dwidth_converter_64_to_8/axis_dwidth_converter_64_to_8.xci \
  $CL_DIR/ip/axis_dwidth_converter_8_to_64/axis_dwidth_converter_8_to_64.xci
]

puts "AWS FPGA: Generating IP blocks";

set_property generate_synth_checkpoint false [get_files axis_dwidth_converter_64_to_8.xci]
set_property generate_synth_checkpoint false [get_files axis_dwidth_converter_8_to_64.xci]

generate_target all [get_ips axis_dwidth_converter_64_to_8]
generate_target all [get_ips axis_dwidth_converter_8_to_64]

#Read DDR IP
read_ip [ list \
  $HDK_SHELL_DESIGN_DIR/ip/ddr4_core/ddr4_core.xci 
]

#Read IP for axi register slices
read_ip [ list \
  $HDK_SHELL_DESIGN_DIR/ip/axi_register_slice/axi_register_slice.xci \
  $HDK_SHELL_DESIGN_DIR/ip/axi_register_slice_light/axi_register_slice_light.xci
]

#Read IP for virtual jtag / ILA/VIO
read_ip [ list \
  $HDK_SHELL_DESIGN_DIR/ip/cl_debug_bridge/cl_debug_bridge.xci \
  $CL_DIR/ip/ila_axi4/ila_axi4.xci \
  $CL_DIR/ip/ila_axi4_512/ila_axi4_512.xci \
  $CL_DIR/ip/ila_axis/ila_axis.xci \
  $CL_DIR/ip/ila_sde_c2h_dm/ila_sde_c2h_dm.xci \
  $CL_DIR/ip/ila_sde_h2c_dm/ila_sde_h2c_dm.xci \
  $CL_DIR/ip/ila_sde_c2h_buf/ila_sde_c2h_buf.xci \
  $CL_DIR/ip/ila_sde_h2c_buf/ila_sde_h2c_buf.xci \
  $CL_DIR/ip/ila_sde_wb/ila_sde_wb.xci \
  $CL_DIR/ip/ila_sde_ps/ila_sde_ps.xci
]

puts "AWS FPGA: Reading AWS constraints";

#Read all the constraints
#
#  cl_clocks_aws.xdc  - AWS auto-generated clock constraint.   ***DO NOT MODIFY***
#  cl_ddr.xdc         - AWS provided DDR pin constraints.      ***DO NOT MODIFY***
#  cl_synth_user.xdc  - Developer synthesis constraints.
read_xdc [ list \
   $CL_DIR/build/constraints/cl_clocks_aws.xdc \
   $HDK_SHELL_DIR/build/constraints/cl_ddr.xdc \
   $HDK_SHELL_DIR/build/constraints/cl_synth_aws.xdc \
   $CL_DIR/build/constraints/cl_synth_user.xdc
]

#Do not propagate local clock constraints for clocks generated in the SH
set_property USED_IN {synthesis implementation OUT_OF_CONTEXT} [get_files cl_clocks_aws.xdc]
set_property PROCESSING_ORDER EARLY  [get_files cl_clocks_aws.xdc]

########################
# CL Synthesis
########################
puts "AWS FPGA: ([clock format [clock seconds] -format %T]) Start design synthesis.";

update_compile_order -fileset sources_1
puts "\nRunning synth_design for $CL_MODULE $CL_DIR/build/scripts \[[clock format [clock seconds] -format {%a %b %d %H:%M:%S %Y}]\]"
eval [concat synth_design -top $CL_MODULE -verilog_define XSDB_SLV_DIS -part [DEVICE_TYPE] -mode out_of_context $synth_options -directive $synth_directive]

set failval [catch {exec grep "FAIL" failfast.csv}]
if { $failval==0 } {
	puts "AWS FPGA: FATAL ERROR--Resource utilization error; check failfast.csv for details"
	exit 1
}

puts "AWS FPGA: ([clock format [clock seconds] -format %T]) writing post synth checkpoint.";
write_checkpoint -force $CL_DIR/build/checkpoints/${timestamp}.CL.post_synth.dcp
#write_checkpoint -force $CL_DIR/build/checkpoints/CL.post_synth.dcp


close_project
#Set param back to default value
set_param sta.enableAutoGenClkNamePersistence 1
