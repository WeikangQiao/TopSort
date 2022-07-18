/**********************************************************************************
 * This module pre-sorts the AXI_DATA_WIDTH data into sorted pieces, and the size of
   the sorted piece is specified by INIT_SORTED_CHUNK.
**********************************************************************************/

`include "macro_def.sv"

module presorter #(
    parameter integer  AXI_DATA_WIDTH   =   512 ,
    parameter integer  DATA_WIDTH       =   32  ,
    parameter integer  KEY_WIDTH        =   32  ,
    parameter integer  INIT_SORTED_CHUNK=   8    
)
(
    input   logic                               aclk    ,  
    input   logic   [AXI_DATA_WIDTH-1:0]        in_data ,
    output  logic   [AXI_DATA_WIDTH-1:0]        out_data
);

///////////////////////////////////////////////////////////////////////////////////
//Declarations
///////////////////////////////////////////////////////////////////////////////////
localparam integer LP_FULL_BUNDLE_WIDTH =   AXI_DATA_WIDTH / DATA_WIDTH;
localparam integer LP_BUNDLE_WIDTH      =   INIT_SORTED_CHUNK;
localparam integer LP_REC_SORT_STEPS    =   (INIT_SORTED_CHUNK == 1) ? 1 : `LOG2(LP_BUNDLE_WIDTH);
localparam integer LP_CHUNK_NUM         =   LP_FULL_BUNDLE_WIDTH / LP_BUNDLE_WIDTH;
localparam integer LP_BIT_PER_CHUNK     =   LP_BUNDLE_WIDTH * DATA_WIDTH;

logic [LP_REC_SORT_STEPS:0][AXI_DATA_WIDTH-1:0] elem_steps;   //elements after each step

///////////////////////////////////////////////////////////////////////////////////
//Main body of the code
///////////////////////////////////////////////////////////////////////////////////
assign elem_steps[0] = in_data;

generate genvar chunk, step, batch, elem_in, elem_out, half, stage, block;
    if (INIT_SORTED_CHUNK != 1) begin: bitonic
        for (chunk = 0; chunk < LP_CHUNK_NUM; chunk = chunk + 1) begin: foreach_chunk
            for (step = 0; step < LP_REC_SORT_STEPS; step = step + 1) begin: foreach_step
                localparam STAGE_NUM = step + 1;
                localparam BATCH_BUNDLE_WIDTH = 2**(STAGE_NUM);
                localparam BATCH_BUNDLE_WIDTH_HALF = BATCH_BUNDLE_WIDTH / 2;
                localparam BATCH_COUNT = LP_BUNDLE_WIDTH / BATCH_BUNDLE_WIDTH;
                localparam BIT_PER_BATCH = LP_BIT_PER_CHUNK / BATCH_COUNT;
                localparam BIT_PER_HALF_BATCH = BIT_PER_BATCH / 2;

                logic [STAGE_NUM-1:0][AXI_DATA_WIDTH-1:0] elem_stages;

                for (batch = 0; batch < BATCH_COUNT; batch = batch + 1) begin: foreach_batch
                    // always do reverser compare and swap in the first stage
                    logic [BATCH_BUNDLE_WIDTH_HALF*DATA_WIDTH-1:0]  low_half, high_half;
                    logic [BATCH_BUNDLE_WIDTH_HALF*DATA_WIDTH-1:0]  high_half_reverse;
                    logic [BATCH_BUNDLE_WIDTH_HALF*DATA_WIDTH-1:0]  low_sort, high_sort;
                    logic [BATCH_BUNDLE_WIDTH_HALF*DATA_WIDTH-1:0]  high_sort_reverse;

                    assign low_half = elem_steps[step][chunk * LP_BIT_PER_CHUNK + batch * BIT_PER_BATCH +: BIT_PER_HALF_BATCH];
                    assign high_half = elem_steps[step][chunk * LP_BIT_PER_CHUNK + batch * BIT_PER_BATCH + BIT_PER_HALF_BATCH +: BIT_PER_HALF_BATCH];
                    for (elem_in = 0; elem_in < BATCH_BUNDLE_WIDTH_HALF; elem_in = elem_in + 1) begin: reverse_in
                        assign high_half_reverse[elem_in * DATA_WIDTH +: DATA_WIDTH] = high_half[(BATCH_BUNDLE_WIDTH_HALF - 1 - elem_in) * DATA_WIDTH +: DATA_WIDTH];
                    end: reverse_in

                    cas #(
                        .DATA_WIDTH ( DATA_WIDTH            ),
                        .KEY_WIDTH  ( KEY_WIDTH             )
                    )
                    u_cas_s1 [BATCH_BUNDLE_WIDTH_HALF-1:0] (
                        .i_clk      ( aclk                  ),  
                        .i_en       ( 1'b1                  ),
                        .i_data_0   ( low_half              ),
                        .i_data_1   ( high_half_reverse     ),
                        .o_data_0   ( low_sort              ),
                        .o_data_1   ( high_sort_reverse     )
                    );

                    for (elem_out = 0; elem_out < BATCH_BUNDLE_WIDTH_HALF; elem_out = elem_out + 1) begin: reverse_out
                        assign high_sort[elem_out * DATA_WIDTH +: DATA_WIDTH] = high_sort_reverse[(BATCH_BUNDLE_WIDTH_HALF - 1 - elem_out) * DATA_WIDTH +: DATA_WIDTH];
                    end: reverse_out

                    assign elem_stages[0][chunk * LP_BIT_PER_CHUNK + batch * BIT_PER_BATCH +: BIT_PER_BATCH] = {high_sort, low_sort};

                    for (half = 0; half < 2; half = half + 1) begin: foreach_half

                        for (stage = 1; stage < STAGE_NUM; stage = stage + 1) begin: foreach_stage
                            localparam BLOCK_NUM = 2**(stage-1);
                            localparam BIT_PER_BLOCK = BIT_PER_HALF_BATCH / BLOCK_NUM;

                            for (block = 0; block < BLOCK_NUM; block = block + 1) begin: foreach_block
                                localparam BIT_OFFSET = BIT_PER_BLOCK * block;
                                logic [BIT_PER_BLOCK-1:0]   block_in;
                                logic [BIT_PER_BLOCK/2-1:0] block_out_low_half;
                                logic [BIT_PER_BLOCK/2-1:0] block_out_high_half;

                                assign block_in = elem_stages[stage-1][chunk * LP_BIT_PER_CHUNK + batch * BIT_PER_BATCH + half * BIT_PER_HALF_BATCH + BIT_OFFSET +: BIT_PER_BLOCK];

                                cas #(
                                    .DATA_WIDTH ( DATA_WIDTH    ),
                                    .KEY_WIDTH  ( KEY_WIDTH     )
                                )
                                cas_s [BATCH_BUNDLE_WIDTH_HALF/2/BLOCK_NUM-1:0] (
                                    .i_clk      ( aclk                                          ),  
                                    .i_en       ( 1'b1                                          ),
                                    .i_data_0   ( block_in[              0 +: BIT_PER_BLOCK/2]  ),
                                    .i_data_1   ( block_in[BIT_PER_BLOCK/2 +: BIT_PER_BLOCK/2]  ),
                                    .o_data_0   ( block_out_low_half                            ),
                                    .o_data_1   ( block_out_high_half                           )
                                );

                                assign elem_stages[stage][chunk * LP_BIT_PER_CHUNK + batch * BIT_PER_BATCH + half * BIT_PER_HALF_BATCH + BIT_OFFSET +: BIT_PER_BLOCK] = {block_out_high_half, block_out_low_half};

                            end: foreach_block

                        end: foreach_stage

                    end: foreach_half

                    assign elem_steps[step + 1][chunk * LP_BIT_PER_CHUNK + batch * BIT_PER_BATCH +: BIT_PER_BATCH] = elem_stages[STAGE_NUM - 1][chunk * LP_BIT_PER_CHUNK + batch * BIT_PER_BATCH +: BIT_PER_BATCH];
                end: foreach_batch

            end: foreach_step

        end: foreach_chunk
    end: bitonic
    else begin: pipe
        delay_chain #(.WIDTH(AXI_DATA_WIDTH), .STAGES(LP_REC_SORT_STEPS)) u_pipe(.clk(aclk), .in_bus(elem_steps[0]), .out_bus(elem_steps[LP_REC_SORT_STEPS]));
    end: pipe
endgenerate

assign out_data = elem_steps[LP_REC_SORT_STEPS];

endmodule