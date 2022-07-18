/*
 * FWFT FIFO Register
 */
module fifo_gen_register #
(
    parameter DATA_WIDTH    =   32,
    parameter PIPE_LEVEL    =   2
)
(
    input  logic                     clk ,

    input  logic                     s_data_vld   ,
    input  logic [DATA_WIDTH-1:0]    s_data       ,
    output logic                     s_read       ,
    
    output logic                     m_data_vld   ,
    output logic [DATA_WIDTH-1:0]    m_data       ,
    input  logic                     m_read       
);

relay_station
#(
    .DATA_WIDTH     ( DATA_WIDTH            ),
    .DEPTH          ( 2                     ),
    .ADDR_WIDTH     ( 1                     ),
    .LEVEL          ( PIPE_LEVEL            )
)
u_pipeline
(
    .clk            ( clk                   ),
    .if_read_ce     ( 1'b1                  ),
    .if_write_ce    ( 1'b1                  ),

    .if_din         ( s_data                ),
    .if_full_n      ( s_read                ),
    .if_write       ( s_data_vld            ),

    .if_dout        ( m_data                ),
    .if_empty_n     ( m_data_vld            ),
    .if_read        ( m_read                )
);

endmodule