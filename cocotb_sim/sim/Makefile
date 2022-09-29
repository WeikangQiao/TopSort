TOPLEVEL_LANG = verilog

#Specify simulator
SIM ?= vcs

#Specify top-level module name
DUT      	= merge_sort_complete
TOPLEVEL 	= $(DUT)
MODULE   	= test_$(DUT)

#Specify source files
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/user_def_pkg.sv
VERILOG_SOURCES += $(shell pwd)/../rtl/$(DUT).sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/addr_cal_phase2.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/addr_cal_read_phase2.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/addr_cal_wr_phase1.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/addr_cal_write_phase2.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/addr_cal.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/axi_bus_ifd.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/axi_conv_wr_rd.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/axi_conv.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/axi_pipeline.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/axi_rd_register.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/axi_read_master.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/axi_register.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/axi_transaction_counter.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/axi_wr_mux_2to1_type2.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/axi_wr_mux_2to1.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/axi_wr_register.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/axi_write_master_phase2.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/axi_write_master.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/axil_register.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/bitonic_merger_l.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/bitonic_merger_s.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/cas.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/control_s_axil.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/coupler.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/delay_chain.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/dsp_ch_addr.sv
VERILOG_SOURCES += $(shell pwd)/../rtl/DSP48E2.v
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/fifo_gen_register.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/fifo_ifd.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/fifo_register.sv
VERILOG_SOURCES += $(shell pwd)/../rtl/glbl.v
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/hls_fifo.v
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/merge_integration.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/merge_logic_demux.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/merge_logic.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/merge_network.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/merge_tree_assembler.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/merge_tree_dispatch.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/merge_tree_phase2_top.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/merge_tree_phase2.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/merge_tree_reuse_type2_top.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/merge_tree_reuse_type2.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/merge_tree_reuse.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/merge_tree_top.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/merge_tree.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/mux.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/presorter.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/qreg.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/qshift_fifo.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/relay_station.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/shift_reg.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/simple_reg.sv
VERILOG_SOURCES += $(shell pwd)/../../src/hdl/srl_buf.sv
VERILOG_SOURCES += $(shell pwd)/../rtl/SRLC16E.v
VERILOG_SOURCES += $(shell pwd)/../rtl/SRLC32E.v
VERILOG_SOURCES += $(shell pwd)/../rtl/xpm_fifo.sv
VERILOG_SOURCES += $(shell pwd)/../rtl/xpm_memory.sv

#Module parameters
#export PARAM_C_S_AXI_CONTROL_ADDR_WIDTH ?= 9 
#export PARAM_C_S_AXI_CONTROL_DATA_WIDTH ?= 32 
#export PARAM_C_M_AXI_ID_WIDTH ?= 4   
#export PARAM_C_M_AXI_ADDR_WIDTH ?= 64 
#export PARAM_C_M_AXI_DATA_WIDTH ?= 512
#export PARAM_C_XFER_SIZE_WIDTH ?= 32
#export PARAM_C_RECORD_BIT_WIDTH ?= 64 
#export PARAM_C_RECORD_KEY_WIDTH ?= 32
#export PARAM_C_INIT_SORTED_CHUNK ?= 1 
#export PARAM_C_ROOT_BUNDLE_WIDTH?= 8  
#export PARAM_C_NUM_LEAVES ?= 16
#export PARAM_C_GRAIN_IN_BYTES ?= 4096

#Compile flags
COMPILE_ARGS += -notice
COMPILE_ARGS += +incdir+$(shell pwd)/../../src/hdl/
COMPILE_ARGS += +define+TEST_PHASE_1
#COMPILE_ARGS += -pvalue+$(TOPLEVEL).C_S_AXI_CONTROL_ADDR_WIDTH=$(PARAM_C_S_AXI_CONTROL_ADDR_WIDTH)
#COMPILE_ARGS += -pvalue+$(TOPLEVEL).C_S_AXI_CONTROL_DATA_WIDTH=$(PARAM_C_S_AXI_CONTROL_DATA_WIDTH)
#COMPILE_ARGS += -pvalue+$(TOPLEVEL).C_M_AXI_ID_WIDTH=$(PARAM_C_M_AXI_ID_WIDTH)
#COMPILE_ARGS += -pvalue+$(TOPLEVEL).C_M_AXI_ADDR_WIDTH=$(PARAM_C_M_AXI_ADDR_WIDTH)
#COMPILE_ARGS += -pvalue+$(TOPLEVEL).C_M_AXI_DATA_WIDTH=$(PARAM_C_M_AXI_DATA_WIDTH)
#COMPILE_ARGS += -pvalue+$(TOPLEVEL).C_XFER_SIZE_WIDTH=$(PARAM_C_XFER_SIZE_WIDTH)
#COMPILE_ARGS += -pvalue+$(TOPLEVEL).C_RECORD_BIT_WIDTH=$(PARAM_C_RECORD_BIT_WIDTH)
#COMPILE_ARGS += -pvalue+$(TOPLEVEL).C_RECORD_KEY_WIDTH=$(PARAM_C_RECORD_KEY_WIDTH)
#COMPILE_ARGS += -pvalue+$(TOPLEVEL).C_INIT_SORTED_CHUNK=$(PARAM_C_INIT_SORTED_CHUNK)
#COMPILE_ARGS += -pvalue+$(TOPLEVEL).C_ROOT_BUNDLE_WIDTH=$(PARAM_C_ROOT_BUNDLE_WIDTH)
#COMPILE_ARGS += -pvalue+$(TOPLEVEL).C_NUM_LEAVES=$(PARAM_C_NUM_LEAVES)
#COMPILE_ARGS += -pvalue+$(TOPLEVEL).C_GRAIN_IN_BYTES=$(PARAM_C_GRAIN_IN_BYTES)

include $(shell cocotb-config --makefiles)/Makefile.sim

clean::
	@rm -rf $(DUT).vpd
	@rm -rf __pycache__
	@rm -rf DVEfiles
	@rm -rf sim_build
	@rm -rf results.xml
	@rm -rf ucli.key