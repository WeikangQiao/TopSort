/*
 * AXI4 Read channel register
 */
module axi_rd_register #
(
    parameter PIPE_LEVEL    =   3
)
(
    input  logic                     clk ,

    axi_bus_rd_t.slave               s_axi  ,
    axi_bus_rd_t.master              m_axi
);

relay_station
#(
    .DATA_WIDTH     ( $bits(s_axi.araddr) + $bits(s_axi.arid) + 8 + 3 + 2                   ),
    .DEPTH          ( 2                                                                     ),
    .ADDR_WIDTH     ( 1                                                                     ),
    .LEVEL          ( PIPE_LEVEL                                                            )
)
AR_pipeline
(
    .clk            ( clk                                                                   ),
    .if_read_ce     ( 1'b1                                                                  ),
    .if_write_ce    ( 1'b1                                                                  ),

    .if_din         ( {s_axi.araddr, s_axi.arid, s_axi.arlen, s_axi.arsize, s_axi.arburst}  ),
    .if_full_n      ( s_axi.arready                                                         ),
    .if_write       ( s_axi.arvalid                                                         ),

    .if_dout        ( {m_axi.araddr, m_axi.arid, m_axi.arlen, m_axi.arsize, m_axi.arburst}  ),
    .if_empty_n     ( m_axi.arvalid                                                         ),
    .if_read        ( m_axi.arready                                                         )
);

relay_station
#(
    .DATA_WIDTH     ( $bits(s_axi.rdata) + 1 + $bits(s_axi.rid) + 2                         ),
    .DEPTH          ( 2                                                                     ),
    .ADDR_WIDTH     ( 1                                                                     ),
    .LEVEL          ( PIPE_LEVEL                                                            )
)
R_pipeline
(
    .clk            ( clk                                                                   ),
    .if_read_ce     ( 1'b1                                                                  ),
    .if_write_ce    ( 1'b1                                                                  ),

    .if_din         ( {m_axi.rdata, m_axi.rlast, m_axi.rid, m_axi.rresp}                    ),
    .if_full_n      ( m_axi.rready                                                          ),
    .if_write       ( m_axi.rvalid                                                          ),

    .if_dout        ( {s_axi.rdata, s_axi.rlast, s_axi.rid, s_axi.rresp}                    ),
    .if_empty_n     ( s_axi.rvalid                                                          ),
    .if_read        ( s_axi.rready                                                          )
);

endmodule