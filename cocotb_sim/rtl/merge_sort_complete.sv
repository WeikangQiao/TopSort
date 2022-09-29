/**********************************************************************************
 *  The top module of the complete merge sort, it contains two phases
 * 
**********************************************************************************/

`include "macro_def.sv"
module merge_sort_complete 
  import user_def_pkg::*;
(
  // System Signals
  input  logic                                    ap_clk                  ,
  input  logic                                    ap_rst_n                ,

  // AXI4 master interface m00_axi
  output logic                                    m00_axi_awvalid      ,
  input  logic                                    m00_axi_awready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m00_axi_awaddr       ,
  output logic [1:0]                              m00_axi_awburst      ,
  output logic [7:0]                              m00_axi_awlen        ,
  output logic [2:0]                              m00_axi_awsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m00_axi_awid         ,

  output logic                                    m00_axi_wvalid       ,
  input  logic                                    m00_axi_wready       ,
  output logic [C_M_AXI_DATA_WIDTH-1:0]           m00_axi_wdata        ,
  output logic [C_M_AXI_DATA_WIDTH/8-1:0]         m00_axi_wstrb        ,
  output logic                                    m00_axi_wlast        ,

  input  logic                                    m00_axi_bvalid       ,
  output logic                                    m00_axi_bready       ,
  input  logic [1:0]                              m00_axi_bresp        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m00_axi_bid          ,

  output logic                                    m00_axi_arvalid      ,
  input  logic                                    m00_axi_arready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m00_axi_araddr       ,
  output logic [1:0]                              m00_axi_arburst      ,
  output logic [7:0]                              m00_axi_arlen        ,
  output logic [2:0]                              m00_axi_arsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m00_axi_arid         ,

  input  logic                                    m00_axi_rvalid       ,
  output logic                                    m00_axi_rready       ,
  input  logic [C_M_AXI_DATA_WIDTH-1:0]           m00_axi_rdata        ,
  input  logic                                    m00_axi_rlast        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m00_axi_rid          ,
  input  logic [1:0]                              m00_axi_rresp        ,
  // AXI4 master interface m01_axi
  output logic                                    m01_axi_awvalid      ,
  input  logic                                    m01_axi_awready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m01_axi_awaddr       ,
  output logic [1:0]                              m01_axi_awburst      ,
  output logic [7:0]                              m01_axi_awlen        ,
  output logic [2:0]                              m01_axi_awsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m01_axi_awid         ,

  output logic                                    m01_axi_wvalid       ,
  input  logic                                    m01_axi_wready       ,
  output logic [C_M_AXI_DATA_WIDTH-1:0]           m01_axi_wdata        ,
  output logic [C_M_AXI_DATA_WIDTH/8-1:0]         m01_axi_wstrb        ,
  output logic                                    m01_axi_wlast        ,

  input  logic                                    m01_axi_bvalid       ,
  output logic                                    m01_axi_bready       ,
  input  logic [1:0]                              m01_axi_bresp        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m01_axi_bid          ,

  output logic                                    m01_axi_arvalid      ,
  input  logic                                    m01_axi_arready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m01_axi_araddr       ,
  output logic [1:0]                              m01_axi_arburst      ,
  output logic [7:0]                              m01_axi_arlen        ,
  output logic [2:0]                              m01_axi_arsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m01_axi_arid         ,

  input  logic                                    m01_axi_rvalid       ,
  output logic                                    m01_axi_rready       ,
  input  logic [C_M_AXI_DATA_WIDTH-1:0]           m01_axi_rdata        ,
  input  logic                                    m01_axi_rlast        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m01_axi_rid          ,
  input  logic [1:0]                              m01_axi_rresp        ,
  // AXI4 master interface m02_axi
  output logic                                    m02_axi_awvalid      ,
  input  logic                                    m02_axi_awready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m02_axi_awaddr       ,
  output logic [1:0]                              m02_axi_awburst      ,
  output logic [7:0]                              m02_axi_awlen        ,
  output logic [2:0]                              m02_axi_awsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m02_axi_awid         ,

  output logic                                    m02_axi_wvalid       ,
  input  logic                                    m02_axi_wready       ,
  output logic [C_M_AXI_DATA_WIDTH-1:0]           m02_axi_wdata        ,
  output logic [C_M_AXI_DATA_WIDTH/8-1:0]         m02_axi_wstrb        ,
  output logic                                    m02_axi_wlast        ,

  input  logic                                    m02_axi_bvalid       ,
  output logic                                    m02_axi_bready       ,
  input  logic [1:0]                              m02_axi_bresp        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m02_axi_bid          ,

  output logic                                    m02_axi_arvalid      ,
  input  logic                                    m02_axi_arready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m02_axi_araddr       ,
  output logic [1:0]                              m02_axi_arburst      ,
  output logic [7:0]                              m02_axi_arlen        ,
  output logic [2:0]                              m02_axi_arsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m02_axi_arid         ,

  input  logic                                    m02_axi_rvalid       ,
  output logic                                    m02_axi_rready       ,
  input  logic [C_M_AXI_DATA_WIDTH-1:0]           m02_axi_rdata        ,
  input  logic                                    m02_axi_rlast        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m02_axi_rid          ,
  input  logic [1:0]                              m02_axi_rresp        ,
  // AXI4 master interface m03_axi
  output logic                                    m03_axi_awvalid      ,
  input  logic                                    m03_axi_awready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m03_axi_awaddr       ,
  output logic [1:0]                              m03_axi_awburst      ,
  output logic [7:0]                              m03_axi_awlen        ,
  output logic [2:0]                              m03_axi_awsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m03_axi_awid         ,

  output logic                                    m03_axi_wvalid       ,
  input  logic                                    m03_axi_wready       ,
  output logic [C_M_AXI_DATA_WIDTH-1:0]           m03_axi_wdata        ,
  output logic [C_M_AXI_DATA_WIDTH/8-1:0]         m03_axi_wstrb        ,
  output logic                                    m03_axi_wlast        ,

  input  logic                                    m03_axi_bvalid       ,
  output logic                                    m03_axi_bready       ,
  input  logic [1:0]                              m03_axi_bresp        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m03_axi_bid          ,

  output logic                                    m03_axi_arvalid      ,
  input  logic                                    m03_axi_arready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m03_axi_araddr       ,
  output logic [1:0]                              m03_axi_arburst      ,
  output logic [7:0]                              m03_axi_arlen        ,
  output logic [2:0]                              m03_axi_arsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m03_axi_arid         ,

  input  logic                                    m03_axi_rvalid       ,
  output logic                                    m03_axi_rready       ,
  input  logic [C_M_AXI_DATA_WIDTH-1:0]           m03_axi_rdata        ,
  input  logic                                    m03_axi_rlast        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m03_axi_rid          ,
  input  logic [1:0]                              m03_axi_rresp        ,
  // AXI4 master interface m04_axi
  output logic                                    m04_axi_awvalid      ,
  input  logic                                    m04_axi_awready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m04_axi_awaddr       ,
  output logic [1:0]                              m04_axi_awburst      ,
  output logic [7:0]                              m04_axi_awlen        ,
  output logic [2:0]                              m04_axi_awsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m04_axi_awid         ,

  output logic                                    m04_axi_wvalid       ,
  input  logic                                    m04_axi_wready       ,
  output logic [C_M_AXI_DATA_WIDTH-1:0]           m04_axi_wdata        ,
  output logic [C_M_AXI_DATA_WIDTH/8-1:0]         m04_axi_wstrb        ,
  output logic                                    m04_axi_wlast        ,

  input  logic                                    m04_axi_bvalid       ,
  output logic                                    m04_axi_bready       ,
  input  logic [1:0]                              m04_axi_bresp        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m04_axi_bid          ,

  output logic                                    m04_axi_arvalid      ,
  input  logic                                    m04_axi_arready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m04_axi_araddr       ,
  output logic [1:0]                              m04_axi_arburst      ,
  output logic [7:0]                              m04_axi_arlen        ,
  output logic [2:0]                              m04_axi_arsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m04_axi_arid         ,

  input  logic                                    m04_axi_rvalid       ,
  output logic                                    m04_axi_rready       ,
  input  logic [C_M_AXI_DATA_WIDTH-1:0]           m04_axi_rdata        ,
  input  logic                                    m04_axi_rlast        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m04_axi_rid          ,
  input  logic [1:0]                              m04_axi_rresp        ,
  // AXI4 master interface m05_axi
  output logic                                    m05_axi_awvalid      ,
  input  logic                                    m05_axi_awready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m05_axi_awaddr       ,
  output logic [1:0]                              m05_axi_awburst      ,
  output logic [7:0]                              m05_axi_awlen        ,
  output logic [2:0]                              m05_axi_awsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m05_axi_awid         ,

  output logic                                    m05_axi_wvalid       ,
  input  logic                                    m05_axi_wready       ,
  output logic [C_M_AXI_DATA_WIDTH-1:0]           m05_axi_wdata        ,
  output logic [C_M_AXI_DATA_WIDTH/8-1:0]         m05_axi_wstrb        ,
  output logic                                    m05_axi_wlast        ,

  input  logic                                    m05_axi_bvalid       ,
  output logic                                    m05_axi_bready       ,
  input  logic [1:0]                              m05_axi_bresp        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m05_axi_bid          ,

  output logic                                    m05_axi_arvalid      ,
  input  logic                                    m05_axi_arready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m05_axi_araddr       ,
  output logic [1:0]                              m05_axi_arburst      ,
  output logic [7:0]                              m05_axi_arlen        ,
  output logic [2:0]                              m05_axi_arsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m05_axi_arid         ,

  input  logic                                    m05_axi_rvalid       ,
  output logic                                    m05_axi_rready       ,
  input  logic [C_M_AXI_DATA_WIDTH-1:0]           m05_axi_rdata        ,
  input  logic                                    m05_axi_rlast        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m05_axi_rid          ,
  input  logic [1:0]                              m05_axi_rresp        ,
  // AXI4 master interface m06_axi
  output logic                                    m06_axi_awvalid      ,
  input  logic                                    m06_axi_awready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m06_axi_awaddr       ,
  output logic [1:0]                              m06_axi_awburst      ,
  output logic [7:0]                              m06_axi_awlen        ,
  output logic [2:0]                              m06_axi_awsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m06_axi_awid         ,

  output logic                                    m06_axi_wvalid       ,
  input  logic                                    m06_axi_wready       ,
  output logic [C_M_AXI_DATA_WIDTH-1:0]           m06_axi_wdata        ,
  output logic [C_M_AXI_DATA_WIDTH/8-1:0]         m06_axi_wstrb        ,
  output logic                                    m06_axi_wlast        ,

  input  logic                                    m06_axi_bvalid       ,
  output logic                                    m06_axi_bready       ,
  input  logic [1:0]                              m06_axi_bresp        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m06_axi_bid          ,

  output logic                                    m06_axi_arvalid      ,
  input  logic                                    m06_axi_arready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m06_axi_araddr       ,
  output logic [1:0]                              m06_axi_arburst      ,
  output logic [7:0]                              m06_axi_arlen        ,
  output logic [2:0]                              m06_axi_arsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m06_axi_arid         ,

  input  logic                                    m06_axi_rvalid       ,
  output logic                                    m06_axi_rready       ,
  input  logic [C_M_AXI_DATA_WIDTH-1:0]           m06_axi_rdata        ,
  input  logic                                    m06_axi_rlast        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m06_axi_rid          ,
  input  logic [1:0]                              m06_axi_rresp        ,
  // AXI4 master interface m07_axi
  output logic                                    m07_axi_awvalid      ,
  input  logic                                    m07_axi_awready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m07_axi_awaddr       ,
  output logic [1:0]                              m07_axi_awburst      ,
  output logic [7:0]                              m07_axi_awlen        ,
  output logic [2:0]                              m07_axi_awsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m07_axi_awid         ,

  output logic                                    m07_axi_wvalid       ,
  input  logic                                    m07_axi_wready       ,
  output logic [C_M_AXI_DATA_WIDTH-1:0]           m07_axi_wdata        ,
  output logic [C_M_AXI_DATA_WIDTH/8-1:0]         m07_axi_wstrb        ,
  output logic                                    m07_axi_wlast        ,

  input  logic                                    m07_axi_bvalid       ,
  output logic                                    m07_axi_bready       ,
  input  logic [1:0]                              m07_axi_bresp        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m07_axi_bid          ,

  output logic                                    m07_axi_arvalid      ,
  input  logic                                    m07_axi_arready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m07_axi_araddr       ,
  output logic [1:0]                              m07_axi_arburst      ,
  output logic [7:0]                              m07_axi_arlen        ,
  output logic [2:0]                              m07_axi_arsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m07_axi_arid         ,

  input  logic                                    m07_axi_rvalid       ,
  output logic                                    m07_axi_rready       ,
  input  logic [C_M_AXI_DATA_WIDTH-1:0]           m07_axi_rdata        ,
  input  logic                                    m07_axi_rlast        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m07_axi_rid          ,
  input  logic [1:0]                              m07_axi_rresp        ,
  // AXI4 master interface m08_axi
  output logic                                    m08_axi_awvalid      ,
  input  logic                                    m08_axi_awready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m08_axi_awaddr       ,
  output logic [1:0]                              m08_axi_awburst      ,
  output logic [7:0]                              m08_axi_awlen        ,
  output logic [2:0]                              m08_axi_awsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m08_axi_awid         ,

  output logic                                    m08_axi_wvalid       ,
  input  logic                                    m08_axi_wready       ,
  output logic [C_M_AXI_DATA_WIDTH-1:0]           m08_axi_wdata        ,
  output logic [C_M_AXI_DATA_WIDTH/8-1:0]         m08_axi_wstrb        ,
  output logic                                    m08_axi_wlast        ,

  input  logic                                    m08_axi_bvalid       ,
  output logic                                    m08_axi_bready       ,
  input  logic [1:0]                              m08_axi_bresp        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m08_axi_bid          ,

  output logic                                    m08_axi_arvalid      ,
  input  logic                                    m08_axi_arready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m08_axi_araddr       ,
  output logic [1:0]                              m08_axi_arburst      ,
  output logic [7:0]                              m08_axi_arlen        ,
  output logic [2:0]                              m08_axi_arsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m08_axi_arid         ,

  input  logic                                    m08_axi_rvalid       ,
  output logic                                    m08_axi_rready       ,
  input  logic [C_M_AXI_DATA_WIDTH-1:0]           m08_axi_rdata        ,
  input  logic                                    m08_axi_rlast        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m08_axi_rid          ,
  input  logic [1:0]                              m08_axi_rresp        ,
  // AXI4 master interface m09_axi
  output logic                                    m09_axi_awvalid      ,
  input  logic                                    m09_axi_awready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m09_axi_awaddr       ,
  output logic [1:0]                              m09_axi_awburst      ,
  output logic [7:0]                              m09_axi_awlen        ,
  output logic [2:0]                              m09_axi_awsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m09_axi_awid         ,

  output logic                                    m09_axi_wvalid       ,
  input  logic                                    m09_axi_wready       ,
  output logic [C_M_AXI_DATA_WIDTH-1:0]           m09_axi_wdata        ,
  output logic [C_M_AXI_DATA_WIDTH/8-1:0]         m09_axi_wstrb        ,
  output logic                                    m09_axi_wlast        ,

  input  logic                                    m09_axi_bvalid       ,
  output logic                                    m09_axi_bready       ,
  input  logic [1:0]                              m09_axi_bresp        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m09_axi_bid          ,

  output logic                                    m09_axi_arvalid      ,
  input  logic                                    m09_axi_arready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m09_axi_araddr       ,
  output logic [1:0]                              m09_axi_arburst      ,
  output logic [7:0]                              m09_axi_arlen        ,
  output logic [2:0]                              m09_axi_arsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m09_axi_arid         ,

  input  logic                                    m09_axi_rvalid       ,
  output logic                                    m09_axi_rready       ,
  input  logic [C_M_AXI_DATA_WIDTH-1:0]           m09_axi_rdata        ,
  input  logic                                    m09_axi_rlast        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m09_axi_rid          ,
  input  logic [1:0]                              m09_axi_rresp        ,
  // AXI4 master interface m10_axi
  output logic                                    m10_axi_awvalid      ,
  input  logic                                    m10_axi_awready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m10_axi_awaddr       ,
  output logic [1:0]                              m10_axi_awburst      ,
  output logic [7:0]                              m10_axi_awlen        ,
  output logic [2:0]                              m10_axi_awsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m10_axi_awid         ,

  output logic                                    m10_axi_wvalid       ,
  input  logic                                    m10_axi_wready       ,
  output logic [C_M_AXI_DATA_WIDTH-1:0]           m10_axi_wdata        ,
  output logic [C_M_AXI_DATA_WIDTH/8-1:0]         m10_axi_wstrb        ,
  output logic                                    m10_axi_wlast        ,

  input  logic                                    m10_axi_bvalid       ,
  output logic                                    m10_axi_bready       ,
  input  logic [1:0]                              m10_axi_bresp        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m10_axi_bid          ,

  output logic                                    m10_axi_arvalid      ,
  input  logic                                    m10_axi_arready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m10_axi_araddr       ,
  output logic [1:0]                              m10_axi_arburst      ,
  output logic [7:0]                              m10_axi_arlen        ,
  output logic [2:0]                              m10_axi_arsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m10_axi_arid         ,

  input  logic                                    m10_axi_rvalid       ,
  output logic                                    m10_axi_rready       ,
  input  logic [C_M_AXI_DATA_WIDTH-1:0]           m10_axi_rdata        ,
  input  logic                                    m10_axi_rlast        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m10_axi_rid          ,
  input  logic [1:0]                              m10_axi_rresp        ,
  // AXI4 master interface m11_axi
  output logic                                    m11_axi_awvalid      ,
  input  logic                                    m11_axi_awready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m11_axi_awaddr       ,
  output logic [1:0]                              m11_axi_awburst      ,
  output logic [7:0]                              m11_axi_awlen        ,
  output logic [2:0]                              m11_axi_awsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m11_axi_awid         ,

  output logic                                    m11_axi_wvalid       ,
  input  logic                                    m11_axi_wready       ,
  output logic [C_M_AXI_DATA_WIDTH-1:0]           m11_axi_wdata        ,
  output logic [C_M_AXI_DATA_WIDTH/8-1:0]         m11_axi_wstrb        ,
  output logic                                    m11_axi_wlast        ,

  input  logic                                    m11_axi_bvalid       ,
  output logic                                    m11_axi_bready       ,
  input  logic [1:0]                              m11_axi_bresp        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m11_axi_bid          ,

  output logic                                    m11_axi_arvalid      ,
  input  logic                                    m11_axi_arready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m11_axi_araddr       ,
  output logic [1:0]                              m11_axi_arburst      ,
  output logic [7:0]                              m11_axi_arlen        ,
  output logic [2:0]                              m11_axi_arsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m11_axi_arid         ,

  input  logic                                    m11_axi_rvalid       ,
  output logic                                    m11_axi_rready       ,
  input  logic [C_M_AXI_DATA_WIDTH-1:0]           m11_axi_rdata        ,
  input  logic                                    m11_axi_rlast        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m11_axi_rid          ,
  input  logic [1:0]                              m11_axi_rresp        ,
  // AXI4 master interface m12_axi
  output logic                                    m12_axi_awvalid      ,
  input  logic                                    m12_axi_awready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m12_axi_awaddr       ,
  output logic [1:0]                              m12_axi_awburst      ,
  output logic [7:0]                              m12_axi_awlen        ,
  output logic [2:0]                              m12_axi_awsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m12_axi_awid         ,

  output logic                                    m12_axi_wvalid       ,
  input  logic                                    m12_axi_wready       ,
  output logic [C_M_AXI_DATA_WIDTH-1:0]           m12_axi_wdata        ,
  output logic [C_M_AXI_DATA_WIDTH/8-1:0]         m12_axi_wstrb        ,
  output logic                                    m12_axi_wlast        ,

  input  logic                                    m12_axi_bvalid       ,
  output logic                                    m12_axi_bready       ,
  input  logic [1:0]                              m12_axi_bresp        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m12_axi_bid          ,

  output logic                                    m12_axi_arvalid      ,
  input  logic                                    m12_axi_arready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m12_axi_araddr       ,
  output logic [1:0]                              m12_axi_arburst      ,
  output logic [7:0]                              m12_axi_arlen        ,
  output logic [2:0]                              m12_axi_arsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m12_axi_arid         ,

  input  logic                                    m12_axi_rvalid       ,
  output logic                                    m12_axi_rready       ,
  input  logic [C_M_AXI_DATA_WIDTH-1:0]           m12_axi_rdata        ,
  input  logic                                    m12_axi_rlast        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m12_axi_rid          ,
  input  logic [1:0]                              m12_axi_rresp        ,
  // AXI4 master interface m13_axi
  output logic                                    m13_axi_awvalid      ,
  input  logic                                    m13_axi_awready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m13_axi_awaddr       ,
  output logic [1:0]                              m13_axi_awburst      ,
  output logic [7:0]                              m13_axi_awlen        ,
  output logic [2:0]                              m13_axi_awsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m13_axi_awid         ,

  output logic                                    m13_axi_wvalid       ,
  input  logic                                    m13_axi_wready       ,
  output logic [C_M_AXI_DATA_WIDTH-1:0]           m13_axi_wdata        ,
  output logic [C_M_AXI_DATA_WIDTH/8-1:0]         m13_axi_wstrb        ,
  output logic                                    m13_axi_wlast        ,

  input  logic                                    m13_axi_bvalid       ,
  output logic                                    m13_axi_bready       ,
  input  logic [1:0]                              m13_axi_bresp        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m13_axi_bid          ,

  output logic                                    m13_axi_arvalid      ,
  input  logic                                    m13_axi_arready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m13_axi_araddr       ,
  output logic [1:0]                              m13_axi_arburst      ,
  output logic [7:0]                              m13_axi_arlen        ,
  output logic [2:0]                              m13_axi_arsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m13_axi_arid         ,

  input  logic                                    m13_axi_rvalid       ,
  output logic                                    m13_axi_rready       ,
  input  logic [C_M_AXI_DATA_WIDTH-1:0]           m13_axi_rdata        ,
  input  logic                                    m13_axi_rlast        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m13_axi_rid          ,
  input  logic [1:0]                              m13_axi_rresp        ,
  // AXI4 master interface m14_axi
  output logic                                    m14_axi_awvalid      ,
  input  logic                                    m14_axi_awready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m14_axi_awaddr       ,
  output logic [1:0]                              m14_axi_awburst      ,
  output logic [7:0]                              m14_axi_awlen        ,
  output logic [2:0]                              m14_axi_awsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m14_axi_awid         ,

  output logic                                    m14_axi_wvalid       ,
  input  logic                                    m14_axi_wready       ,
  output logic [C_M_AXI_DATA_WIDTH-1:0]           m14_axi_wdata        ,
  output logic [C_M_AXI_DATA_WIDTH/8-1:0]         m14_axi_wstrb        ,
  output logic                                    m14_axi_wlast        ,

  input  logic                                    m14_axi_bvalid       ,
  output logic                                    m14_axi_bready       ,
  input  logic [1:0]                              m14_axi_bresp        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m14_axi_bid          ,

  output logic                                    m14_axi_arvalid      ,
  input  logic                                    m14_axi_arready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m14_axi_araddr       ,
  output logic [1:0]                              m14_axi_arburst      ,
  output logic [7:0]                              m14_axi_arlen        ,
  output logic [2:0]                              m14_axi_arsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m14_axi_arid         ,

  input  logic                                    m14_axi_rvalid       ,
  output logic                                    m14_axi_rready       ,
  input  logic [C_M_AXI_DATA_WIDTH-1:0]           m14_axi_rdata        ,
  input  logic                                    m14_axi_rlast        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m14_axi_rid          ,
  input  logic [1:0]                              m14_axi_rresp        ,
  // AXI4 master interface m15_axi
  output logic                                    m15_axi_awvalid      ,
  input  logic                                    m15_axi_awready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m15_axi_awaddr       ,
  output logic [1:0]                              m15_axi_awburst      ,
  output logic [7:0]                              m15_axi_awlen        ,
  output logic [2:0]                              m15_axi_awsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m15_axi_awid         ,

  output logic                                    m15_axi_wvalid       ,
  input  logic                                    m15_axi_wready       ,
  output logic [C_M_AXI_DATA_WIDTH-1:0]           m15_axi_wdata        ,
  output logic [C_M_AXI_DATA_WIDTH/8-1:0]         m15_axi_wstrb        ,
  output logic                                    m15_axi_wlast        ,

  input  logic                                    m15_axi_bvalid       ,
  output logic                                    m15_axi_bready       ,
  input  logic [1:0]                              m15_axi_bresp        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m15_axi_bid          ,

  output logic                                    m15_axi_arvalid      ,
  input  logic                                    m15_axi_arready      ,
  output logic [C_M_AXI_ADDR_WIDTH-1:0]           m15_axi_araddr       ,
  output logic [1:0]                              m15_axi_arburst      ,
  output logic [7:0]                              m15_axi_arlen        ,
  output logic [2:0]                              m15_axi_arsize       ,
  output logic [C_M_AXI_ID_WIDTH-1:0]             m15_axi_arid         ,

  input  logic                                    m15_axi_rvalid       ,
  output logic                                    m15_axi_rready       ,
  input  logic [C_M_AXI_DATA_WIDTH-1:0]           m15_axi_rdata        ,
  input  logic                                    m15_axi_rlast        ,
  input  logic [C_M_AXI_ID_WIDTH-1:0]             m15_axi_rid          ,
  input  logic [1:0]                              m15_axi_rresp        ,
  // AXI4-Lite slave interface
  input  logic                                    s_axi_control_awvalid,
  output logic                                    s_axi_control_awready,
  input  logic [C_S_AXI_CONTROL_ADDR_WIDTH-1:0]   s_axi_control_awaddr ,
  input  logic                                    s_axi_control_wvalid ,
  output logic                                    s_axi_control_wready ,
  input  logic [C_S_AXI_CONTROL_DATA_WIDTH-1:0]   s_axi_control_wdata  ,
  input  logic [C_S_AXI_CONTROL_DATA_WIDTH/8-1:0] s_axi_control_wstrb  ,
  input  logic                                    s_axi_control_arvalid,
  output logic                                    s_axi_control_arready,
  input  logic [C_S_AXI_CONTROL_ADDR_WIDTH-1:0]   s_axi_control_araddr ,
  output logic                                    s_axi_control_rvalid ,
  input  logic                                    s_axi_control_rready ,
  output logic [C_S_AXI_CONTROL_DATA_WIDTH-1:0]   s_axi_control_rdata  ,
  output logic [1:0]                              s_axi_control_rresp  ,
  output logic                                    s_axi_control_bvalid ,
  input  logic                                    s_axi_control_bready ,
  output logic [1:0]                              s_axi_control_bresp  ,
  output logic                                    interrupt            
);

///////////////////////////////////////////////////////////////////////////////////
//Declarations
///////////////////////////////////////////////////////////////////////////////////

// Local Parameters
localparam integer  LP_NUM_MERGE_TREES  = 16;
localparam integer  LP_ROOT_DATA_WIDTH  = C_ROOT_BUNDLE_WIDTH*C_RECORD_BIT_WIDTH+1;

// Variables for AXI-Lite register
logic [C_S_AXI_CONTROL_ADDR_WIDTH-1:0]  m_axil_awaddr               ;   
logic                                   m_axil_awvalid              ;   
logic                                   m_axil_awready              ;   

logic [32-1:0]                          m_axil_wdata                ;
logic [4-1:0]                           m_axil_wstrb                ;
logic                                   m_axil_wvalid               ;
logic                                   m_axil_wready               ;

logic [1:0]                             m_axil_bresp                ;
logic                                   m_axil_bvalid               ;
logic                                   m_axil_bready               ;

logic [C_S_AXI_CONTROL_ADDR_WIDTH-1:0]  m_axil_araddr               ;
logic                                   m_axil_arvalid              ;
logic                                   m_axil_arready              ;

logic [32-1:0]                          m_axil_rdata                ;
logic [1:0]                             m_axil_rresp                ;
logic                                   m_axil_rvalid               ;
logic                                   m_axil_rready               ;

// Variables for control & scalars
logic                                   areset                      ;
logic                                   ap_start                    ;
logic                                   ap_idle     = 1'b1          ;
logic                                   ap_done                     ;

(* KEEP = "yes" *)logic                 ap_start_r = 1'b0           ;
logic                                   ap_start_p1                 ;
logic                                   ap_start_p2 = 1'b0          ;
logic [LP_NUM_MERGE_TREES-1:0]          ap_done_p1_i                ;
logic [LP_NUM_MERGE_TREES-1:0]          ap_done_p1_r   = '0         ;
logic                                   ap_done_p1                  ;
logic [3:0]                             ap_done_p2_i                ;
logic [3:0]                             ap_done_p2_r   = '0         ;
logic                                   ap_done_p2                  ;
logic                                   ap_done_p2_pipe             ;

logic [63:0]                            size                        ;
logic [7:0]                             num_pass                    ;
logic [63:0]                            ptr_0                       ;

// WK Note: need to specify pipeline for done & start signals
// Varaibles for merge tree 4 
logic                                                t4_wr_done_p1 ;
logic                                                t4_wr_start_p1; 
logic                                                t4_wr_done_p1_pipe;
logic                                                t4_wr_start_p1_pipe; 
fifo_if_t #(.DATA_WIDTH(LP_ROOT_DATA_WIDTH))         fifo_t_04();
fifo_if_t #(.DATA_WIDTH(LP_ROOT_DATA_WIDTH))         fifo_t_04_pipe();
// Varaibles for merge tree 12 
logic                                                t12_wr_done_p1 ;
logic                                                t12_wr_start_p1; 
logic                                                t12_wr_done_p1_pipe;
logic                                                t12_wr_start_p1_pipe; 
fifo_if_t #(.DATA_WIDTH(LP_ROOT_DATA_WIDTH))         fifo_t_12();
fifo_if_t #(.DATA_WIDTH(LP_ROOT_DATA_WIDTH))         fifo_t_12_pipe();



// Variables for AXI bus & register
axi_bus_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_00();

axi_bus_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_01();
axi_bus_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_pipe_01();

axi_bus_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_02();
axi_bus_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_pipe_02();

axi_bus_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_03();
axi_bus_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_pipe_03();

axi_bus_rd_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_rd_04();
axi_bus_wr_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_wr_04();
axi_bus_rd_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_rd_pipe_04();

axi_bus_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_05();
axi_bus_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_pipe_05();

axi_bus_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_06();
axi_bus_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_pipe_06();

axi_bus_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_07();
axi_bus_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_pipe_07();

axi_bus_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_08();

axi_bus_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_09();
axi_bus_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_pipe_09();

axi_bus_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_10();
axi_bus_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_pipe_10();

axi_bus_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_11();
axi_bus_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_pipe_11();

axi_bus_rd_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_rd_12();
axi_bus_wr_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_wr_12();
axi_bus_rd_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_rd_pipe_12();

axi_bus_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_13();
axi_bus_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_pipe_13();

axi_bus_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_14();
axi_bus_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_pipe_14();

axi_bus_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_15();
axi_bus_t #(.M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH), .M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH), .M_AXI_ID_WIDTH(C_M_AXI_ID_WIDTH)) axi_pipe_15();


///////////////////////////////////////////////////////////////////////////////////
//Main body of the code
///////////////////////////////////////////////////////////////////////////////////
`ifdef COCOTB_SIM
    glbl u_glbl();
`endif

always_ff @(posedge ap_clk) begin
    areset      <=  ~ap_rst_n   ;
    ap_start_r  <=  ap_start    ;
end

// ap_idle is asserted when done is asserted, it is de-asserted when ap_start_pulse 
// is asserted
always_ff @(posedge ap_clk) begin 
  if (areset) 
      ap_idle <=  1'b1;
  else
      ap_idle <=  ap_done        ?    1'b1 : 
                  ap_start_p1    ?    1'b0 : 
                                      ap_idle;
end

// Done logic
always_ff @(posedge ap_clk) begin
  if (areset)
    ap_done_p1_r <= '0;
  else
    ap_done_p1_r <= (ap_start_p1 | ap_done_p1) ? '0 : ap_done_p1_r | ap_done_p1_i;
end

always_ff @(posedge ap_clk) begin
  if (areset)
    ap_done_p2_r <= '0;
  else
    ap_done_p2_r <= (ap_start_p1 | ap_done_p2) ? '0 : ap_done_p2_r | ap_done_p2_i;
end

assign ap_start_p1 = ap_start & ~ap_start_r;
assign ap_ready = ap_done;
assign ap_done_p1 = &ap_done_p1_r;
assign ap_done_p2 = &ap_done_p2_r;
`ifdef TEST_PHASE_1
  assign ap_done = ap_done_p1;
`else
  assign ap_done = ap_done_p2;
`endif

always_ff @(posedge ap_clk) begin
    ap_start_p2 <= ap_done_p1;
end

delay_chain #(
  .WIDTH          ( 1                   ),
  .STAGES         ( 2                   )
)
u_ap_done_2 (
  .clk            ( ap_clk              ),
  .in_bus         ( ap_done_p2          ),
  .out_bus        ( ap_done_p2_pipe     )
);

// AXI Lite Register
(* keep_hierarchy = "yes" *) axil_register #
(
    .S_AXI_ADDR_WIDTH       ( C_S_AXI_CONTROL_ADDR_WIDTH    ),
    .PIPE_LEVEL             ( C_AXI_LITE_PIPE_NO + 1        ) 
)
u_axil_register(
    .clk                    ( ap_clk                        ),

    // axi4 lite slave signals
    .s_awaddr               ( s_axi_control_awaddr          ),
    .s_awvalid              ( s_axi_control_awvalid         ),
    .s_awready              ( s_axi_control_awready         ),

    .s_wdata                ( s_axi_control_wdata           ),
    .s_wstrb                ( s_axi_control_wstrb           ),
    .s_wvalid               ( s_axi_control_wvalid          ),
    .s_wready               ( s_axi_control_wready          ),

    .s_bresp                ( s_axi_control_bresp           ),
    .s_bvalid               ( s_axi_control_bvalid          ),
    .s_bready               ( s_axi_control_bready          ),

    .s_araddr               ( s_axi_control_araddr          ),
    .s_arvalid              ( s_axi_control_arvalid         ),
    .s_arready              ( s_axi_control_arready         ),

    .s_rdata                ( s_axi_control_rdata           ),
    .s_rresp                ( s_axi_control_rresp           ),
    .s_rvalid               ( s_axi_control_rvalid          ),
    .s_rready               ( s_axi_control_rready          ),

    // axi4 lite master signals
    .m_awaddr               ( m_axil_awaddr                 ),
    .m_awvalid              ( m_axil_awvalid                ),
    .m_awready              ( m_axil_awready                ),

    .m_wdata                ( m_axil_wdata                  ),
    .m_wstrb                ( m_axil_wstrb                  ),
    .m_wvalid               ( m_axil_wvalid                 ),
    .m_wready               ( m_axil_wready                 ),

    .m_bresp                ( m_axil_bresp                  ),
    .m_bvalid               ( m_axil_bvalid                 ),
    .m_bready               ( m_axil_bready                 ),

    .m_araddr               ( m_axil_araddr                 ),
    .m_arvalid              ( m_axil_arvalid                ),
    .m_arready              ( m_axil_arready                ),

    .m_rdata                ( m_axil_rdata                  ),
    .m_rresp                ( m_axil_rresp                  ),
    .m_rvalid               ( m_axil_rvalid                 ),
    .m_rready               ( m_axil_rready                 )
);

// AXI4-Lite slave interface
control_s_axil #
(
    .S_AXI_ADDR_WIDTH       ( C_S_AXI_CONTROL_ADDR_WIDTH    )
)
u_control(
    .i_clk                  ( ap_clk                        ),

    // axi4 lite slave signals
    .i_awaddr               ( m_axil_awaddr                 ),
    .i_awvalid              ( m_axil_awvalid                ),
    .o_awready              ( m_axil_awready                ),

    .i_wdata                ( m_axil_wdata                  ),
    .i_wstrb                ( m_axil_wstrb                  ),
    .i_wvalid               ( m_axil_wvalid                 ),
    .o_wready               ( m_axil_wready                 ),

    .o_bresp                ( m_axil_bresp                  ),
    .o_bvalid               ( m_axil_bvalid                 ),
    .i_bready               ( m_axil_bready                 ),

    .i_araddr               ( m_axil_araddr                 ),
    .i_arvalid              ( m_axil_arvalid                ),
    .o_arready              ( m_axil_arready                ),

    .o_rdata                ( m_axil_rdata                  ),
    .o_rresp                ( m_axil_rresp                  ),
    .o_rvalid               ( m_axil_rvalid                 ),
    .i_rready               ( m_axil_rready                 ),

    // user signals
    .o_interrupt            ( interrupt                     ),

    .o_ap_start             ( ap_start                      ),
    .i_ap_done              ( ap_done                       ),
    .i_ap_ready             ( ap_ready                      ),
    .i_ap_idle              ( ap_idle                       ),
    
    .o_size                 ( size                          ),
    .o_num_pass             ( num_pass                      ),
    .o_ptr_0                ( ptr_0                         )
);

// AXI converter
axi_conv #(
    .M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH            ),
    .M_AXI_DATA_WIDTH       ( C_M_AXI_DATA_WIDTH            ),
    .M_AXI_ID_WIDTH         ( C_M_AXI_ID_WIDTH              )
)
u_axi_conv_00(
    .s_axi                  ( axi_00                        ), 

    .m_axi_awvalid          ( m00_axi_awvalid               ),
    .m_axi_awready          ( m00_axi_awready               ),
    .m_axi_awaddr           ( m00_axi_awaddr                ),
    .m_axi_awburst          ( m00_axi_awburst               ),
    .m_axi_awlen            ( m00_axi_awlen                 ),
    .m_axi_awsize           ( m00_axi_awsize                ),
    .m_axi_awid             ( m00_axi_awid                  ),

    .m_axi_wvalid           ( m00_axi_wvalid                ),
    .m_axi_wready           ( m00_axi_wready                ),
    .m_axi_wdata            ( m00_axi_wdata                 ),
    .m_axi_wstrb            ( m00_axi_wstrb                 ),
    .m_axi_wlast            ( m00_axi_wlast                 ),

    .m_axi_bvalid           ( m00_axi_bvalid                ),
    .m_axi_bready           ( m00_axi_bready                ),
    .m_axi_bresp            ( m00_axi_bresp                 ),
    .m_axi_bid              ( m00_axi_bid                   ),

    .m_axi_arvalid          ( m00_axi_arvalid               ),
    .m_axi_arready          ( m00_axi_arready               ),
    .m_axi_araddr           ( m00_axi_araddr                ),
    .m_axi_arburst          ( m00_axi_arburst               ),
    .m_axi_arlen            ( m00_axi_arlen                 ),
    .m_axi_arsize           ( m00_axi_arsize                ),
    .m_axi_arid             ( m00_axi_arid                  ),

    .m_axi_rvalid           ( m00_axi_rvalid                ),
    .m_axi_rready           ( m00_axi_rready                ),
    .m_axi_rdata            ( m00_axi_rdata                 ),
    .m_axi_rlast            ( m00_axi_rlast                 ),
    .m_axi_rid              ( m00_axi_rid                   ),
    .m_axi_rresp            ( m00_axi_rresp                 )            
);

axi_conv #(
    .M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH            ),
    .M_AXI_DATA_WIDTH       ( C_M_AXI_DATA_WIDTH            ),
    .M_AXI_ID_WIDTH         ( C_M_AXI_ID_WIDTH              )
)
u_axi_conv_01(
    .s_axi                  ( axi_01                        ), 

    .m_axi_awvalid          ( m01_axi_awvalid               ),
    .m_axi_awready          ( m01_axi_awready               ),
    .m_axi_awaddr           ( m01_axi_awaddr                ),
    .m_axi_awburst          ( m01_axi_awburst               ),
    .m_axi_awlen            ( m01_axi_awlen                 ),
    .m_axi_awsize           ( m01_axi_awsize                ),
    .m_axi_awid             ( m01_axi_awid                  ),

    .m_axi_wvalid           ( m01_axi_wvalid                ),
    .m_axi_wready           ( m01_axi_wready                ),
    .m_axi_wdata            ( m01_axi_wdata                 ),
    .m_axi_wstrb            ( m01_axi_wstrb                 ),
    .m_axi_wlast            ( m01_axi_wlast                 ),

    .m_axi_bvalid           ( m01_axi_bvalid                ),
    .m_axi_bready           ( m01_axi_bready                ),
    .m_axi_bresp            ( m01_axi_bresp                 ),
    .m_axi_bid              ( m01_axi_bid                   ),

    .m_axi_arvalid          ( m01_axi_arvalid               ),
    .m_axi_arready          ( m01_axi_arready               ),
    .m_axi_araddr           ( m01_axi_araddr                ),
    .m_axi_arburst          ( m01_axi_arburst               ),
    .m_axi_arlen            ( m01_axi_arlen                 ),
    .m_axi_arsize           ( m01_axi_arsize                ),
    .m_axi_arid             ( m01_axi_arid                  ),

    .m_axi_rvalid           ( m01_axi_rvalid                ),
    .m_axi_rready           ( m01_axi_rready                ),
    .m_axi_rdata            ( m01_axi_rdata                 ),
    .m_axi_rlast            ( m01_axi_rlast                 ),
    .m_axi_rid              ( m01_axi_rid                   ),
    .m_axi_rresp            ( m01_axi_rresp                 )            
);

axi_conv #(
    .M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH            ),
    .M_AXI_DATA_WIDTH       ( C_M_AXI_DATA_WIDTH            ),
    .M_AXI_ID_WIDTH         ( C_M_AXI_ID_WIDTH              )
)
u_axi_conv_02(
    .s_axi                  ( axi_02                        ), 

    .m_axi_awvalid          ( m02_axi_awvalid               ),
    .m_axi_awready          ( m02_axi_awready               ),
    .m_axi_awaddr           ( m02_axi_awaddr                ),
    .m_axi_awburst          ( m02_axi_awburst               ),
    .m_axi_awlen            ( m02_axi_awlen                 ),
    .m_axi_awsize           ( m02_axi_awsize                ),
    .m_axi_awid             ( m02_axi_awid                  ),

    .m_axi_wvalid           ( m02_axi_wvalid                ),
    .m_axi_wready           ( m02_axi_wready                ),
    .m_axi_wdata            ( m02_axi_wdata                 ),
    .m_axi_wstrb            ( m02_axi_wstrb                 ),
    .m_axi_wlast            ( m02_axi_wlast                 ),

    .m_axi_bvalid           ( m02_axi_bvalid                ),
    .m_axi_bready           ( m02_axi_bready                ),
    .m_axi_bresp            ( m02_axi_bresp                 ),
    .m_axi_bid              ( m02_axi_bid                   ),

    .m_axi_arvalid          ( m02_axi_arvalid               ),
    .m_axi_arready          ( m02_axi_arready               ),
    .m_axi_araddr           ( m02_axi_araddr                ),
    .m_axi_arburst          ( m02_axi_arburst               ),
    .m_axi_arlen            ( m02_axi_arlen                 ),
    .m_axi_arsize           ( m02_axi_arsize                ),
    .m_axi_arid             ( m02_axi_arid                  ),

    .m_axi_rvalid           ( m02_axi_rvalid                ),
    .m_axi_rready           ( m02_axi_rready                ),
    .m_axi_rdata            ( m02_axi_rdata                 ),
    .m_axi_rlast            ( m02_axi_rlast                 ),
    .m_axi_rid              ( m02_axi_rid                   ),
    .m_axi_rresp            ( m02_axi_rresp                 )            
);

axi_conv #(
    .M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH            ),
    .M_AXI_DATA_WIDTH       ( C_M_AXI_DATA_WIDTH            ),
    .M_AXI_ID_WIDTH         ( C_M_AXI_ID_WIDTH              )
)
u_axi_conv_03(
    .s_axi                  ( axi_03                        ), 

    .m_axi_awvalid          ( m03_axi_awvalid               ),
    .m_axi_awready          ( m03_axi_awready               ),
    .m_axi_awaddr           ( m03_axi_awaddr                ),
    .m_axi_awburst          ( m03_axi_awburst               ),
    .m_axi_awlen            ( m03_axi_awlen                 ),
    .m_axi_awsize           ( m03_axi_awsize                ),
    .m_axi_awid             ( m03_axi_awid                  ),

    .m_axi_wvalid           ( m03_axi_wvalid                ),
    .m_axi_wready           ( m03_axi_wready                ),
    .m_axi_wdata            ( m03_axi_wdata                 ),
    .m_axi_wstrb            ( m03_axi_wstrb                 ),
    .m_axi_wlast            ( m03_axi_wlast                 ),

    .m_axi_bvalid           ( m03_axi_bvalid                ),
    .m_axi_bready           ( m03_axi_bready                ),
    .m_axi_bresp            ( m03_axi_bresp                 ),
    .m_axi_bid              ( m03_axi_bid                   ),

    .m_axi_arvalid          ( m03_axi_arvalid               ),
    .m_axi_arready          ( m03_axi_arready               ),
    .m_axi_araddr           ( m03_axi_araddr                ),
    .m_axi_arburst          ( m03_axi_arburst               ),
    .m_axi_arlen            ( m03_axi_arlen                 ),
    .m_axi_arsize           ( m03_axi_arsize                ),
    .m_axi_arid             ( m03_axi_arid                  ),

    .m_axi_rvalid           ( m03_axi_rvalid                ),
    .m_axi_rready           ( m03_axi_rready                ),
    .m_axi_rdata            ( m03_axi_rdata                 ),
    .m_axi_rlast            ( m03_axi_rlast                 ),
    .m_axi_rid              ( m03_axi_rid                   ),
    .m_axi_rresp            ( m03_axi_rresp                 )            
);

axi_conv_wr_rd #(
    .M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH            ),
    .M_AXI_DATA_WIDTH       ( C_M_AXI_DATA_WIDTH            ),
    .M_AXI_ID_WIDTH         ( C_M_AXI_ID_WIDTH              )
)
u_axi_conv_04(
    .s_axi_wr               ( axi_wr_04                     ), 
    .s_axi_rd               ( axi_rd_04                     ),

    .m_axi_awvalid          ( m04_axi_awvalid               ),
    .m_axi_awready          ( m04_axi_awready               ),
    .m_axi_awaddr           ( m04_axi_awaddr                ),
    .m_axi_awburst          ( m04_axi_awburst               ),
    .m_axi_awlen            ( m04_axi_awlen                 ),
    .m_axi_awsize           ( m04_axi_awsize                ),
    .m_axi_awid             ( m04_axi_awid                  ),

    .m_axi_wvalid           ( m04_axi_wvalid                ),
    .m_axi_wready           ( m04_axi_wready                ),
    .m_axi_wdata            ( m04_axi_wdata                 ),
    .m_axi_wstrb            ( m04_axi_wstrb                 ),
    .m_axi_wlast            ( m04_axi_wlast                 ),

    .m_axi_bvalid           ( m04_axi_bvalid                ),
    .m_axi_bready           ( m04_axi_bready                ),
    .m_axi_bresp            ( m04_axi_bresp                 ),
    .m_axi_bid              ( m04_axi_bid                   ),

    .m_axi_arvalid          ( m04_axi_arvalid               ),
    .m_axi_arready          ( m04_axi_arready               ),
    .m_axi_araddr           ( m04_axi_araddr                ),
    .m_axi_arburst          ( m04_axi_arburst               ),
    .m_axi_arlen            ( m04_axi_arlen                 ),
    .m_axi_arsize           ( m04_axi_arsize                ),
    .m_axi_arid             ( m04_axi_arid                  ),

    .m_axi_rvalid           ( m04_axi_rvalid                ),
    .m_axi_rready           ( m04_axi_rready                ),
    .m_axi_rdata            ( m04_axi_rdata                 ),
    .m_axi_rlast            ( m04_axi_rlast                 ),
    .m_axi_rid              ( m04_axi_rid                   ),
    .m_axi_rresp            ( m04_axi_rresp                 )            
);

axi_conv #(
    .M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH            ),
    .M_AXI_DATA_WIDTH       ( C_M_AXI_DATA_WIDTH            ),
    .M_AXI_ID_WIDTH         ( C_M_AXI_ID_WIDTH              )
)
u_axi_conv_05(
    .s_axi                  ( axi_05                        ), 

    .m_axi_awvalid          ( m05_axi_awvalid               ),
    .m_axi_awready          ( m05_axi_awready               ),
    .m_axi_awaddr           ( m05_axi_awaddr                ),
    .m_axi_awburst          ( m05_axi_awburst               ),
    .m_axi_awlen            ( m05_axi_awlen                 ),
    .m_axi_awsize           ( m05_axi_awsize                ),
    .m_axi_awid             ( m05_axi_awid                  ),

    .m_axi_wvalid           ( m05_axi_wvalid                ),
    .m_axi_wready           ( m05_axi_wready                ),
    .m_axi_wdata            ( m05_axi_wdata                 ),
    .m_axi_wstrb            ( m05_axi_wstrb                 ),
    .m_axi_wlast            ( m05_axi_wlast                 ),

    .m_axi_bvalid           ( m05_axi_bvalid                ),
    .m_axi_bready           ( m05_axi_bready                ),
    .m_axi_bresp            ( m05_axi_bresp                 ),
    .m_axi_bid              ( m05_axi_bid                   ),

    .m_axi_arvalid          ( m05_axi_arvalid               ),
    .m_axi_arready          ( m05_axi_arready               ),
    .m_axi_araddr           ( m05_axi_araddr                ),
    .m_axi_arburst          ( m05_axi_arburst               ),
    .m_axi_arlen            ( m05_axi_arlen                 ),
    .m_axi_arsize           ( m05_axi_arsize                ),
    .m_axi_arid             ( m05_axi_arid                  ),

    .m_axi_rvalid           ( m05_axi_rvalid                ),
    .m_axi_rready           ( m05_axi_rready                ),
    .m_axi_rdata            ( m05_axi_rdata                 ),
    .m_axi_rlast            ( m05_axi_rlast                 ),
    .m_axi_rid              ( m05_axi_rid                   ),
    .m_axi_rresp            ( m05_axi_rresp                 )            
);

axi_conv #(
    .M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH            ),
    .M_AXI_DATA_WIDTH       ( C_M_AXI_DATA_WIDTH            ),
    .M_AXI_ID_WIDTH         ( C_M_AXI_ID_WIDTH              )
)
u_axi_conv_06(
    .s_axi                  ( axi_06                        ), 

    .m_axi_awvalid          ( m06_axi_awvalid               ),
    .m_axi_awready          ( m06_axi_awready               ),
    .m_axi_awaddr           ( m06_axi_awaddr                ),
    .m_axi_awburst          ( m06_axi_awburst               ),
    .m_axi_awlen            ( m06_axi_awlen                 ),
    .m_axi_awsize           ( m06_axi_awsize                ),
    .m_axi_awid             ( m06_axi_awid                  ),

    .m_axi_wvalid           ( m06_axi_wvalid                ),
    .m_axi_wready           ( m06_axi_wready                ),
    .m_axi_wdata            ( m06_axi_wdata                 ),
    .m_axi_wstrb            ( m06_axi_wstrb                 ),
    .m_axi_wlast            ( m06_axi_wlast                 ),

    .m_axi_bvalid           ( m06_axi_bvalid                ),
    .m_axi_bready           ( m06_axi_bready                ),
    .m_axi_bresp            ( m06_axi_bresp                 ),
    .m_axi_bid              ( m06_axi_bid                   ),

    .m_axi_arvalid          ( m06_axi_arvalid               ),
    .m_axi_arready          ( m06_axi_arready               ),
    .m_axi_araddr           ( m06_axi_araddr                ),
    .m_axi_arburst          ( m06_axi_arburst               ),
    .m_axi_arlen            ( m06_axi_arlen                 ),
    .m_axi_arsize           ( m06_axi_arsize                ),
    .m_axi_arid             ( m06_axi_arid                  ),

    .m_axi_rvalid           ( m06_axi_rvalid                ),
    .m_axi_rready           ( m06_axi_rready                ),
    .m_axi_rdata            ( m06_axi_rdata                 ),
    .m_axi_rlast            ( m06_axi_rlast                 ),
    .m_axi_rid              ( m06_axi_rid                   ),
    .m_axi_rresp            ( m06_axi_rresp                 )            
);

axi_conv #(
    .M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH            ),
    .M_AXI_DATA_WIDTH       ( C_M_AXI_DATA_WIDTH            ),
    .M_AXI_ID_WIDTH         ( C_M_AXI_ID_WIDTH              )
)
u_axi_conv_07(
    .s_axi                  ( axi_07                        ), 

    .m_axi_awvalid          ( m07_axi_awvalid               ),
    .m_axi_awready          ( m07_axi_awready               ),
    .m_axi_awaddr           ( m07_axi_awaddr                ),
    .m_axi_awburst          ( m07_axi_awburst               ),
    .m_axi_awlen            ( m07_axi_awlen                 ),
    .m_axi_awsize           ( m07_axi_awsize                ),
    .m_axi_awid             ( m07_axi_awid                  ),

    .m_axi_wvalid           ( m07_axi_wvalid                ),
    .m_axi_wready           ( m07_axi_wready                ),
    .m_axi_wdata            ( m07_axi_wdata                 ),
    .m_axi_wstrb            ( m07_axi_wstrb                 ),
    .m_axi_wlast            ( m07_axi_wlast                 ),

    .m_axi_bvalid           ( m07_axi_bvalid                ),
    .m_axi_bready           ( m07_axi_bready                ),
    .m_axi_bresp            ( m07_axi_bresp                 ),
    .m_axi_bid              ( m07_axi_bid                   ),

    .m_axi_arvalid          ( m07_axi_arvalid               ),
    .m_axi_arready          ( m07_axi_arready               ),
    .m_axi_araddr           ( m07_axi_araddr                ),
    .m_axi_arburst          ( m07_axi_arburst               ),
    .m_axi_arlen            ( m07_axi_arlen                 ),
    .m_axi_arsize           ( m07_axi_arsize                ),
    .m_axi_arid             ( m07_axi_arid                  ),

    .m_axi_rvalid           ( m07_axi_rvalid                ),
    .m_axi_rready           ( m07_axi_rready                ),
    .m_axi_rdata            ( m07_axi_rdata                 ),
    .m_axi_rlast            ( m07_axi_rlast                 ),
    .m_axi_rid              ( m07_axi_rid                   ),
    .m_axi_rresp            ( m07_axi_rresp                 )            
);

axi_conv #(
    .M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH            ),
    .M_AXI_DATA_WIDTH       ( C_M_AXI_DATA_WIDTH            ),
    .M_AXI_ID_WIDTH         ( C_M_AXI_ID_WIDTH              )
)
u_axi_conv_08(
    .s_axi                  ( axi_08                        ), 

    .m_axi_awvalid          ( m08_axi_awvalid               ),
    .m_axi_awready          ( m08_axi_awready               ),
    .m_axi_awaddr           ( m08_axi_awaddr                ),
    .m_axi_awburst          ( m08_axi_awburst               ),
    .m_axi_awlen            ( m08_axi_awlen                 ),
    .m_axi_awsize           ( m08_axi_awsize                ),
    .m_axi_awid             ( m08_axi_awid                  ),

    .m_axi_wvalid           ( m08_axi_wvalid                ),
    .m_axi_wready           ( m08_axi_wready                ),
    .m_axi_wdata            ( m08_axi_wdata                 ),
    .m_axi_wstrb            ( m08_axi_wstrb                 ),
    .m_axi_wlast            ( m08_axi_wlast                 ),

    .m_axi_bvalid           ( m08_axi_bvalid                ),
    .m_axi_bready           ( m08_axi_bready                ),
    .m_axi_bresp            ( m08_axi_bresp                 ),
    .m_axi_bid              ( m08_axi_bid                   ),

    .m_axi_arvalid          ( m08_axi_arvalid               ),
    .m_axi_arready          ( m08_axi_arready               ),
    .m_axi_araddr           ( m08_axi_araddr                ),
    .m_axi_arburst          ( m08_axi_arburst               ),
    .m_axi_arlen            ( m08_axi_arlen                 ),
    .m_axi_arsize           ( m08_axi_arsize                ),
    .m_axi_arid             ( m08_axi_arid                  ),

    .m_axi_rvalid           ( m08_axi_rvalid                ),
    .m_axi_rready           ( m08_axi_rready                ),
    .m_axi_rdata            ( m08_axi_rdata                 ),
    .m_axi_rlast            ( m08_axi_rlast                 ),
    .m_axi_rid              ( m08_axi_rid                   ),
    .m_axi_rresp            ( m08_axi_rresp                 )            
);

axi_conv #(
    .M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH            ),
    .M_AXI_DATA_WIDTH       ( C_M_AXI_DATA_WIDTH            ),
    .M_AXI_ID_WIDTH         ( C_M_AXI_ID_WIDTH              )
)
u_axi_conv_09(
    .s_axi                  ( axi_09                        ), 

    .m_axi_awvalid          ( m09_axi_awvalid               ),
    .m_axi_awready          ( m09_axi_awready               ),
    .m_axi_awaddr           ( m09_axi_awaddr                ),
    .m_axi_awburst          ( m09_axi_awburst               ),
    .m_axi_awlen            ( m09_axi_awlen                 ),
    .m_axi_awsize           ( m09_axi_awsize                ),
    .m_axi_awid             ( m09_axi_awid                  ),

    .m_axi_wvalid           ( m09_axi_wvalid                ),
    .m_axi_wready           ( m09_axi_wready                ),
    .m_axi_wdata            ( m09_axi_wdata                 ),
    .m_axi_wstrb            ( m09_axi_wstrb                 ),
    .m_axi_wlast            ( m09_axi_wlast                 ),

    .m_axi_bvalid           ( m09_axi_bvalid                ),
    .m_axi_bready           ( m09_axi_bready                ),
    .m_axi_bresp            ( m09_axi_bresp                 ),
    .m_axi_bid              ( m09_axi_bid                   ),

    .m_axi_arvalid          ( m09_axi_arvalid               ),
    .m_axi_arready          ( m09_axi_arready               ),
    .m_axi_araddr           ( m09_axi_araddr                ),
    .m_axi_arburst          ( m09_axi_arburst               ),
    .m_axi_arlen            ( m09_axi_arlen                 ),
    .m_axi_arsize           ( m09_axi_arsize                ),
    .m_axi_arid             ( m09_axi_arid                  ),

    .m_axi_rvalid           ( m09_axi_rvalid                ),
    .m_axi_rready           ( m09_axi_rready                ),
    .m_axi_rdata            ( m09_axi_rdata                 ),
    .m_axi_rlast            ( m09_axi_rlast                 ),
    .m_axi_rid              ( m09_axi_rid                   ),
    .m_axi_rresp            ( m09_axi_rresp                 )            
);

axi_conv #(
    .M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH            ),
    .M_AXI_DATA_WIDTH       ( C_M_AXI_DATA_WIDTH            ),
    .M_AXI_ID_WIDTH         ( C_M_AXI_ID_WIDTH              )
)
u_axi_conv_10(
    .s_axi                  ( axi_10                        ), 

    .m_axi_awvalid          ( m10_axi_awvalid               ),
    .m_axi_awready          ( m10_axi_awready               ),
    .m_axi_awaddr           ( m10_axi_awaddr                ),
    .m_axi_awburst          ( m10_axi_awburst               ),
    .m_axi_awlen            ( m10_axi_awlen                 ),
    .m_axi_awsize           ( m10_axi_awsize                ),
    .m_axi_awid             ( m10_axi_awid                  ),

    .m_axi_wvalid           ( m10_axi_wvalid                ),
    .m_axi_wready           ( m10_axi_wready                ),
    .m_axi_wdata            ( m10_axi_wdata                 ),
    .m_axi_wstrb            ( m10_axi_wstrb                 ),
    .m_axi_wlast            ( m10_axi_wlast                 ),

    .m_axi_bvalid           ( m10_axi_bvalid                ),
    .m_axi_bready           ( m10_axi_bready                ),
    .m_axi_bresp            ( m10_axi_bresp                 ),
    .m_axi_bid              ( m10_axi_bid                   ),

    .m_axi_arvalid          ( m10_axi_arvalid               ),
    .m_axi_arready          ( m10_axi_arready               ),
    .m_axi_araddr           ( m10_axi_araddr                ),
    .m_axi_arburst          ( m10_axi_arburst               ),
    .m_axi_arlen            ( m10_axi_arlen                 ),
    .m_axi_arsize           ( m10_axi_arsize                ),
    .m_axi_arid             ( m10_axi_arid                  ),

    .m_axi_rvalid           ( m10_axi_rvalid                ),
    .m_axi_rready           ( m10_axi_rready                ),
    .m_axi_rdata            ( m10_axi_rdata                 ),
    .m_axi_rlast            ( m10_axi_rlast                 ),
    .m_axi_rid              ( m10_axi_rid                   ),
    .m_axi_rresp            ( m10_axi_rresp                 )            
);

axi_conv #(
    .M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH            ),
    .M_AXI_DATA_WIDTH       ( C_M_AXI_DATA_WIDTH            ),
    .M_AXI_ID_WIDTH         ( C_M_AXI_ID_WIDTH              )
)
u_axi_conv_11(
    .s_axi                  ( axi_11                        ), 

    .m_axi_awvalid          ( m11_axi_awvalid               ),
    .m_axi_awready          ( m11_axi_awready               ),
    .m_axi_awaddr           ( m11_axi_awaddr                ),
    .m_axi_awburst          ( m11_axi_awburst               ),
    .m_axi_awlen            ( m11_axi_awlen                 ),
    .m_axi_awsize           ( m11_axi_awsize                ),
    .m_axi_awid             ( m11_axi_awid                  ),

    .m_axi_wvalid           ( m11_axi_wvalid                ),
    .m_axi_wready           ( m11_axi_wready                ),
    .m_axi_wdata            ( m11_axi_wdata                 ),
    .m_axi_wstrb            ( m11_axi_wstrb                 ),
    .m_axi_wlast            ( m11_axi_wlast                 ),

    .m_axi_bvalid           ( m11_axi_bvalid                ),
    .m_axi_bready           ( m11_axi_bready                ),
    .m_axi_bresp            ( m11_axi_bresp                 ),
    .m_axi_bid              ( m11_axi_bid                   ),

    .m_axi_arvalid          ( m11_axi_arvalid               ),
    .m_axi_arready          ( m11_axi_arready               ),
    .m_axi_araddr           ( m11_axi_araddr                ),
    .m_axi_arburst          ( m11_axi_arburst               ),
    .m_axi_arlen            ( m11_axi_arlen                 ),
    .m_axi_arsize           ( m11_axi_arsize                ),
    .m_axi_arid             ( m11_axi_arid                  ),

    .m_axi_rvalid           ( m11_axi_rvalid                ),
    .m_axi_rready           ( m11_axi_rready                ),
    .m_axi_rdata            ( m11_axi_rdata                 ),
    .m_axi_rlast            ( m11_axi_rlast                 ),
    .m_axi_rid              ( m11_axi_rid                   ),
    .m_axi_rresp            ( m11_axi_rresp                 )            
);

axi_conv_wr_rd #(
    .M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH            ),
    .M_AXI_DATA_WIDTH       ( C_M_AXI_DATA_WIDTH            ),
    .M_AXI_ID_WIDTH         ( C_M_AXI_ID_WIDTH              )
)
u_axi_conv_12(
    .s_axi_wr               ( axi_wr_12                     ), 
    .s_axi_rd               ( axi_rd_12                     ), 

    .m_axi_awvalid          ( m12_axi_awvalid               ),
    .m_axi_awready          ( m12_axi_awready               ),
    .m_axi_awaddr           ( m12_axi_awaddr                ),
    .m_axi_awburst          ( m12_axi_awburst               ),
    .m_axi_awlen            ( m12_axi_awlen                 ),
    .m_axi_awsize           ( m12_axi_awsize                ),
    .m_axi_awid             ( m12_axi_awid                  ),

    .m_axi_wvalid           ( m12_axi_wvalid                ),
    .m_axi_wready           ( m12_axi_wready                ),
    .m_axi_wdata            ( m12_axi_wdata                 ),
    .m_axi_wstrb            ( m12_axi_wstrb                 ),
    .m_axi_wlast            ( m12_axi_wlast                 ),

    .m_axi_bvalid           ( m12_axi_bvalid                ),
    .m_axi_bready           ( m12_axi_bready                ),
    .m_axi_bresp            ( m12_axi_bresp                 ),
    .m_axi_bid              ( m12_axi_bid                   ),

    .m_axi_arvalid          ( m12_axi_arvalid               ),
    .m_axi_arready          ( m12_axi_arready               ),
    .m_axi_araddr           ( m12_axi_araddr                ),
    .m_axi_arburst          ( m12_axi_arburst               ),
    .m_axi_arlen            ( m12_axi_arlen                 ),
    .m_axi_arsize           ( m12_axi_arsize                ),
    .m_axi_arid             ( m12_axi_arid                  ),

    .m_axi_rvalid           ( m12_axi_rvalid                ),
    .m_axi_rready           ( m12_axi_rready                ),
    .m_axi_rdata            ( m12_axi_rdata                 ),
    .m_axi_rlast            ( m12_axi_rlast                 ),
    .m_axi_rid              ( m12_axi_rid                   ),
    .m_axi_rresp            ( m12_axi_rresp                 )            
);

axi_conv #(
    .M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH            ),
    .M_AXI_DATA_WIDTH       ( C_M_AXI_DATA_WIDTH            ),
    .M_AXI_ID_WIDTH         ( C_M_AXI_ID_WIDTH              )
)
u_axi_conv_13(
    .s_axi                  ( axi_13                        ), 

    .m_axi_awvalid          ( m13_axi_awvalid               ),
    .m_axi_awready          ( m13_axi_awready               ),
    .m_axi_awaddr           ( m13_axi_awaddr                ),
    .m_axi_awburst          ( m13_axi_awburst               ),
    .m_axi_awlen            ( m13_axi_awlen                 ),
    .m_axi_awsize           ( m13_axi_awsize                ),
    .m_axi_awid             ( m13_axi_awid                  ),

    .m_axi_wvalid           ( m13_axi_wvalid                ),
    .m_axi_wready           ( m13_axi_wready                ),
    .m_axi_wdata            ( m13_axi_wdata                 ),
    .m_axi_wstrb            ( m13_axi_wstrb                 ),
    .m_axi_wlast            ( m13_axi_wlast                 ),

    .m_axi_bvalid           ( m13_axi_bvalid                ),
    .m_axi_bready           ( m13_axi_bready                ),
    .m_axi_bresp            ( m13_axi_bresp                 ),
    .m_axi_bid              ( m13_axi_bid                   ),

    .m_axi_arvalid          ( m13_axi_arvalid               ),
    .m_axi_arready          ( m13_axi_arready               ),
    .m_axi_araddr           ( m13_axi_araddr                ),
    .m_axi_arburst          ( m13_axi_arburst               ),
    .m_axi_arlen            ( m13_axi_arlen                 ),
    .m_axi_arsize           ( m13_axi_arsize                ),
    .m_axi_arid             ( m13_axi_arid                  ),

    .m_axi_rvalid           ( m13_axi_rvalid                ),
    .m_axi_rready           ( m13_axi_rready                ),
    .m_axi_rdata            ( m13_axi_rdata                 ),
    .m_axi_rlast            ( m13_axi_rlast                 ),
    .m_axi_rid              ( m13_axi_rid                   ),
    .m_axi_rresp            ( m13_axi_rresp                 )            
);

axi_conv #(
    .M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH            ),
    .M_AXI_DATA_WIDTH       ( C_M_AXI_DATA_WIDTH            ),
    .M_AXI_ID_WIDTH         ( C_M_AXI_ID_WIDTH              )
)
u_axi_conv_14(
    .s_axi                  ( axi_14                        ), 

    .m_axi_awvalid          ( m14_axi_awvalid               ),
    .m_axi_awready          ( m14_axi_awready               ),
    .m_axi_awaddr           ( m14_axi_awaddr                ),
    .m_axi_awburst          ( m14_axi_awburst               ),
    .m_axi_awlen            ( m14_axi_awlen                 ),
    .m_axi_awsize           ( m14_axi_awsize                ),
    .m_axi_awid             ( m14_axi_awid                  ),

    .m_axi_wvalid           ( m14_axi_wvalid                ),
    .m_axi_wready           ( m14_axi_wready                ),
    .m_axi_wdata            ( m14_axi_wdata                 ),
    .m_axi_wstrb            ( m14_axi_wstrb                 ),
    .m_axi_wlast            ( m14_axi_wlast                 ),

    .m_axi_bvalid           ( m14_axi_bvalid                ),
    .m_axi_bready           ( m14_axi_bready                ),
    .m_axi_bresp            ( m14_axi_bresp                 ),
    .m_axi_bid              ( m14_axi_bid                   ),

    .m_axi_arvalid          ( m14_axi_arvalid               ),
    .m_axi_arready          ( m14_axi_arready               ),
    .m_axi_araddr           ( m14_axi_araddr                ),
    .m_axi_arburst          ( m14_axi_arburst               ),
    .m_axi_arlen            ( m14_axi_arlen                 ),
    .m_axi_arsize           ( m14_axi_arsize                ),
    .m_axi_arid             ( m14_axi_arid                  ),

    .m_axi_rvalid           ( m14_axi_rvalid                ),
    .m_axi_rready           ( m14_axi_rready                ),
    .m_axi_rdata            ( m14_axi_rdata                 ),
    .m_axi_rlast            ( m14_axi_rlast                 ),
    .m_axi_rid              ( m14_axi_rid                   ),
    .m_axi_rresp            ( m14_axi_rresp                 )            
);

axi_conv #(
    .M_AXI_ADDR_WIDTH       ( C_M_AXI_ADDR_WIDTH            ),
    .M_AXI_DATA_WIDTH       ( C_M_AXI_DATA_WIDTH            ),
    .M_AXI_ID_WIDTH         ( C_M_AXI_ID_WIDTH              )
)
u_axi_conv_15(
    .s_axi                  ( axi_15                        ), 

    .m_axi_awvalid          ( m15_axi_awvalid               ),
    .m_axi_awready          ( m15_axi_awready               ),
    .m_axi_awaddr           ( m15_axi_awaddr                ),
    .m_axi_awburst          ( m15_axi_awburst               ),
    .m_axi_awlen            ( m15_axi_awlen                 ),
    .m_axi_awsize           ( m15_axi_awsize                ),
    .m_axi_awid             ( m15_axi_awid                  ),

    .m_axi_wvalid           ( m15_axi_wvalid                ),
    .m_axi_wready           ( m15_axi_wready                ),
    .m_axi_wdata            ( m15_axi_wdata                 ),
    .m_axi_wstrb            ( m15_axi_wstrb                 ),
    .m_axi_wlast            ( m15_axi_wlast                 ),

    .m_axi_bvalid           ( m15_axi_bvalid                ),
    .m_axi_bready           ( m15_axi_bready                ),
    .m_axi_bresp            ( m15_axi_bresp                 ),
    .m_axi_bid              ( m15_axi_bid                   ),

    .m_axi_arvalid          ( m15_axi_arvalid               ),
    .m_axi_arready          ( m15_axi_arready               ),
    .m_axi_araddr           ( m15_axi_araddr                ),
    .m_axi_arburst          ( m15_axi_arburst               ),
    .m_axi_arlen            ( m15_axi_arlen                 ),
    .m_axi_arsize           ( m15_axi_arsize                ),
    .m_axi_arid             ( m15_axi_arid                  ),

    .m_axi_rvalid           ( m15_axi_rvalid                ),
    .m_axi_rready           ( m15_axi_rready                ),
    .m_axi_rdata            ( m15_axi_rdata                 ),
    .m_axi_rlast            ( m15_axi_rlast                 ),
    .m_axi_rid              ( m15_axi_rid                   ),
    .m_axi_rresp            ( m15_axi_rresp                 )            
);

// AXI register instances
// m01-m03: 2 stages pipeline
(* keep_hierarchy = "yes" *) axi_register #(.PIPE_LEVEL(3))  u_axi_pipe_01(.clk(ap_clk), .s_axi(axi_pipe_01), .m_axi(axi_01));
(* keep_hierarchy = "yes" *) axi_register #(.PIPE_LEVEL(3))  u_axi_pipe_02(.clk(ap_clk), .s_axi(axi_pipe_02), .m_axi(axi_02));
(* keep_hierarchy = "yes" *) axi_register #(.PIPE_LEVEL(3))  u_axi_pipe_03(.clk(ap_clk), .s_axi(axi_pipe_03), .m_axi(axi_03));
// m04-m07: 4 stages pipeline
(* keep_hierarchy = "yes" *) axi_rd_register #(.PIPE_LEVEL(5))  u_axi_rd_pipe_04(.clk(ap_clk), .s_axi(axi_rd_pipe_04), .m_axi(axi_rd_04));
(* keep_hierarchy = "yes" *) fifo_register #(.PIPE_LEVEL(5))  u_fifo_pipe_04(.clk(ap_clk), .s_fifo(fifo_t_04_pipe), .m_fifo(fifo_t_04));
(* keep_hierarchy = "yes" *) axi_register #(.PIPE_LEVEL(5))  u_axi_pipe_05(.clk(ap_clk), .s_axi(axi_pipe_05), .m_axi(axi_05));
(* keep_hierarchy = "yes" *) axi_register #(.PIPE_LEVEL(5))  u_axi_pipe_06(.clk(ap_clk), .s_axi(axi_pipe_06), .m_axi(axi_06));
(* keep_hierarchy = "yes" *) axi_register #(.PIPE_LEVEL(5))  u_axi_pipe_07(.clk(ap_clk), .s_axi(axi_pipe_07), .m_axi(axi_07));
// m09-11: 2 stage pipeline
(* keep_hierarchy = "yes" *) axi_register #(.PIPE_LEVEL(3))  u_axi_pipe_09(.clk(ap_clk), .s_axi(axi_pipe_09), .m_axi(axi_09));
(* keep_hierarchy = "yes" *) axi_register #(.PIPE_LEVEL(3))  u_axi_pipe_10(.clk(ap_clk), .s_axi(axi_pipe_10), .m_axi(axi_10));
(* keep_hierarchy = "yes" *) axi_register #(.PIPE_LEVEL(3))  u_axi_pipe_11(.clk(ap_clk), .s_axi(axi_pipe_11), .m_axi(axi_11));
// m12-15: 4 stages pipeline
(* keep_hierarchy = "yes" *) axi_rd_register #(.PIPE_LEVEL(5))  u_axi_rd_pipe_12(.clk(ap_clk), .s_axi(axi_rd_pipe_12), .m_axi(axi_rd_12));
(* keep_hierarchy = "yes" *) fifo_register #(.PIPE_LEVEL(5))  u_fifo_pipe_12(.clk(ap_clk), .s_fifo(fifo_t_12_pipe), .m_fifo(fifo_t_12));
(* keep_hierarchy = "yes" *) axi_register #(.PIPE_LEVEL(5))  u_axi_pipe_13(.clk(ap_clk), .s_axi(axi_pipe_13), .m_axi(axi_13));
(* keep_hierarchy = "yes" *) axi_register #(.PIPE_LEVEL(5))  u_axi_pipe_14(.clk(ap_clk), .s_axi(axi_pipe_14), .m_axi(axi_14));
(* keep_hierarchy = "yes" *) axi_register #(.PIPE_LEVEL(5))  u_axi_pipe_15(.clk(ap_clk), .s_axi(axi_pipe_15), .m_axi(axi_15));


// instances of merge tree top 
(* keep_hierarchy = "yes" *) merge_tree_top #(
  .SCALA_PIPE               ( 2                             ),
  .CHANNEL_OFFSET           ( 2                             ),
  .C_NUM_BRAM_NODES         ( 4                             )
)
u_merge_tree_top_1 (
  .aclk                     ( ap_clk                        ),

  .ap_start                 ( ap_start_p1                   ),
  .ap_done                  ( ap_done_p1_i[1]               ),

  .i_num_pass               ( num_pass                      ),
  .i_ptr_0                  ( ptr_0                         ),
  .i_xfer_size_in_bytes     ( size[0+:C_XFER_SIZE_WIDTH]    ),

  .m_axi                    ( axi_pipe_01                   )
);

(* keep_hierarchy = "yes" *) merge_tree_top #(
  .SCALA_PIPE               ( 2                             ),
  .CHANNEL_OFFSET           ( 4                             ),
  .C_NUM_BRAM_NODES         ( 4                             )
)
u_merge_tree_top_2 (
  .aclk                     ( ap_clk                        ),

  .ap_start                 ( ap_start_p1                   ),
  .ap_done                  ( ap_done_p1_i[2]               ),

  .i_num_pass               ( num_pass                      ),
  .i_ptr_0                  ( ptr_0                         ),
  .i_xfer_size_in_bytes     ( size[0+:C_XFER_SIZE_WIDTH]    ),

  .m_axi                    ( axi_pipe_02                   )
);

(* keep_hierarchy = "yes" *) merge_tree_top #(
  .SCALA_PIPE               ( 2                             ),
  .CHANNEL_OFFSET           ( 6                             ),
  .C_NUM_BRAM_NODES         ( 4                             )
)
u_merge_tree_top_3 (
  .aclk                     ( ap_clk                        ),

  .ap_start                 ( ap_start_p1                   ),
  .ap_done                  ( ap_done_p1_i[3]               ),

  .i_num_pass               ( num_pass                      ),
  .i_ptr_0                  ( ptr_0                         ),
  .i_xfer_size_in_bytes     ( size[0+:C_XFER_SIZE_WIDTH]    ),

  .m_axi                    ( axi_pipe_03                   )
);

(* keep_hierarchy = "yes" *) merge_tree_top #(
  .SCALA_PIPE               ( 3                             ),
  .CHANNEL_OFFSET           ( 10                            ),
  .C_NUM_BRAM_NODES         ( 4                             )
)
u_merge_tree_top_5 (
  .aclk                     ( ap_clk                        ),

  .ap_start                 ( ap_start_p1                   ),
  .ap_done                  ( ap_done_p1_i[5]               ),

  .i_num_pass               ( num_pass                      ),
  .i_ptr_0                  ( ptr_0                         ),
  .i_xfer_size_in_bytes     ( size[0+:C_XFER_SIZE_WIDTH]    ),

  .m_axi                    ( axi_pipe_05                   )
);

(* keep_hierarchy = "yes" *) merge_tree_top #(
  .SCALA_PIPE               ( 3                             ),
  .CHANNEL_OFFSET           ( 12                            ),
  .C_NUM_BRAM_NODES         ( 4                             )
)
u_merge_tree_top_6 (
  .aclk                     ( ap_clk                        ),

  .ap_start                 ( ap_start_p1                   ),
  .ap_done                  ( ap_done_p1_i[6]               ),

  .i_num_pass               ( num_pass                      ),
  .i_ptr_0                  ( ptr_0                         ),
  .i_xfer_size_in_bytes     ( size[0+:C_XFER_SIZE_WIDTH]    ),

  .m_axi                    ( axi_pipe_06                   )
);

(* keep_hierarchy = "yes" *) merge_tree_top #(
  .SCALA_PIPE               ( 3                             ),
  .CHANNEL_OFFSET           ( 14                            ),
  .C_NUM_BRAM_NODES         ( 4                             )
)
u_merge_tree_top_7 (
  .aclk                     ( ap_clk                        ),

  .ap_start                 ( ap_start_p1                   ),
  .ap_done                  ( ap_done_p1_i[7]               ),

  .i_num_pass               ( num_pass                      ),
  .i_ptr_0                  ( ptr_0                         ),
  .i_xfer_size_in_bytes     ( size[0+:C_XFER_SIZE_WIDTH]    ),

  .m_axi                    ( axi_pipe_07                   )
);


(* keep_hierarchy = "yes" *) merge_tree_top #(
  .SCALA_PIPE               ( 2                             ),
  .CHANNEL_OFFSET           ( 18                            ),
  .C_NUM_BRAM_NODES         ( 4                             )
)
u_merge_tree_top_9 (
  .aclk                     ( ap_clk                        ),

  .ap_start                 ( ap_start_p1                   ),
  .ap_done                  ( ap_done_p1_i[9]               ),

  .i_num_pass               ( num_pass                      ),
  .i_ptr_0                  ( ptr_0                         ),
  .i_xfer_size_in_bytes     ( size[0+:C_XFER_SIZE_WIDTH]    ),

  .m_axi                    ( axi_pipe_09                   )
);

(* keep_hierarchy = "yes" *) merge_tree_top #(
  .SCALA_PIPE               ( 2                             ),
  .CHANNEL_OFFSET           ( 20                            ),
  .C_NUM_BRAM_NODES         ( 4                             )
)
u_merge_tree_top_10 (
  .aclk                     ( ap_clk                        ),

  .ap_start                 ( ap_start_p1                   ),
  .ap_done                  ( ap_done_p1_i[10]              ),

  .i_num_pass               ( num_pass                      ),
  .i_ptr_0                  ( ptr_0                         ),
  .i_xfer_size_in_bytes     ( size[0+:C_XFER_SIZE_WIDTH]    ),

  .m_axi                    ( axi_pipe_10                   )
);

(* keep_hierarchy = "yes" *) merge_tree_top #(
  .SCALA_PIPE               ( 2                             ),
  .CHANNEL_OFFSET           ( 22                            ),
  .C_NUM_BRAM_NODES         ( 4                             )
)
u_merge_tree_top_11 (
  .aclk                     ( ap_clk                        ),

  .ap_start                 ( ap_start_p1                   ),
  .ap_done                  ( ap_done_p1_i[11]              ),

  .i_num_pass               ( num_pass                      ),
  .i_ptr_0                  ( ptr_0                         ),
  .i_xfer_size_in_bytes     ( size[0+:C_XFER_SIZE_WIDTH]    ),

  .m_axi                    ( axi_pipe_11                   )
);

(* keep_hierarchy = "yes" *) merge_tree_top #(
  .SCALA_PIPE               ( 3                             ),
  .CHANNEL_OFFSET           ( 26                            ),
  .C_NUM_BRAM_NODES         ( 4                             )
)
u_merge_tree_top_13 (
  .aclk                     ( ap_clk                        ),

  .ap_start                 ( ap_start_p1                   ),
  .ap_done                  ( ap_done_p1_i[13]              ),

  .i_num_pass               ( num_pass                      ),
  .i_ptr_0                  ( ptr_0                         ),
  .i_xfer_size_in_bytes     ( size[0+:C_XFER_SIZE_WIDTH]    ),

  .m_axi                    ( axi_pipe_13                   )
);

(* keep_hierarchy = "yes" *) merge_tree_top #(
  .SCALA_PIPE               ( 3                             ),
  .CHANNEL_OFFSET           ( 28                            ),
  .C_NUM_BRAM_NODES         ( 4                             )
)
u_merge_tree_top_14 (
  .aclk                     ( ap_clk                        ),

  .ap_start                 ( ap_start_p1                   ),
  .ap_done                  ( ap_done_p1_i[14]              ),

  .i_num_pass               ( num_pass                      ),
  .i_ptr_0                  ( ptr_0                         ),
  .i_xfer_size_in_bytes     ( size[0+:C_XFER_SIZE_WIDTH]    ),

  .m_axi                    ( axi_pipe_14                   )
);

(* keep_hierarchy = "yes" *) merge_tree_top #(
  .SCALA_PIPE               ( 3                             ),
  .CHANNEL_OFFSET           ( 30                            ),
  .C_NUM_BRAM_NODES         ( 4                             )
)
u_merge_tree_top_15 (
  .aclk                     ( ap_clk                        ),

  .ap_start                 ( ap_start_p1                   ),
  .ap_done                  ( ap_done_p1_i[15]              ),

  .i_num_pass               ( num_pass                      ),
  .i_ptr_0                  ( ptr_0                         ),
  .i_xfer_size_in_bytes     ( size[0+:C_XFER_SIZE_WIDTH]    ),

  .m_axi                    ( axi_pipe_15                   )
);


// merge tree 4 & 12 that are reused in both phases
(* keep_hierarchy = "yes" *) merge_tree_reuse_type2_top #(
  .SCALA_PIPE               ( 3                             ),
  .CHANNEL_OFFSET           ( 8                             ),
  .C_NUM_BRAM_NODES         ( 8                             )
)
u_merge_tree_top_4 (
  .aclk                     ( ap_clk                        ),

`ifdef TEST_PHASE_2
  .i_start_p1               ( 1'b0                          ), // test phase 2
`else
  .i_start_p1               ( ap_start_p1                   ),
`endif
  
  .o_done_p1                ( ap_done_p1_i[4]               ),

`ifdef TEST_PHASE_2
  .i_start_p2               ( ap_start_p1                   ), // test phase 2
`else
`ifdef TEST_PHASE_1
  .i_start_p2               ( 1'b0                          ), // test phase 1
`else
  .i_start_p2               ( ap_start_p2                   ),
`endif
`endif
  
  .i_write_done_p1          ( t4_wr_done_p1_pipe            ),
  .o_write_start_p1         ( t4_wr_start_p1                ),

  .i_num_pass               ( num_pass                      ),
  .i_ptr_0                  ( ptr_0                         ),
  .i_xfer_size_in_bytes     ( size[0+:C_XFER_SIZE_WIDTH]    ),

  .m_axi                    ( axi_rd_pipe_04                ),
  .i_root_read              ( fifo_t_04_pipe.read           ),
  .o_root_data              ( fifo_t_04_pipe.data           ),
  .o_root_data_vld          ( fifo_t_04_pipe.data_vld       )
);

(* keep_hierarchy = "yes" *) merge_tree_reuse_type2_top #(
  .SCALA_PIPE               ( 3                             ),
  .CHANNEL_OFFSET           ( 24                            ),
  .C_NUM_BRAM_NODES         ( 8                             )
)
u_merge_tree_top_12 (
  .aclk                     ( ap_clk                        ),

`ifdef TEST_PHASE_2
  .i_start_p1               ( 1'b0                          ), // test phase 2
`else
  .i_start_p1               ( ap_start_p1                   ),
`endif

  .o_done_p1                ( ap_done_p1_i[12]              ),

`ifdef TEST_PHASE_2
  .i_start_p2               ( ap_start_p1                   ), // test phase 2
`else
`ifdef TEST_PHASE_1
  .i_start_p2               ( 1'b0                          ), // test phase 1
`else
  .i_start_p2               ( ap_start_p2                   ),
`endif
`endif
  
  .i_write_done_p1          ( t12_wr_done_p1_pipe           ),
  .o_write_start_p1         ( t12_wr_start_p1               ),

  .i_num_pass               ( num_pass                      ),
  .i_ptr_0                  ( ptr_0                         ),
  .i_xfer_size_in_bytes     ( size[0+:C_XFER_SIZE_WIDTH]    ),

  .m_axi                    ( axi_rd_pipe_12                ),
  .i_root_read              ( fifo_t_12_pipe.read           ),
  .o_root_data              ( fifo_t_12_pipe.data           ),
  .o_root_data_vld          ( fifo_t_12_pipe.data_vld       )
);

delay_chain #(
  .WIDTH          ( 1                   ),
  .STAGES         ( 4                   )
)
u_wr_start_p1_4 (
  .clk            ( ap_clk              ),
  .in_bus         ( t4_wr_start_p1      ),
  .out_bus        ( t4_wr_start_p1_pipe )
);

delay_chain #(
  .WIDTH          ( 1                   ),
  .STAGES         ( 4                   )
)
u_wr_done_p1_4 (
  .clk            ( ap_clk              ),
  .in_bus         ( t4_wr_done_p1       ),
  .out_bus        ( t4_wr_done_p1_pipe  )
);

delay_chain #(
  .WIDTH          ( 1                   ),
  .STAGES         ( 4                   )
)
u_wr_start_p1_12 (
  .clk            ( ap_clk              ),
  .in_bus         ( t12_wr_start_p1     ),
  .out_bus        ( t12_wr_start_p1_pipe)
);

delay_chain #(
  .WIDTH          ( 1                   ),
  .STAGES         ( 4                   )
)
u_wr_done_p1_12 (
  .clk            ( ap_clk              ),
  .in_bus         ( t12_wr_done_p1      ),
  .out_bus        ( t12_wr_done_p1_pipe )
);

// merge tree reuse top
(* keep_hierarchy = "yes" *) merge_tree_phase2_top #(
  .SCALA_PIPE               ( 2                             ),
  .C_NUM_BRAM_NODES         ( 8                             )
)
u_merge_tree_phase2_top (
  .aclk                     ( ap_clk                        ),

`ifdef TEST_PHASE_2
  .i_start_p1               ( 1'b0                          ), // test phase 2
`else
  .i_start_p1               ( ap_start_p1                   ),
`endif

  .o_done_p1                ( {ap_done_p1_i[8], ap_done_p1_i[0]} ),

`ifdef TEST_PHASE_2
  .i_start_p2               ( ap_start_p1                   ), // test phase 2
`else
`ifdef TEST_PHASE_1
  .i_start_p2               ( 1'b0                          ), // test phase 1
`else
  .i_start_p2               ( ap_start_p2                   ),
`endif
`endif

  .i_done_p2                ( ap_done_p2_pipe               ),
  .o_done_p2                ( ap_done_p2_i                  ),

  .i_num_pass               ( num_pass                      ),
  .i_ptr_0                  ( ptr_0                         ),
  .i_xfer_size_in_bytes     ( size[0+:C_XFER_SIZE_WIDTH]    ),

  .i_wr_start_p1_t04        ( t4_wr_start_p1_pipe           ),
  .o_wr_done_p1_t04         ( t4_wr_done_p1                 ),
  .fifo_it_t04              ( fifo_t_04                     ),
  .i_wr_start_p1_t12        ( t12_wr_start_p1_pipe          ),
  .o_wr_done_p1_t12         ( t12_wr_done_p1                ),
  .fifo_it_t12              ( fifo_t_12                     ),

  .m00_axi                  ( axi_00                        ),
  .m04_axi_wr               ( axi_wr_04                     ),
  .m08_axi                  ( axi_08                        ),
  .m12_axi_wr               ( axi_wr_12                     )
);


//The macro to dump signals
`ifdef COCOTB_SIM
initial begin
    $vcdplusfile("merge_sort_complete.vpd");
    $vcdpluson(0, merge_sort_complete);
    #1;
end
`endif

endmodule
