/**********************************************************************************
 Shift register:
 (1) SRL_DEPTH <= 3: implemented using register
 (2) SRL_DEPTH <= 16: implemented using SRLC16E
 (3) SRL_DEPTH <= 32: implemented using SRLC32E
**********************************************************************************/
module srl_buf #(
    parameter DATA_WIDTH = 8,
    parameter SRL_DEPTH = 16    // SRL_DEPTH <= 3: implemented using register; else: implemented using SRL_LUT 
) 
(
    input  logic                        i_clk,
    input  logic [DATA_WIDTH-1:0]       i_data,
    output logic [DATA_WIDTH-1:0]       o_data
);

///////////////////////////////////////////////////////////////////////////////////
//Declarations
///////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////
//Main body of the code
///////////////////////////////////////////////////////////////////////////////////

initial if(SRL_DEPTH>32) begin  
    $display("Invalid SRL_DEPTH(%d)", SRL_DEPTH); 
    $finish(); 
end

generate
    if(SRL_DEPTH == 0) begin : use_wire 
        assign o_data = i_data;
    end : use_wire
        
    else if(SRL_DEPTH <= 3) begin : use_reg // implemented using register chain
        logic [SRL_DEPTH-1:0][DATA_WIDTH-1:0] pipe = '0;

        integer i;
        always_ff @(posedge i_clk) begin
            for (i = 0; i < SRL_DEPTH; i = i + 1) begin
                pipe[i] <= i>0 ? pipe[i-1] : i_data;
            end 
        end
        assign o_data = pipe[SRL_DEPTH-1];        
    end : use_reg
        
    else if(SRL_DEPTH <= 16) begin : usr_srl16 // implemented using SRL16E
        logic [3:0] a = SRL_DEPTH - 1;

        SRLC16E #(
            .INIT   (16'h0000               ) // Initial Value of Shift Register
        ) 
        srl16_uut [DATA_WIDTH-1:0]
        (
            .Q      ( o_data                ), // SRL data output
            .Q15    ( /* unused */          ), // SRL 16th bit output
            .A0     ( a[0]                  ), // Select[0] input
            .A1     ( a[1]                  ), // Select[1] input
            .A2     ( a[2]                  ), // Select[2] input
            .A3     ( a[3]                  ), // Select[3] input
            .CE     ( 1'b1                  ), // Clock enable input
            .CLK    ( i_clk                 ), // Clock input
            .D      ( i_data                )  // SRL data input
        );
        
    end : usr_srl16

    else if(SRL_DEPTH <= 32) begin : usr_srl32 // implemented using SRLC32E
        logic [4:0] a = SRL_DEPTH - 1;

        SRLC32E #(
            .INIT   (32'h00000000           )
        )
        srl32_uut [DATA_WIDTH-1:0]
        (
            .Q      ( o_data                ),  // SRL data output 
            .Q31    ( /* unused */          ),  // SRL 32th bit output
            .A      ( a                     ),  // Select input
            .CE     ( 1'b1                  ),  // Clock enable input
            .CLK    ( i_clk                 ),  // Clock input
            .D      ( i_data                )   // SRL data input
        );

    end: usr_srl32
        
endgenerate

endmodule