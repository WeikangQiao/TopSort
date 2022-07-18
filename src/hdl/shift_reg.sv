/**********************************************************************************
 Shift register with 1-stage build-in register
**********************************************************************************/
module shift_reg #(
    parameter DATA_WIDTH = 8,
    parameter SRL_DEPTH = 16 
) 
(
    input  logic                        i_clk,
    input  logic [DATA_WIDTH-1:0]       i_data,
    output logic [DATA_WIDTH-1:0]       o_data
);

///////////////////////////////////////////////////////////////////////////////////
//Declarations
///////////////////////////////////////////////////////////////////////////////////

(* srl_style = "register" *) logic [DATA_WIDTH-1:0] out_data_reg = '0;
  
logic [DATA_WIDTH-1:0] srl_out;

///////////////////////////////////////////////////////////////////////////////////
//Main body of the code
///////////////////////////////////////////////////////////////////////////////////
  
srl_buf #(
  .DATA_WIDTH   ( DATA_WIDTH    ), 
  .SRL_DEPTH    ( SRL_DEPTH-1   )
) 
u_srl_buf (
    .i_clk      ( i_clk         ), 
    .i_data     ( i_data        ), 
    .o_data     ( srl_out       )
);
  
always_ff @(posedge i_clk) begin
    out_data_reg <= srl_out;
end 

assign o_data = out_data_reg;

endmodule