`include "macro_def.sv"
/**********************************************************************************
 This module is the bitonic half merger that outputs the larger half
**********************************************************************************/
module bitonic_merger_s #(
    parameter integer  DATA_WIDTH   = 32,
    parameter integer  KEY_WIDTH    = 32, 
    parameter integer  BUNDLE_WIDTH = 16
) 
(
    input   logic                                   i_clk       ,
    input   logic                                   i_valid     ,
    input   logic [DATA_WIDTH*BUNDLE_WIDTH-1:0]     i_bundle_0  ,
    input   logic [DATA_WIDTH*BUNDLE_WIDTH-1:0]     i_bundle_1  ,
    input   logic                                   i_last      , // make sure i_valid is deasserted in the cycle after i_last is asserted so that the larger half can be popped out
    output  logic [DATA_WIDTH*BUNDLE_WIDTH-1:0]     o_bundle    , 
    output  logic                                   o_valid
);

///////////////////////////////////////////////////////////////////////////////////
//Declarations
///////////////////////////////////////////////////////////////////////////////////

localparam STAGE_NUM = `LOG2(BUNDLE_WIDTH) + 1; // this is the total number of latency

logic [DATA_WIDTH*BUNDLE_WIDTH-1:0]                     bundel_1_reverse;
logic [DATA_WIDTH*BUNDLE_WIDTH-1:0]                     bundle_0_s1;
logic [DATA_WIDTH*BUNDLE_WIDTH-1:0]                     bundle_1_s1;
logic                                                   valid_s1;
logic                                                   last_s1;
logic                                                   last_s2;
logic [STAGE_NUM-1:0][DATA_WIDTH*BUNDLE_WIDTH-1:0]      bundle_s;
logic [STAGE_NUM-1:0][0:0]                              enable_s;
//logic [0:0]                              enable_s[0:STAGE_NUM-1];
//logic [DATA_WIDTH*BUNDLE_WIDTH-1:0]      bundle_s[0:STAGE_NUM-1];


///////////////////////////////////////////////////////////////////////////////////
//Main body of the code
///////////////////////////////////////////////////////////////////////////////////

// Reverse i_bundle_1 to make {i_bundle_0, i_bundle_1_reverse} bitonic
generate genvar gi;
    for (gi = 0; gi < BUNDLE_WIDTH; gi = gi + 1) begin: Reverse 
        assign bundel_1_reverse[gi * DATA_WIDTH +: DATA_WIDTH] = i_bundle_1[(BUNDLE_WIDTH - 1 - gi) * DATA_WIDTH +: DATA_WIDTH];
    end
endgenerate

// stage 1
cas #(
    .DATA_WIDTH ( DATA_WIDTH        ),
    .KEY_WIDTH  ( KEY_WIDTH         )
)
u_cas_s1 [BUNDLE_WIDTH-1:0] (
    .i_clk      ( i_clk             ),  
    .i_en       ( i_valid           ),
    .i_data_0   ( i_bundle_0        ),
    .i_data_1   ( bundel_1_reverse  ),
    .o_data_0   ( bundle_0_s1       ),
    .o_data_1   ( bundle_1_s1       )
);

qreg #(.N(1))   enable_reg_s1(.i_clk(i_clk), .i_d(i_valid), .o_q(valid_s1));
qreg #(.N(1))   last_reg_s1(.i_clk(i_clk), .i_d(i_last), .o_q(last_s1));

// stage 2   
qreg #(.N(1))   last_reg_s2(.i_clk(i_clk), .i_d(last_s1), .o_q(last_s2));

// stage 2-STAGE_NUM: do the divide-conquer bitonic merge
assign bundle_s[0] = last_s2 ? bundle_1_s1 : bundle_0_s1;   // Switch output:
                                                            // ideally bundle_1_s1 should be bundle_1_s2, but since i_valid is deasserted, bundle_1_s1 is not updated.
    
assign enable_s[0] = last_s2 ? 1'b1 : valid_s1; // Add 1 more cycle for valid

generate genvar stage, block;
    for (stage = 1; stage < STAGE_NUM; stage = stage + 1) begin: PBM // each stage we have Parallel Bitonic Mergers
        localparam BLOCK_NUM = 2**(stage-1);
        localparam WIRE_PER_BLOCK = DATA_WIDTH * BUNDLE_WIDTH / BLOCK_NUM;
        for (block = 0; block < BLOCK_NUM; block = block + 1) begin: CAS_BLOCK
            localparam                      WIRE_OFFSET = WIRE_PER_BLOCK * block;
            logic [WIRE_PER_BLOCK-1:0]      block_in;
            logic [WIRE_PER_BLOCK/2-1:0]    block_out_0;
            logic [WIRE_PER_BLOCK/2-1:0]    block_out_1;

            assign block_in = bundle_s[stage-1][WIRE_OFFSET +: WIRE_PER_BLOCK];

            cas #(
                .DATA_WIDTH ( DATA_WIDTH    ),
                .KEY_WIDTH  ( KEY_WIDTH     )
            )
            cas_s [BUNDLE_WIDTH/2/BLOCK_NUM-1:0] (
                .i_clk      ( i_clk                                          ),  
                .i_en       ( enable_s[stage-1]                              ),
                .i_data_0   ( block_in[               0 +: WIRE_PER_BLOCK/2] ),
                .i_data_1   ( block_in[WIRE_PER_BLOCK/2 +: WIRE_PER_BLOCK/2] ),
                .o_data_0   ( block_out_0                                    ),
                .o_data_1   ( block_out_1                                    )
            );
            assign bundle_s[stage][WIRE_OFFSET +: WIRE_PER_BLOCK] = {block_out_1, block_out_0};
        end: CAS_BLOCK
        qreg #(.N(1))   enable_reg_s(.i_clk(i_clk), .i_d(enable_s[stage-1]), .o_q(enable_s[stage]));
    end: PBM
endgenerate

assign o_bundle = bundle_s[STAGE_NUM-1];
assign o_valid = enable_s[STAGE_NUM-1];

endmodule
