module mux_4_to_1 #(
   parameter integer RECORD_DATA_WIDTH     =   32
)
(
    input    logic [RECORD_DATA_WIDTH-1:0]      i_data_0         ,
    input    logic [RECORD_DATA_WIDTH-1:0]      i_data_1         ,
    input    logic [RECORD_DATA_WIDTH-1:0]      i_data_2         ,
    input    logic [RECORD_DATA_WIDTH-1:0]      i_data_3         ,
    input    logic [1:0]                        i_sel            ,

    output   logic [RECORD_DATA_WIDTH-1:0]      o_data
);

assign o_data = i_sel[1]    ?   (i_sel[0] ? i_data_3 : i_data_2) 
                            :   (i_sel[0] ? i_data_1 : i_data_0);

endmodule

module mux_8_to_1 #(
   parameter integer RECORD_DATA_WIDTH     =   32
)
(
    input    logic [RECORD_DATA_WIDTH-1:0]      i_data_0         ,
    input    logic [RECORD_DATA_WIDTH-1:0]      i_data_1         ,
    input    logic [RECORD_DATA_WIDTH-1:0]      i_data_2         ,
    input    logic [RECORD_DATA_WIDTH-1:0]      i_data_3         ,
    input    logic [RECORD_DATA_WIDTH-1:0]      i_data_4         ,
    input    logic [RECORD_DATA_WIDTH-1:0]      i_data_5         ,
    input    logic [RECORD_DATA_WIDTH-1:0]      i_data_6         ,
    input    logic [RECORD_DATA_WIDTH-1:0]      i_data_7         ,
    input    logic [2:0]                        i_sel            ,

    output   logic [RECORD_DATA_WIDTH-1:0]      o_data
);

logic [RECORD_DATA_WIDTH-1:0]      temp_data_0;
logic [RECORD_DATA_WIDTH-1:0]      temp_data_1;

mux_4_to_1 #(
    .RECORD_DATA_WIDTH   ( RECORD_DATA_WIDTH    )
)
u_mux_0(
    .i_data_0           ( i_data_0              ),
    .i_data_1           ( i_data_1              ),
    .i_data_2           ( i_data_2              ),
    .i_data_3           ( i_data_3              ),
    .i_sel              ( i_sel[1:0]            ),
    .o_data             ( temp_data_0           )
);

mux_4_to_1 #(
    .RECORD_DATA_WIDTH   ( RECORD_DATA_WIDTH    )
)
u_mux_1(
    .i_data_0           ( i_data_4              ),
    .i_data_1           ( i_data_5              ),
    .i_data_2           ( i_data_6              ),
    .i_data_3           ( i_data_7              ),
    .i_sel              ( i_sel[1:0]            ),

    .o_data             ( temp_data_1           )
);

assign o_data = i_sel[2] ? temp_data_1 : temp_data_0;


endmodule