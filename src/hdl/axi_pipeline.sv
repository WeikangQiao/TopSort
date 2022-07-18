module axi_pipeline #(
  parameter
    C_M_AXI_ID_WIDTH        = 1,
    C_M_AXI_ADDR_WIDTH      = 32,
    C_M_AXI_DATA_WIDTH      = 512,
    C_M_AXI_WSTRB_WIDTH     = (512 / 8),

    PIPELINE_LEVEL          = 3
) 
(
  input logic                                         ap_clk,

  // pipeline in
  input  logic                                        in_AWVALID,
  output logic                                        in_AWREADY,
  input  logic [C_M_AXI_ADDR_WIDTH - 1:0]             in_AWADDR,
  input  logic [1:0]                                  in_AWBURST,
  input  logic [7:0]                                  in_AWLEN,
  input  logic [2:0]                                  in_AWSIZE,
  input  logic [C_M_AXI_ID_WIDTH - 1:0]               in_AWID,

  input  logic                                        in_WVALID,
  output logic                                        in_WREADY,
  input  logic [C_M_AXI_DATA_WIDTH - 1:0]             in_WDATA,
  input  logic [C_M_AXI_WSTRB_WIDTH - 1:0]            in_WSTRB,
  input  logic                                        in_WLAST,

  output logic                                        in_BVALID,
  input  logic                                        in_BREADY,
  output logic  [1:0]                                 in_BRESP,
  output logic  [C_M_AXI_ID_WIDTH - 1:0]              in_BID,

  input  logic                                        in_ARVALID,
  output logic                                        in_ARREADY,
  input  logic [C_M_AXI_ADDR_WIDTH - 1:0]             in_ARADDR,
  input  logic [1:0]                                  in_ARBURST,
  input  logic [7:0]                                  in_ARLEN,
  input  logic [2:0]                                  in_ARSIZE,
  input  logic [C_M_AXI_ID_WIDTH - 1:0]               in_ARID,
  
  output logic                                        in_RVALID,
  input  logic                                        in_RREADY,
  output logic  [C_M_AXI_DATA_WIDTH - 1:0]            in_RDATA,
  output logic                                        in_RLAST,
  output logic  [C_M_AXI_ID_WIDTH - 1:0]              in_RID,
  output logic  [1:0]                                 in_RRESP,

  // pipeline out
  output logic                                        out_AWVALID,
  input  logic                                        out_AWREADY,
  output logic  [C_M_AXI_ADDR_WIDTH - 1:0]            out_AWADDR,
  output logic  [1:0]                                 out_AWBURST,
  output logic  [7:0]                                 out_AWLEN,
  output logic  [2:0]                                 out_AWSIZE,
  output logic  [C_M_AXI_ID_WIDTH - 1:0]              out_AWID,

  output logic                                        out_WVALID,
  input  logic                                        out_WREADY,
  output logic  [C_M_AXI_DATA_WIDTH - 1:0]            out_WDATA,
  output logic  [C_M_AXI_WSTRB_WIDTH - 1:0]           out_WSTRB,
  output logic                                        out_WLAST,

  input  logic                                        out_BVALID,
  output logic                                        out_BREADY,
  input  logic [1:0]                                  out_BRESP,
  input  logic [C_M_AXI_ID_WIDTH - 1:0]               out_BID,

  output logic                                        out_ARVALID,
  input  logic                                        out_ARREADY,
  output logic  [C_M_AXI_ADDR_WIDTH - 1:0]            out_ARADDR,
  output logic  [1:0]                                 out_ARBURST,
  output logic  [7:0]                                 out_ARLEN,
  output logic  [2:0]                                 out_ARSIZE,
  output logic  [C_M_AXI_ID_WIDTH - 1:0]              out_ARID,

  input  logic                                        out_RVALID,
  output logic                                        out_RREADY,
  input  logic [C_M_AXI_DATA_WIDTH - 1:0]             out_RDATA,
  input  logic                                        out_RLAST,
  input  logic [C_M_AXI_ID_WIDTH - 1:0]               out_RID,
  input  logic [1:0]                                  out_RRESP
);

  relay_station
  #(
    .DATA_WIDTH     ( C_M_AXI_ADDR_WIDTH + C_M_AXI_ID_WIDTH + 8 + 3 + 2           ),
    .DEPTH          ( 2                                                           ),
    .ADDR_WIDTH     ( 1                                                           ),
    .LEVEL          ( PIPELINE_LEVEL                                              )
  )
  AW_pipeline
  (
    .clk            ( ap_clk                                                      ),
    .if_read_ce     ( 1'b1                                                        ),
    .if_write_ce    ( 1'b1                                                        ),

    .if_din         ( {in_AWADDR,  in_AWID,  in_AWLEN,  in_AWSIZE,  in_AWBURST}   ),
    .if_full_n      ( in_AWREADY                                                  ),
    .if_write       ( in_AWVALID                                                  ),

    .if_dout        ( {out_AWADDR, out_AWID, out_AWLEN, out_AWSIZE, out_AWBURST}  ),
    .if_empty_n     ( out_AWVALID                                                 ),
    .if_read        ( out_AWREADY                                                 )
  );

  relay_station
  #(
    .DATA_WIDTH(
      C_M_AXI_DATA_WIDTH + C_M_AXI_WSTRB_WIDTH + 1
    ),
    .DEPTH(2),
    .ADDR_WIDTH(1),
    .LEVEL(PIPELINE_LEVEL)
  )
  W_pipeline
  (
    .clk        (ap_clk),
    .if_read_ce (1'b1),
    .if_write_ce(1'b1),

    .if_din     ({in_WDATA,  in_WSTRB,  in_WLAST}),
    .if_full_n  ( in_WREADY),
    .if_write   ( in_WVALID),

    .if_dout    ({out_WDATA, out_WSTRB, out_WLAST}),
    .if_empty_n (out_WVALID),
    .if_read    (out_WREADY)
  );

  relay_station
  #(
    .DATA_WIDTH(
      C_M_AXI_ADDR_WIDTH + C_M_AXI_ID_WIDTH + 8 + 3 + 2
    ),
    .DEPTH(2),
    .ADDR_WIDTH(1),
    .LEVEL(PIPELINE_LEVEL)
  )
  AR_pipeline
  (
    .clk        (ap_clk),
    .if_read_ce (1'b1),
    .if_write_ce(1'b1),

    .if_din     ({ in_ARADDR,  in_ARID,  in_ARLEN,  in_ARSIZE,  in_ARBURST}),
    .if_full_n  ( in_ARREADY),
    .if_write   ( in_ARVALID),

    .if_dout    ({out_ARADDR, out_ARID, out_ARLEN, out_ARSIZE, out_ARBURST}),
    .if_empty_n (out_ARVALID),
    .if_read    (out_ARREADY)
  );

  relay_station
  #(
    .DATA_WIDTH(
      C_M_AXI_DATA_WIDTH + 1 + C_M_AXI_ID_WIDTH + 2
    ),
    .DEPTH(2),
    .ADDR_WIDTH(1),
    .LEVEL(PIPELINE_LEVEL)
  )
  R_pipeline
  (
    .clk        (ap_clk),
    .if_read_ce (1'b1),
    .if_write_ce(1'b1),

    .if_din     ({out_RDATA, out_RLAST, out_RID, out_RRESP}),
    .if_full_n  ( out_RREADY),
    .if_write   ( out_RVALID),

    .if_dout    ({in_RDATA,  in_RLAST,  in_RID, in_RRESP}),
    .if_empty_n (in_RVALID),
    .if_read    (in_RREADY)
  );

  relay_station
  #(
    .DATA_WIDTH(
      2 + C_M_AXI_ID_WIDTH
    ),
    .DEPTH(2),
    .ADDR_WIDTH(1),
    .LEVEL(PIPELINE_LEVEL)
  )
  B_pipeline
  (
    .clk        (ap_clk),
    .if_read_ce (1'b1),
    .if_write_ce(1'b1),

    .if_din     ({out_BRESP,  out_BID}),
    .if_full_n  (out_BREADY),
    .if_write   (out_BVALID),

    .if_dout    ({ in_BRESP,  in_BID}),
    .if_empty_n (in_BVALID),
    .if_read    (in_BREADY)
  );

endmodule