VIVADO := $(XILINX_VIVADO)/bin/vivado
$(TEMP_DIR)/merge_sort_complete.xo: scripts/package_kernel.tcl scripts/gen_xo.tcl src/hdl/*.sv 
	mkdir -p $(TEMP_DIR)
	$(VIVADO) -mode batch -source scripts/gen_xo.tcl -tclargs $(TEMP_DIR)/merge_sort_complete.xo merge_sort_complete $(TARGET) $(DEVICE) $(XSA)
