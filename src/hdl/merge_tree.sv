`include "macro_def.sv"

/**********************************************************************************
 * This is the merge tree kernel:
 *  its leaves directly take data from read burst buffers;
 *  its root writes to a root buffer and interacts with the write burst buffer
**********************************************************************************/

module merge_tree #(
    parameter integer  DATA_WIDTH   = 64,
    parameter integer  KEY_WIDTH    = 32,
    parameter integer  BUNDLE_WIDTH = 8 ,
    parameter integer  NUM_LEAVES   = 32
)
(
    input  logic                                    i_clk               ,

    input  logic [NUM_LEAVES-1:0][DATA_WIDTH:0]     i_leaf_data         ,   // {last, data} from each leaf
    input  logic [NUM_LEAVES-1:0]                   i_leaf_data_vld     ,   // valid signal for data from each leaf
    input  logic                                    i_root_read         ,   // enable signal for reading the root fifo

    output logic [NUM_LEAVES-1:0]                   o_leaf_read         ,   // enable signal for reading each leaf
    output logic [BUNDLE_WIDTH*DATA_WIDTH-1:0]      o_root_data         ,   // root output data
    output logic                                    o_root_data_vld         // root output data valid
);

///////////////////////////////////////////////////////////////////////////////////
//Declarations
///////////////////////////////////////////////////////////////////////////////////
logic   [7:0]                               lc_8_read;
logic   [7:0][2*DATA_WIDTH:0]               lc_8_data_in;
logic   [7:0]                               lc_8_data_in_vld;

logic   [3:0]                               lc_4_read;
logic   [3:0][4*DATA_WIDTH:0]               lc_4_data_in;
logic   [3:0]                               lc_4_data_in_vld;

logic   [1:0]                               lc_2_read;
logic   [1:0][8*DATA_WIDTH:0]               lc_2_data_in;
logic   [1:0]                               lc_2_data_in_vld;


///////////////////////////////////////////////////////////////////////////////////
//Main body of the code
///////////////////////////////////////////////////////////////////////////////////
genvar  leaf_cnt, i;
generate
    for (leaf_cnt = NUM_LEAVES; leaf_cnt >= 2; leaf_cnt = leaf_cnt / 2) begin: foreach_level
        if (leaf_cnt == 16) begin: leaf_cnt_16
            for (i = 0; i < leaf_cnt / 2; i++) begin: foreach_leaf_pair
                localparam  LP_BUNDLE_WIDTH =   1;
                localparam  LP_BM_LATENCY   = `LOG2(LP_BUNDLE_WIDTH) + 1;
                localparam  LP_ML_LATENCY   = (LP_BUNDLE_WIDTH <= 1) ? 1 : (2 * LP_BM_LATENCY + 2) / 2;

                logic   [LP_BUNDLE_WIDTH*DATA_WIDTH:0]      ml_data;
                logic                                       ml_write;
                logic                                       coupler_prog_full;
                logic                                       coupler_read;
                logic   [2*LP_BUNDLE_WIDTH*DATA_WIDTH:0]    coupler_data;
                logic                                       coupler_empty;

                merge_logic #(
                    .DATA_WIDTH             ( DATA_WIDTH                ),
                    .KEY_WIDTH              ( KEY_WIDTH                 ),
                    .BUNDLE_WIDTH           ( LP_BUNDLE_WIDTH           )
                )
                u_merge_logic(
                    .i_clk                  ( i_clk                     ),

                    .i_fifo_data_0          ( i_leaf_data[2*i]          ),   // {last, data} from input fifo 0
                    .i_fifo_data_0_vld      ( i_leaf_data_vld[2*i]      ),   // valid signal for data from input fifo 0
                    .i_fifo_data_1          ( i_leaf_data[2*i+1]        ),   // {last, data} from input fifo 1
                    .i_fifo_data_1_vld      ( i_leaf_data_vld[2*i+1]    ),   // valid signal for data from input fifo 1
                    .i_fifo_full            ( coupler_prog_full         ),   // programmable full from the coupler

                    .o_fifo_0_read          ( o_leaf_read[2*i]          ),   // enable signal for reading input fifo 0
                    .o_fifo_1_read          ( o_leaf_read[2*i+1]        ),   // enable signal for reading input fifo 1
                    .o_fifo_data            ( ml_data                   ),   // output data
                    .o_fifo_write           ( ml_write                  )    // enable signal for writing outout fifo
                );

                assign  coupler_read    =   lc_8_read[i];

                coupler #(
                    .DATA_WIDTH             ( DATA_WIDTH                ),
                    .BUNDLE_WIDTH           ( LP_BUNDLE_WIDTH           ),
                    .FIFO_DEPTH             ( 32                        ),
                    .PROG_FULL_THRESH       ( 32 - LP_ML_LATENCY        )
                )
                u_coupler (
                    .i_clk                  ( i_clk                     ),

                    .i_fifo_data            ( ml_data                   ),   // input data to the coupler: {last, data}
                    .i_fifo_write           ( ml_write                  ),   // write enable signal to the coupler
                    .i_fifo_read            ( coupler_read              ),   // read enable signal to the coupler

                    .o_fifo_data            ( coupler_data              ),   // output data from the coupler
                    .o_fifo_prog_full       ( coupler_prog_full         ),   // programmable full from the coupler
                    .o_fifo_empty           ( coupler_empty             )
                );

                assign  lc_8_data_in[i]     =   coupler_data;
                assign  lc_8_data_in_vld[i] =   !coupler_empty;

            end: foreach_leaf_pair
        end: leaf_cnt_16

        else if (leaf_cnt == 8) begin: leaf_cnt_8
            for (i = 0; i < leaf_cnt / 2; i++) begin: foreach_leaf_pair
                localparam  LP_BUNDLE_WIDTH =   2;
                localparam  LP_BM_LATENCY   = `LOG2(LP_BUNDLE_WIDTH) + 1;
                localparam  LP_ML_LATENCY   = (LP_BUNDLE_WIDTH <= 1) ? 1 : (2 * LP_BM_LATENCY + 2) / 2;

                logic   [LP_BUNDLE_WIDTH*DATA_WIDTH:0]      ml_data;
                logic                                       ml_write;
                logic                                       coupler_prog_full;
                logic                                       coupler_read;
                logic   [2*LP_BUNDLE_WIDTH*DATA_WIDTH:0]    coupler_data;
                logic                                       coupler_empty;

                merge_logic #(
                    .DATA_WIDTH             ( DATA_WIDTH                ),
                    .KEY_WIDTH              ( KEY_WIDTH                 ),
                    .BUNDLE_WIDTH           ( LP_BUNDLE_WIDTH           )
                )
                u_merge_logic(
                    .i_clk                  ( i_clk                     ),

                    .i_fifo_data_0          ( lc_8_data_in[2*i]         ),   // {last, data} from input fifo 0
                    .i_fifo_data_0_vld      ( lc_8_data_in_vld[2*i]     ),   // valid signal for data from input fifo 0
                    .i_fifo_data_1          ( lc_8_data_in[2*i+1]       ),   // {last, data} from input fifo 1
                    .i_fifo_data_1_vld      ( lc_8_data_in_vld[2*i+1]   ),   // valid signal for data from input fifo 1
                    .i_fifo_full            ( coupler_prog_full         ),   // programmable full from the coupler

                    .o_fifo_0_read          ( lc_8_read[2*i]            ),   // enable signal for reading input fifo 0
                    .o_fifo_1_read          ( lc_8_read[2*i+1]          ),   // enable signal for reading input fifo 1
                    .o_fifo_data            ( ml_data                   ),   // output data
                    .o_fifo_write           ( ml_write                  )    // enable signal for writing outout fifo
                );

                assign  coupler_read    =   lc_4_read[i];

                coupler #(
                    .DATA_WIDTH             ( DATA_WIDTH                ),
                    .BUNDLE_WIDTH           ( LP_BUNDLE_WIDTH           ),
                    .FIFO_DEPTH             ( 32                        ),
                    .PROG_FULL_THRESH       ( 32 - LP_ML_LATENCY        )
                )
                u_coupler (
                    .i_clk                  ( i_clk                     ),

                    .i_fifo_data            ( ml_data                   ),   // input data to the coupler: {last, data}
                    .i_fifo_write           ( ml_write                  ),   // write enable signal to the coupler
                    .i_fifo_read            ( coupler_read              ),   // read enable signal to the coupler

                    .o_fifo_data            ( coupler_data              ),   // output data from the coupler
                    .o_fifo_prog_full       ( coupler_prog_full         ),   // programmable full from the coupler
                    .o_fifo_empty           ( coupler_empty             )
                );

                assign  lc_4_data_in[i]     =   coupler_data;
                assign  lc_4_data_in_vld[i] =   !coupler_empty;

            end: foreach_leaf_pair
        end: leaf_cnt_8

        else if (leaf_cnt == 4) begin: leaf_cnt_4
            for (i = 0; i < leaf_cnt / 2; i++) begin: foreach_leaf_pair
                localparam  LP_BUNDLE_WIDTH =   4;
                localparam  LP_BM_LATENCY   = `LOG2(LP_BUNDLE_WIDTH) + 1;
                localparam  LP_ML_LATENCY   = (LP_BUNDLE_WIDTH <= 1) ? 1 : (2 * LP_BM_LATENCY + 2) / 2;

                logic   [LP_BUNDLE_WIDTH*DATA_WIDTH:0]      ml_data;
                logic                                       ml_write;
                logic                                       coupler_prog_full;
                logic                                       coupler_read;
                logic   [2*LP_BUNDLE_WIDTH*DATA_WIDTH:0]    coupler_data;
                logic                                       coupler_empty;

                merge_logic #(
                    .DATA_WIDTH             ( DATA_WIDTH                ),
                    .KEY_WIDTH              ( KEY_WIDTH                 ),
                    .BUNDLE_WIDTH           ( LP_BUNDLE_WIDTH           )
                )
                u_merge_logic(
                    .i_clk                  ( i_clk                     ),

                    .i_fifo_data_0          ( lc_4_data_in[2*i]         ),   // {last, data} from input fifo 0
                    .i_fifo_data_0_vld      ( lc_4_data_in_vld[2*i]     ),   // valid signal for data from input fifo 0
                    .i_fifo_data_1          ( lc_4_data_in[2*i+1]       ),   // {last, data} from input fifo 1
                    .i_fifo_data_1_vld      ( lc_4_data_in_vld[2*i+1]   ),   // valid signal for data from input fifo 1
                    .i_fifo_full            ( coupler_prog_full         ),   // programmable full from the coupler

                    .o_fifo_0_read          ( lc_4_read[2*i]            ),   // enable signal for reading input fifo 0
                    .o_fifo_1_read          ( lc_4_read[2*i+1]          ),   // enable signal for reading input fifo 1
                    .o_fifo_data            ( ml_data                   ),   // output data
                    .o_fifo_write           ( ml_write                  )    // enable signal for writing outout fifo
                );

                assign  coupler_read    =   lc_2_read[i];

                coupler #(
                    .DATA_WIDTH             ( DATA_WIDTH                ),
                    .BUNDLE_WIDTH           ( LP_BUNDLE_WIDTH           ),
                    .FIFO_DEPTH             ( 32                        ),
                    .PROG_FULL_THRESH       ( 32 - LP_ML_LATENCY        )
                )
                u_coupler (
                    .i_clk                  ( i_clk                     ),

                    .i_fifo_data            ( ml_data                   ),   // input data to the coupler: {last, data}
                    .i_fifo_write           ( ml_write                  ),   // write enable signal to the coupler
                    .i_fifo_read            ( coupler_read              ),   // read enable signal to the coupler

                    .o_fifo_data            ( coupler_data              ),   // output data from the coupler
                    .o_fifo_prog_full       ( coupler_prog_full         ),   // programmable full from the coupler
                    .o_fifo_empty           ( coupler_empty             )
                );

                assign  lc_2_data_in[i]     =   coupler_data;
                assign  lc_2_data_in_vld[i] =   !coupler_empty;

            end: foreach_leaf_pair
        end: leaf_cnt_4

        else if (leaf_cnt == 2) begin: leaf_cnt_2
            for (i = 0; i < leaf_cnt / 2; i++) begin: foreach_leaf_pair
                localparam  LP_BUNDLE_WIDTH =   8;
                localparam  LP_BM_LATENCY   = `LOG2(LP_BUNDLE_WIDTH) + 1;
                localparam  LP_ML_LATENCY   = (LP_BUNDLE_WIDTH <= 1) ? 1 : (2 * LP_BM_LATENCY + 2); // Here no coupler, so threshold doubles

                logic   [LP_BUNDLE_WIDTH*DATA_WIDTH:0]      ml_data         ;
                logic                                       ml_write        ;
                logic                                       root_fifo_empty ;
                logic                                       root_fifo_prog_full;

                merge_logic #(
                    .DATA_WIDTH             ( DATA_WIDTH                ),
                    .KEY_WIDTH              ( KEY_WIDTH                 ),
                    .BUNDLE_WIDTH           ( LP_BUNDLE_WIDTH           )
                )
                u_merge_logic(
                    .i_clk                  ( i_clk                     ),

                    .i_fifo_data_0          ( lc_2_data_in[2*i]         ),   // {last, data} from input fifo 0
                    .i_fifo_data_0_vld      ( lc_2_data_in_vld[2*i]     ),   // valid signal for data from input fifo 0
                    .i_fifo_data_1          ( lc_2_data_in[2*i+1]       ),   // {last, data} from input fifo 1
                    .i_fifo_data_1_vld      ( lc_2_data_in_vld[2*i+1]   ),   // valid signal for data from input fifo 1
                    .i_fifo_full            ( root_fifo_prog_full       ),   // programmable full from the coupler

                    .o_fifo_0_read          ( lc_2_read[2*i]            ),   // enable signal for reading input fifo 0
                    .o_fifo_1_read          ( lc_2_read[2*i+1]          ),   // enable signal for reading input fifo 1
                    .o_fifo_data            ( ml_data                   ),   // output data
                    .o_fifo_write           ( ml_write                  )    // enable signal for writing outout fifo
                );

                // root fifo: it can be removed to save resources
                qshift_fifo #(
                  .FIFO_WIDTH           ( LP_BUNDLE_WIDTH*DATA_WIDTH                ),
                  .FIFO_DEPTH           ( 32                                        ),
                  .PROG_FULL_THRESH     ( 32 - LP_ML_LATENCY                        )
                ) 
                u_root_fifo (
                  .i_clk                ( i_clk                                     ),
                  .i_din                ( ml_data[0+:LP_BUNDLE_WIDTH*DATA_WIDTH]    ),
                  .i_wr_en              ( ml_write                                  ),
                  .i_rd_en              ( i_root_read                               ),
                  .o_dout               ( o_root_data                               ),
                  .o_full               ( /* Unused */                              ), 
                  .o_empty              ( root_fifo_empty                           ),
                  .o_prog_full          ( root_fifo_prog_full                       )
                );

                assign o_root_data_vld =   ~root_fifo_empty;
            end: foreach_leaf_pair
        end: leaf_cnt_2

    end: foreach_level
endgenerate


endmodule