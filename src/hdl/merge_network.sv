`include "macro_def.sv"
/**********************************************************************************
 *  When the input bundle is the last one, the i_bundle_last should be asserted.
 *  If BUNDLE_WIDTH >= 2, the latency of the module is 2 + 2 * BM_LATENCY;
    otherwise, the latency of the module is 1.
**********************************************************************************/

module merge_network #(
    parameter integer  DATA_WIDTH   = 32,
    parameter integer  KEY_WIDTH    = 32,
    parameter integer  BUNDLE_WIDTH = 8
)
(
    input  logic                                    i_clk           ,

    input  logic [DATA_WIDTH*BUNDLE_WIDTH-1:0]      i_bundle        ,
    input  logic                                    i_bundle_v      ,
    input  logic                                    i_bundle_sel    , // 0: select i_bundle_0; 1: select i_bundle_1
    input  logic                                    i_bundle_last   , // indicate it is the last input bundle for the current run

    output logic [DATA_WIDTH*BUNDLE_WIDTH-1:0]      o_bundle        ,
    output logic                                    o_bundle_v      ,
    output logic                                    o_bundle_last     // indicate it is the last output bundle for the current run
);

generate
    if (BUNDLE_WIDTH == 1) begin: direct_connect

        logic [DATA_WIDTH*BUNDLE_WIDTH-1:0] i_bundle_reg = '0;
        logic i_bundle_v_reg = 0;
        logic i_bundle_last_reg = 0;

        always_ff @(posedge i_clk) begin
            i_bundle_reg        <=  i_bundle;
            i_bundle_v_reg      <=  i_bundle_v;
            i_bundle_last_reg   <=  i_bundle_last;
        end

        always_comb begin
            o_bundle        =   i_bundle_reg        ;
            o_bundle_v      =   i_bundle_v_reg      ;
            o_bundle_last   =   i_bundle_last_reg   ;
        end

    end: direct_connect

    else begin : use_network
        ///////////////////////////////////////////////////////////////////////////////////
        //Declarations
        ///////////////////////////////////////////////////////////////////////////////////
        localparam BM_LATENCY = `LOG2(BUNDLE_WIDTH) + 1; // this is the number of latency for a single bitonic merger (BM)

        // Stage 1: assume all inputs are not registered, then register all inputs
        (* srl_style = "register" *) logic [DATA_WIDTH*BUNDLE_WIDTH-1:0] i_bundle_reg = 0;
        logic i_bundle_v_reg = 0;
        logic i_bundle_sel_reg = 0;
        logic i_bundle_last_reg = 0;

        // Stage 2: Generate RA, RB, srg_in
        (* srl_style = "register" *) logic [DATA_WIDTH*BUNDLE_WIDTH-1:0] RA = '0;
        (* srl_style = "register" *) logic [DATA_WIDTH*BUNDLE_WIDTH-1:0] RB = '0;
        (* srl_style = "register" *) logic [DATA_WIDTH*BUNDLE_WIDTH-1:0] srg_in = '0;  // srg_in is 1 cycle ahead of RA & RB, so SRG has BM_LATENCY-1 cycle latency
        logic i_bundle_v_bml = 0;    // this signal flows with RA & RB into BML

        // SRG
        logic [DATA_WIDTH*BUNDLE_WIDTH-1:0] srg_out;
        logic                               bundle_last_srg; // this signal flows with srg_out into BMS
    
        logic [DATA_WIDTH*BUNDLE_WIDTH-1:0] bml_out;
        logic                               i_bundle_v_bms;
        logic                               o_bundle_v_tmp; // o_bundle_v_tmp has 1 more cycle than o_bundle_v

        logic                               o_bundle_first_ahead; // ahead 1 cycle
        logic                               o_bundle_v_env = 0;     //envelope

        ///////////////////////////////////////////////////////////////////////////////////
        //Main body of the code
        ///////////////////////////////////////////////////////////////////////////////////

        // Stage 1: register inputs
        always_ff @(posedge i_clk) begin
            i_bundle_reg        <=  i_bundle;
            i_bundle_v_reg      <=  i_bundle_v;
            i_bundle_sel_reg    <=  i_bundle_sel;
            i_bundle_last_reg   <=  i_bundle_last;
        end

        // Stage 2: select which bundle to be stored into SRG and registers
        always_ff @(posedge i_clk) begin
            if (i_bundle_v_reg)
                srg_in <= i_bundle_reg;
        end

        always_ff @(posedge i_clk) begin
            if (i_bundle_last_reg) begin
                RA <= 0;
                RB <= 0;
            end
            else if (i_bundle_v_reg) begin
                if (i_bundle_sel_reg)   // select bundle_1
                    RB <= i_bundle_reg;
                else
                    RA <= i_bundle_reg;
            end 
        end

        always_ff @(posedge i_clk) begin
            i_bundle_v_bml <= i_bundle_v_reg;
        end

        // SRG module
        shift_reg #(
            .DATA_WIDTH ( DATA_WIDTH*BUNDLE_WIDTH   ),
            .SRL_DEPTH  ( BM_LATENCY-1              )
        )
        SRG (
            .i_clk      ( i_clk                     ),
            .i_data     ( srg_in                    ),
            .o_data     ( srg_out                   )
        );

        shift_reg #(
            .DATA_WIDTH ( 1                         ),
            .SRL_DEPTH  ( BM_LATENCY                )
        )
        last_srg_uut (
            .i_clk      ( i_clk                     ),
            .i_data     ( i_bundle_last_reg         ),
            .o_data     ( bundle_last_srg           )
        );

        // BML module
        bitonic_merger_l #(
            .DATA_WIDTH(DATA_WIDTH),
            .KEY_WIDTH(KEY_WIDTH), 
            .BUNDLE_WIDTH(BUNDLE_WIDTH)
        ) 
        BML (
            .i_clk(i_clk),
            .i_valid(i_bundle_v_bml),
            .i_bundle_0(RA),
            .i_bundle_1(RB),
            .o_bundle(bml_out),
            .o_valid()
        );

        // BMS module
        shift_reg #(
            .DATA_WIDTH ( 1                         ),
            .SRL_DEPTH  ( BM_LATENCY                )
        )
        bms_bundle_valid (
            .i_clk  ( i_clk                         ),
            .i_data ( i_bundle_v_reg                ),
            .o_data ( i_bundle_v_bms                )
        );

        bitonic_merger_s #(
            .DATA_WIDTH(DATA_WIDTH),
            .KEY_WIDTH(KEY_WIDTH), 
            .BUNDLE_WIDTH(BUNDLE_WIDTH)
        ) 
        BMS (
            .i_clk(i_clk),
            .i_valid(i_bundle_v_bms),
            .i_bundle_0(srg_out),
            .i_bundle_1(bml_out),
            .i_last(bundle_last_srg),
            .o_bundle(o_bundle),
            .o_valid(o_bundle_v_tmp)
        );    

        // o_bundle_first
        shift_reg #(
            .DATA_WIDTH ( 1                         ),
            .SRL_DEPTH  (2*BM_LATENCY               )
        )
        o_first_srg_uut (
            .i_clk  ( i_clk                         ),
            .i_data ( i_bundle_v_reg                ),
            .o_data ( o_bundle_first_ahead          )
        );

        // o_bundle_last
        shift_reg #(
            .DATA_WIDTH ( 1                         ),
            .SRL_DEPTH  ( BM_LATENCY+1              )
        )
        o_last_srg_uut (
            .i_clk      ( i_clk                     ),
            .i_data     ( bundle_last_srg           ),
            .o_data     ( o_bundle_last             )
        );

        // calculate o_bundle_v
        always @(posedge i_clk) begin
            if (o_bundle_first_ahead)
                o_bundle_v_env <= 1;
            else if (o_bundle_last)
                o_bundle_v_env <= 0;
        end

        assign o_bundle_v = o_bundle_v_env & o_bundle_v_tmp;
    end : use_network

endgenerate

endmodule





