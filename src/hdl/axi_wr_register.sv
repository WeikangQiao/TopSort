/*
 * AXI4 Write Channels Register
 */
module axi_wr_register #
(
    parameter PIPE_LEVEL    =   3
)
(
    input  logic                     clk ,

    axi_bus_wr_t.slave               s_axi  ,
    axi_bus_wr_t.master              m_axi
);

relay_station
#(
    .DATA_WIDTH     ( $bits(s_axi.awaddr) + $bits(s_axi.awid) + 8 + 3 + 2         ),
    .DEPTH          ( 2                                                           ),
    .ADDR_WIDTH     ( 1                                                           ),
    .LEVEL          ( PIPE_LEVEL                                                  )
)
AW_pipeline
(
    .clk            ( clk                                                         ),
    .if_read_ce     ( 1'b1                                                        ),
    .if_write_ce    ( 1'b1                                                        ),

    .if_din         ( {s_axi.awaddr, s_axi.awid, s_axi.awlen, s_axi.awsize, s_axi.awburst}   ),
    .if_full_n      ( s_axi.awready                                               ),
    .if_write       ( s_axi.awvalid                                               ),

    .if_dout        ( {m_axi.awaddr, m_axi.awid, m_axi.awlen, m_axi.awsize, m_axi.awburst}  ),
    .if_empty_n     ( m_axi.awvalid                                               ),
    .if_read        ( m_axi.awready                                               )
);

relay_station
#(
    .DATA_WIDTH     ( $bits(s_axi.wdata) + $bits(s_axi.wstrb) + 1                 ),
    .DEPTH          ( 2                                                           ),
    .ADDR_WIDTH     ( 1                                                           ),
    .LEVEL          ( PIPE_LEVEL                                                  )
)
W_pipeline
(
    .clk            ( clk                                                         ),
    .if_read_ce     ( 1'b1                                                        ),
    .if_write_ce    ( 1'b1                                                        ),

    .if_din         ( {s_axi.wdata, s_axi.wstrb, s_axi.wlast}                     ),
    .if_full_n      ( s_axi.wready                                                ),
    .if_write       ( s_axi.wvalid                                                ),

    .if_dout        ( {m_axi.wdata, m_axi.wstrb, m_axi.wlast}                     ),
    .if_empty_n     ( m_axi.wvalid                                                ),
    .if_read        ( m_axi.wready                                                )
);

relay_station
#(
    .DATA_WIDTH     ( 2 + $bits(s_axi.awid)                                       ),
    .DEPTH          ( 2                                                           ),
    .ADDR_WIDTH     ( 1                                                           ),
    .LEVEL          ( PIPE_LEVEL                                                  )
)
B_pipeline
(
    .clk            ( clk                                                         ),
    .if_read_ce     ( 1'b1                                                        ),
    .if_write_ce    ( 1'b1                                                        ),

    .if_din         ( {m_axi.bresp, m_axi.bid}                                    ),
    .if_full_n      ( m_axi.bready                                                ),
    .if_write       ( m_axi.bvalid                                                ),

    .if_dout        ( {s_axi.bresp, s_axi.bid}                                    ),
    .if_empty_n     ( s_axi.bvalid                                                ),
    .if_read        ( s_axi.bready                                                )
  );

endmodule