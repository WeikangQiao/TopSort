/*
 * AXI4 register
 */
module axi_register #
(
    parameter PIPE_LEVEL    =   3
)
(
    input  logic                     clk    ,

    axi_bus_t.slave                  s_axi  ,
    axi_bus_t.master                 m_axi
);

axi_pipeline #(
    .C_M_AXI_DATA_WIDTH         ( $bits(s_axi.wdata)    ),
    .C_M_AXI_ADDR_WIDTH         ( $bits(s_axi.awaddr)   ),
    .C_M_AXI_WSTRB_WIDTH        ( $bits(s_axi.wstrb)    ),
    .C_M_AXI_ID_WIDTH           ( $bits(s_axi.rid)      ),
    .PIPELINE_LEVEL             ( PIPE_LEVEL            )
) 
u_axi_pipe(
    .ap_clk                     ( clk                   ),

    // pipeline in
    .in_AWVALID                 ( s_axi.awvalid         ),
    .in_AWREADY                 ( s_axi.awready         ),
    .in_AWADDR                  ( s_axi.awaddr          ),
    .in_AWBURST                 ( s_axi.awburst         ),
    .in_AWLEN                   ( s_axi.awlen           ),
    .in_AWSIZE                  ( s_axi.awsize          ),
    .in_AWID                    ( s_axi.awid            ),

    .in_WVALID                  ( s_axi.wvalid          ),
    .in_WREADY                  ( s_axi.wready          ),
    .in_WDATA                   ( s_axi.wdata           ),
    .in_WSTRB                   ( s_axi.wstrb           ),
    .in_WLAST                   ( s_axi.wlast           ),

    .in_BVALID                  ( s_axi.bvalid          ),
    .in_BREADY                  ( s_axi.bready          ),
    .in_BRESP                   ( s_axi.bresp           ),
    .in_BID                     ( s_axi.bid             ),

    .in_ARVALID                 ( s_axi.arvalid         ),
    .in_ARREADY                 ( s_axi.arready         ),
    .in_ARADDR                  ( s_axi.araddr          ),
    .in_ARBURST                 ( s_axi.arburst         ),
    .in_ARLEN                   ( s_axi.arlen           ),
    .in_ARSIZE                  ( s_axi.arsize          ),
    .in_ARID                    ( s_axi.arid            ),
  
    .in_RVALID                  ( s_axi.rvalid          ),
    .in_RREADY                  ( s_axi.rready          ),
    .in_RDATA                   ( s_axi.rdata           ),
    .in_RLAST                   ( s_axi.rlast           ),
    .in_RID                     ( s_axi.rid             ),
    .in_RRESP                   ( s_axi.rresp           ),

    // pipeline out
    .out_AWVALID                ( m_axi.awvalid         ),
    .out_AWREADY                ( m_axi.awready         ),
    .out_AWADDR                 ( m_axi.awaddr          ),
    .out_AWBURST                ( m_axi.awburst         ),
    .out_AWLEN                  ( m_axi.awlen           ),
    .out_AWSIZE                 ( m_axi.awsize          ),
    .out_AWID                   ( m_axi.awid            ),

    .out_WVALID                 ( m_axi.wvalid          ),
    .out_WREADY                 ( m_axi.wready          ),
    .out_WDATA                  ( m_axi.wdata           ),
    .out_WSTRB                  ( m_axi.wstrb           ),
    .out_WLAST                  ( m_axi.wlast           ),

    .out_BVALID                 ( m_axi.bvalid          ),
    .out_BREADY                 ( m_axi.bready          ),
    .out_BRESP                  ( m_axi.bresp           ),
    .out_BID                    ( m_axi.bid             ),

    .out_ARVALID                ( m_axi.arvalid         ),
    .out_ARREADY                ( m_axi.arready         ),
    .out_ARADDR                 ( m_axi.araddr          ),
    .out_ARBURST                ( m_axi.arburst         ),
    .out_ARLEN                  ( m_axi.arlen           ),
    .out_ARSIZE                 ( m_axi.arsize          ),
    .out_ARID                   ( m_axi.arid            ),

    .out_RVALID                 ( m_axi.rvalid          ),
    .out_RREADY                 ( m_axi.rready          ),
    .out_RDATA                  ( m_axi.rdata           ),
    .out_RLAST                  ( m_axi.rlast           ),
    .out_RID                    ( m_axi.rid             ),
    .out_RRESP                  ( m_axi.rresp           )
);

endmodule