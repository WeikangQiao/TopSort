/*
 * FWFT FIFO Register
 */
module fifo_register #
(
    parameter PIPE_LEVEL    =   3
)
(
    input  logic                     clk     ,

    fifo_if_t.slave                  s_fifo  ,
    fifo_if_t.master                 m_fifo
);

relay_station
#(
    .DATA_WIDTH     ( $bits(s_fifo.data)    ),
    .DEPTH          ( 2                     ),
    .ADDR_WIDTH     ( 1                     ),
    .LEVEL          ( PIPE_LEVEL            )
)
u_pipeline
(
    .clk            ( clk                   ),
    .if_read_ce     ( 1'b1                  ),
    .if_write_ce    ( 1'b1                  ),

    .if_din         ( s_fifo.data           ),
    .if_full_n      ( s_fifo.read           ),
    .if_write       ( s_fifo.data_vld       ),

    .if_dout        ( m_fifo.data           ),
    .if_empty_n     ( m_fifo.data_vld       ),
    .if_read        ( m_fifo.read           )
);

endmodule