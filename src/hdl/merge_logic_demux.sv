`include "macro_def.sv"

/**********************************************************************************
 * This is the merge logic demux module
 *  its leaves directly take data from root merge logic
 *  its root writes to a root buffer and interacts with the write burst buffer
 *  its root coupler writes to next level merge logic in phase 2
**********************************************************************************/

module merge_logic_demux #(
    parameter integer  DATA_WIDTH   = 64,
    parameter integer  KEY_WIDTH    = 32,
    parameter integer  BUNDLE_WIDTH = 8 
)
(
    input  logic                                    i_clk               ,

    input  logic                                    i_phase_sel         ,   // 0: phase 1; 1: phase 2
    input  logic [BUNDLE_WIDTH*DATA_WIDTH:0]        i_ml_data           ,   // root ml data
    input  logic                                    i_ml_data_vld       ,   // root ml data valid
    input  logic                                    i_root_read         ,   // enable signal for reading the root fifo, this is for phase 1
    input  logic                                    i_coupler_read      ,   // enable signal for reading the root coupler, this is for phase 2

    output logic                                    o_ml_read           ,   // enable signal for reading ml
    output logic [BUNDLE_WIDTH*DATA_WIDTH-1:0]      o_root_data         ,   // root output data
    output logic                                    o_root_data_vld     ,   // root output data valid
    output logic [2*BUNDLE_WIDTH*DATA_WIDTH:0]      o_coupler_data      ,   // root coupler output data
    output logic                                    o_coupler_data_vld      // root coupler output data valid
);

///////////////////////////////////////////////////////////////////////////////////
//Declarations
///////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////
//Main body of the code
///////////////////////////////////////////////////////////////////////////////////

    localparam  LP_BUNDLE_WIDTH = BUNDLE_WIDTH;
    localparam  LP_BM_LATENCY   = `LOG2(LP_BUNDLE_WIDTH) + 1;
    localparam  LP_ML_LATENCY   = (LP_BUNDLE_WIDTH <= 1) ? 1 : (2 * LP_BM_LATENCY + 2); // Here no coupler, so threshold doubles
    localparam  LP_CP_LATENCY   = (LP_BUNDLE_WIDTH <= 1) ? 1 : (2 * LP_BM_LATENCY + 2) / 2; // The last 2 is counting for cross-die regs, need to check

    logic   [LP_BUNDLE_WIDTH*DATA_WIDTH:0]      ml_data         ;
    logic                                       ml_write        ;
                
    logic                                       root_fifo_prog_full;
    logic                                       root_fifo_empty ;
    logic                                       root_fifo_wr_en;

    logic                                       coupler_prog_full;
    logic                                       coupler_empty;
    logic                                       coupler_wr_en;

    // root fifo: it can be removed to save resources
    assign root_fifo_wr_en  =   i_ml_data_vld & ~i_phase_sel & ~root_fifo_prog_full;
    assign coupler_wr_en    =   i_ml_data_vld & i_phase_sel & ~coupler_prog_full;

    qshift_fifo #(
      .FIFO_WIDTH           ( LP_BUNDLE_WIDTH*DATA_WIDTH                ),
      .FIFO_DEPTH           ( 32                                        ),
      .PROG_FULL_THRESH     ( 32 - LP_ML_LATENCY                        )
    ) 
    u_root_fifo (
      .i_clk                ( i_clk                                     ),
      .i_din                ( i_ml_data[0+:LP_BUNDLE_WIDTH*DATA_WIDTH]  ),
      .i_wr_en              ( root_fifo_wr_en                           ),
      .i_rd_en              ( i_root_read                               ),
      .o_dout               ( o_root_data                               ),
      .o_full               ( /* Unused */                              ), 
      .o_empty              ( root_fifo_empty                           ),
      .o_prog_full          ( root_fifo_prog_full                       )
    );

    coupler #(
        .DATA_WIDTH             ( DATA_WIDTH                ),
        .BUNDLE_WIDTH           ( LP_BUNDLE_WIDTH           ),
        .FIFO_DEPTH             ( 32                        ),
        .PROG_FULL_THRESH       ( 32 - LP_CP_LATENCY        )
    )
    u_coupler (
        .i_clk                  ( i_clk                     ),

        .i_fifo_data            ( i_ml_data                 ),   // input data to the coupler: {last, data}
        .i_fifo_write           ( coupler_wr_en             ),   // write enable signal to the coupler
        .i_fifo_read            ( i_coupler_read            ),   // read enable signal to the coupler

        .o_fifo_data            ( o_coupler_data            ),   // output data from the coupler
        .o_fifo_prog_full       ( coupler_prog_full         ),   // programmable full from the coupler
        .o_fifo_empty           ( coupler_empty             )
    );

    assign o_ml_read    =   i_phase_sel ?   ~coupler_prog_full   :   ~root_fifo_prog_full;
    assign o_root_data_vld      =   !root_fifo_empty;
    assign o_coupler_data_vld   =   !coupler_empty;


endmodule