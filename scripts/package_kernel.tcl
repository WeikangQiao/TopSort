#
# Copyright (C) 2020 Xilinx, Inc
#
# Licensed under the Apache License, Version 2.0 (the "License"). You may
# not use this file except in compliance with the License. A copy of the
# License is located at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
#

set path_to_hdl "./src/hdl"
set path_to_packaged "./packaged_kernel_${suffix}"
set path_to_tmp_project "./tmp_kernel_pack_${suffix}"

create_project -force kernel_pack $path_to_tmp_project 
add_files -norecurse [glob $path_to_hdl/*.v $path_to_hdl/*.sv]
set_property top merge_sort_complete [current_fileset]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
ipx::package_project -root_dir $path_to_packaged -vendor xilinx.com -library RTLKernel -taxonomy /KernelIP -import_files -set_current false
ipx::unload_core $path_to_packaged/component.xml
ipx::edit_ip_in_project -upgrade true -name tmp_edit_project -directory $path_to_packaged $path_to_packaged/component.xml

set core [ipx::current_core]

set_property core_revision 2 $core
foreach up [ipx::get_user_parameters] {
  ipx::remove_user_parameter [get_property NAME $up] $core
}
ipx::associate_bus_interfaces -busif m00_axi -clock ap_clk $core
ipx::associate_bus_interfaces -busif m01_axi -clock ap_clk $core
ipx::associate_bus_interfaces -busif m02_axi -clock ap_clk $core
ipx::associate_bus_interfaces -busif m03_axi -clock ap_clk $core
ipx::associate_bus_interfaces -busif m04_axi -clock ap_clk $core
ipx::associate_bus_interfaces -busif m05_axi -clock ap_clk $core
ipx::associate_bus_interfaces -busif m06_axi -clock ap_clk $core
ipx::associate_bus_interfaces -busif m07_axi -clock ap_clk $core
ipx::associate_bus_interfaces -busif m08_axi -clock ap_clk $core
ipx::associate_bus_interfaces -busif m09_axi -clock ap_clk $core
ipx::associate_bus_interfaces -busif m10_axi -clock ap_clk $core
ipx::associate_bus_interfaces -busif m11_axi -clock ap_clk $core
ipx::associate_bus_interfaces -busif m12_axi -clock ap_clk $core
ipx::associate_bus_interfaces -busif m13_axi -clock ap_clk $core
ipx::associate_bus_interfaces -busif m14_axi -clock ap_clk $core
ipx::associate_bus_interfaces -busif m15_axi -clock ap_clk $core
ipx::associate_bus_interfaces -busif s_axi_control -clock ap_clk $core

# Specify the freq_hz parameter 
set clkbif      [::ipx::get_bus_interfaces -of $core "ap_clk"]
set clkbifparam [::ipx::add_bus_parameter -quiet "FREQ_HZ" $clkbif]
# Set desired frequency                   
set_property value 250000000 $clkbifparam
# set value_resolve_type 'user' if the frequency can vary. 
set_property value_resolve_type user $clkbifparam
# set value_resolve_type 'immediate' if the frequency cannot change. 
# set_property value_resolve_type immediate $clkbifparam

set mem_map    [::ipx::add_memory_map -quiet "s_axi_control" $core]
set addr_block [::ipx::add_address_block -quiet "reg0" $mem_map]

set reg      [::ipx::add_register "CTRL" $addr_block]
  set_property description    "Control signals"    $reg
  set_property address_offset 0x000 $reg
  set_property size           32    $reg
set field [ipx::add_field AP_START $reg]
  set_property ACCESS {read-write} $field
  set_property BIT_OFFSET {0} $field
  set_property BIT_WIDTH {1} $field
  set_property DESCRIPTION {Control signal Register for 'ap_start'.} $field
  set_property MODIFIED_WRITE_VALUE {modify} $field
set field [ipx::add_field AP_DONE $reg]
  set_property ACCESS {read-only} $field
  set_property BIT_OFFSET {1} $field
  set_property BIT_WIDTH {1} $field
  set_property DESCRIPTION {Control signal Register for 'ap_done'.} $field
  set_property READ_ACTION {modify} $field
set field [ipx::add_field AP_IDLE $reg]
  set_property ACCESS {read-only} $field
  set_property BIT_OFFSET {2} $field
  set_property BIT_WIDTH {1} $field
  set_property DESCRIPTION {Control signal Register for 'ap_idle'.} $field
  set_property READ_ACTION {modify} $field
set field [ipx::add_field AP_READY $reg]
  set_property ACCESS {read-only} $field
  set_property BIT_OFFSET {3} $field
  set_property BIT_WIDTH {1} $field
  set_property DESCRIPTION {Control signal Register for 'ap_ready'.} $field
  set_property READ_ACTION {modify} $field
set field [ipx::add_field RESERVED_1 $reg]
  set_property ACCESS {read-only} $field
  set_property BIT_OFFSET {4} $field
  set_property BIT_WIDTH {3} $field
  set_property DESCRIPTION {Reserved.  0s on read.} $field
  set_property READ_ACTION {modify} $field
set field [ipx::add_field AUTO_RESTART $reg]
  set_property ACCESS {read-write} $field
  set_property BIT_OFFSET {7} $field
  set_property BIT_WIDTH {1} $field
  set_property DESCRIPTION {Control signal Register for 'auto_restart'.} $field
  set_property MODIFIED_WRITE_VALUE {modify} $field
set field [ipx::add_field RESERVED_2 $reg]
  set_property ACCESS {read-only} $field
  set_property BIT_OFFSET {8} $field
  set_property BIT_WIDTH {24} $field
  set_property DESCRIPTION {Reserved.  0s on read.} $field
  set_property READ_ACTION {modify} $field

set reg      [::ipx::add_register "GIER" $addr_block]
  set_property description    "Global Interrupt Enable Register"    $reg
  set_property address_offset 0x004 $reg
  set_property size           32    $reg

set reg      [::ipx::add_register "IP_IER" $addr_block]
  set_property description    "IP Interrupt Enable Register"    $reg
  set_property address_offset 0x008 $reg
  set_property size           32    $reg

set reg      [::ipx::add_register "IP_ISR" $addr_block]
  set_property description    "IP Interrupt Status Register"    $reg
  set_property address_offset 0x00C $reg
  set_property size           32    $reg

set reg      [::ipx::add_register -quiet "size" $addr_block]
  set_property address_offset 0x010 $reg
  set_property size           [expr {8*8}]   $reg

set reg      [::ipx::add_register -quiet "num_pass" $addr_block]
  set_property address_offset 0x018 $reg
  set_property size           [expr {1*8}]   $reg

set reg      [::ipx::add_register -quiet "ptr_0" $addr_block]
  set_property address_offset 0x01c $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m00_axi $regparam 

set reg      [::ipx::add_register -quiet "out_0_ptr" $addr_block]
  set_property address_offset 0x024 $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m00_axi $regparam 

set reg      [::ipx::add_register -quiet "in_1_ptr" $addr_block]
  set_property address_offset 0x02c $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m01_axi $regparam 

set reg      [::ipx::add_register -quiet "out_1_ptr" $addr_block]
  set_property address_offset 0x034 $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m01_axi $regparam 

set reg      [::ipx::add_register -quiet "in_2_ptr" $addr_block]
  set_property address_offset 0x03c $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m02_axi $regparam 

set reg      [::ipx::add_register -quiet "out_2_ptr" $addr_block]
  set_property address_offset 0x044 $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m02_axi $regparam 

set reg      [::ipx::add_register -quiet "in_3_ptr" $addr_block]
  set_property address_offset 0x04c $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m03_axi $regparam 

set reg      [::ipx::add_register -quiet "out_3_ptr" $addr_block]
  set_property address_offset 0x054 $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m03_axi $regparam 

set reg      [::ipx::add_register -quiet "in_4_ptr" $addr_block]
  set_property address_offset 0x05c $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m04_axi $regparam 

set reg      [::ipx::add_register -quiet "out_4_ptr" $addr_block]
  set_property address_offset 0x064 $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m04_axi $regparam 

set reg      [::ipx::add_register -quiet "in_5_ptr" $addr_block]
  set_property address_offset 0x06c $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m05_axi $regparam 

set reg      [::ipx::add_register -quiet "out_5_ptr" $addr_block]
  set_property address_offset 0x074 $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m05_axi $regparam 

set reg      [::ipx::add_register -quiet "in_6_ptr" $addr_block]
  set_property address_offset 0x07c $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m06_axi $regparam 

set reg      [::ipx::add_register -quiet "out_6_ptr" $addr_block]
  set_property address_offset 0x084 $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m06_axi $regparam 

set reg      [::ipx::add_register -quiet "in_7_ptr" $addr_block]
  set_property address_offset 0x08c $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m07_axi $regparam 

set reg      [::ipx::add_register -quiet "out_7_ptr" $addr_block]
  set_property address_offset 0x094 $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m07_axi $regparam 

set reg      [::ipx::add_register -quiet "in_8_ptr" $addr_block]
  set_property address_offset 0x09c $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m08_axi $regparam 

set reg      [::ipx::add_register -quiet "out_8_ptr" $addr_block]
  set_property address_offset 0x0a4 $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m08_axi $regparam 

set reg      [::ipx::add_register -quiet "in_9_ptr" $addr_block]
  set_property address_offset 0x0ac $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m09_axi $regparam 

set reg      [::ipx::add_register -quiet "out_9_ptr" $addr_block]
  set_property address_offset 0x0b4 $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m09_axi $regparam 

set reg      [::ipx::add_register -quiet "in_10_ptr" $addr_block]
  set_property address_offset 0x0bc $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m10_axi $regparam 

set reg      [::ipx::add_register -quiet "out_10_ptr" $addr_block]
  set_property address_offset 0x0c4 $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m10_axi $regparam 

set reg      [::ipx::add_register -quiet "in_11_ptr" $addr_block]
  set_property address_offset 0x0cc $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m11_axi $regparam 

set reg      [::ipx::add_register -quiet "out_11_ptr" $addr_block]
  set_property address_offset 0x0d4 $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m11_axi $regparam 

set reg      [::ipx::add_register -quiet "in_12_ptr" $addr_block]
  set_property address_offset 0x0dc $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m12_axi $regparam 

set reg      [::ipx::add_register -quiet "out_12_ptr" $addr_block]
  set_property address_offset 0x0e4 $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m12_axi $regparam 

set reg      [::ipx::add_register -quiet "in_13_ptr" $addr_block]
  set_property address_offset 0x0ec $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m13_axi $regparam 

set reg      [::ipx::add_register -quiet "out_13_ptr" $addr_block]
  set_property address_offset 0x0f4 $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m13_axi $regparam 

set reg      [::ipx::add_register -quiet "in_14_ptr" $addr_block]
  set_property address_offset 0x0fc $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m14_axi $regparam 

set reg      [::ipx::add_register -quiet "out_14_ptr" $addr_block]
  set_property address_offset 0x104 $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m14_axi $regparam 

set reg      [::ipx::add_register -quiet "in_15_ptr" $addr_block]
  set_property address_offset 0x10c $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m15_axi $regparam 

set reg      [::ipx::add_register -quiet "out_15_ptr" $addr_block]
  set_property address_offset 0x114 $reg
  set_property size           [expr {8*8}]   $reg
  set regparam [::ipx::add_register_parameter -quiet {ASSOCIATED_BUSIF} $reg] 
  set_property value m15_axi $regparam 

set_property slave_memory_map_ref "s_axi_control" [::ipx::get_bus_interfaces -of $core "s_axi_control"]

set_property xpm_libraries {XPM_CDC XPM_MEMORY XPM_FIFO} $core
set_property sdx_kernel true $core
set_property sdx_kernel_type rtl $core
set_property supported_families { } $core
set_property auto_family_support_level level_2 $core
ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::check_integrity -kernel $core
ipx::save_core $core
close_project -delete
