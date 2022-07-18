/**********************************************************************************
 This module is the LUTs based fifos and contains the following features:
 (1) its depth should be no more than 32;
 (2) when it is full and we do simultaneous read and write, only read operation 
     is valid;
**********************************************************************************/
module qshift_fifo
#(
  parameter integer             FIFO_WIDTH          = 32,
  parameter integer             FIFO_DEPTH          = 16,
  parameter integer             PROG_FULL_THRESH    = 32
) 
(
  input  logic 		                    i_clk       ,
  input  logic [FIFO_WIDTH-1:0]         i_din       ,
  input  logic 		                    i_wr_en     ,
  input  logic 		                    i_rd_en     ,
  output logic [FIFO_WIDTH-1:0]         o_dout      ,
  output logic 		                    o_full      , 
  output logic		                    o_empty     ,
  output logic                          o_prog_full 
);


///////////////////////////////////////////////////////////////////////////////////
//Declarations
///////////////////////////////////////////////////////////////////////////////////

localparam  LP_ADDR_WIDTH   = $clog2(FIFO_DEPTH) + 1;
localparam  LP_DEPTH_WIDTH  = FIFO_DEPTH <= 16 ? 4: 5;

logic [LP_ADDR_WIDTH-1:0]   addr    =   '1  ;   // Initialize to all 1s to indicate empty
logic [LP_DEPTH_WIDTH-1:0]  depth           ;
logic                       rd_en_int       ;
logic                       wr_en_int       ;


///////////////////////////////////////////////////////////////////////////////////
//Main body of the code
///////////////////////////////////////////////////////////////////////////////////

always_comb begin
    depth                       =   'b0;
    depth[0+:LP_ADDR_WIDTH-1]   =   addr[0+:LP_ADDR_WIDTH-1];

    rd_en_int                   = i_rd_en & !o_empty;
    wr_en_int                   = i_wr_en & !o_full;
end

always_ff @(posedge i_clk) begin
    case ({rd_en_int, wr_en_int})
        2'b00:  // No read and write
            addr <= addr;
        2'b01:  // Write and not read
            addr <= addr + 1;
        2'b10:  // Read and not write
            addr <= addr - 1;
        2'b11:  // Read and write
            addr <= addr;
        default:
            addr <= addr;
    endcase
end

generate
if (FIFO_DEPTH <= 16)   begin: USE_SRL16E
    SRLC16E #(
        .INIT   (16'h0000               ) // Initial Value of Shift Register
    ) 
    srl_array [FIFO_WIDTH-1:0]
    (
        .Q      ( o_dout                ), // SRL data output
        .Q15    ( /* unused */          ), // SRL 16th bit output
        .A0     ( depth[0]              ), // Select[0] input
        .A1     ( depth[1]              ), // Select[1] input
        .A2     ( depth[2]              ), // Select[2] input
        .A3     ( depth[3]              ), // Select[3] input
        .CE     ( i_wr_en & !o_full     ), // Clock enable input
        .CLK    ( i_clk                 ), // Clock input
        .D      ( i_din                 )  // SRL data input
    );
end: USE_SRL16E
else    begin: USE_SRL32E
    SRLC32E #(
        .INIT   (32'h00000000           )
    )
    srl_array [FIFO_WIDTH-1:0]
    (
        .Q      ( o_dout                ),  // SRL data output 
        .Q31    ( /* unused */          ),  // SRL 32th bit output
        .A      ( depth[0+:5]           ),  // Select input
        .CE     ( i_wr_en & !o_full     ),  // Clock enable input
        .CLK    ( i_clk                 ),  // Clock input
        .D      ( i_din                 )   // SRL data input
    );
end: USE_SRL32E
endgenerate

//Generate output control signals
assign o_empty      = addr[LP_ADDR_WIDTH-1];
assign o_full       = addr == FIFO_DEPTH - 1;
assign o_prog_full  = (addr[0+:LP_ADDR_WIDTH-1] >= PROG_FULL_THRESH - 1) && ~addr[LP_ADDR_WIDTH-1];  

endmodule