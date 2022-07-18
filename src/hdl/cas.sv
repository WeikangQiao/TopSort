/**********************************************************************************
 This module compares the keys of two inputs and swap them if needed
**********************************************************************************/
module cas 
#(
    parameter integer  DATA_WIDTH = 32,
    parameter integer  KEY_WIDTH  = 32
)
(
    input   logic                               i_clk       ,  
    input   logic                               i_en        ,
    input   logic    [DATA_WIDTH-1:0]           i_data_0    ,
    input   logic    [DATA_WIDTH-1:0]           i_data_1    ,
    output  logic    [DATA_WIDTH-1:0]           o_data_0    ,
    output  logic    [DATA_WIDTH-1:0]           o_data_1
);

///////////////////////////////////////////////////////////////////////////////////
//Declarations
///////////////////////////////////////////////////////////////////////////////////
localparam VALUE_WIDTH = DATA_WIDTH - KEY_WIDTH;

logic [DATA_WIDTH-1:0]      out_data_reg_0 = '0;
logic [DATA_WIDTH-1:0]      out_data_reg_1 = '0;

///////////////////////////////////////////////////////////////////////////////////
//Main body of the code
///////////////////////////////////////////////////////////////////////////////////
always_ff @(posedge i_clk) begin
    if (i_en) begin
        if (i_data_0[VALUE_WIDTH+:KEY_WIDTH] > i_data_1[VALUE_WIDTH+:KEY_WIDTH]) begin
            out_data_reg_0 <= i_data_1;
            out_data_reg_1 <= i_data_0;
        end
        else begin
            out_data_reg_0 <= i_data_0;
            out_data_reg_1 <= i_data_1;
        end
    end 
end

assign o_data_0 = out_data_reg_0;
assign o_data_1 = out_data_reg_1;

endmodule