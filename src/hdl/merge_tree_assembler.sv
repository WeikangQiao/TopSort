/**********************************************************************************
 * This is the rate converter that assembles the merge tree root outputs into the 
   512-bit AIXS stream and exports them into the downstream AXI write master.
**********************************************************************************/
module merge_tree_assembler #(
   parameter integer AXIS_TDATA_WIDTH      =   512 , 
   parameter integer RECORD_DATA_WIDTH     =   32
)
(
   input    logic                            i_clk          ,

   output   logic                            m_axis_tvalid  ,
   input    logic                            m_axis_tready  ,
   output   logic [AXIS_TDATA_WIDTH-1:0]     m_axis_tdata   ,
   output   logic [AXIS_TDATA_WIDTH/8-1:0]   m_axis_tkeep   ,
   output   logic                            m_axis_tlast   ,

    
   input    logic [RECORD_DATA_WIDTH-1:0]    i_data         ,
   input    logic                            i_data_vld     ,
   output   logic                            o_read           

);

///////////////////////////////////////////////////////////////////////////////////
//Declarations
///////////////////////////////////////////////////////////////////////////////////
localparam              DIFF_DATA_WIDTH   =  AXIS_TDATA_WIDTH - RECORD_DATA_WIDTH;

// If RECORD_DATA_WIDTH is 32*16, then each 512-bit AXIS data contains 1 records
typedef enum logic[0:0] {
   FSM_IDLE = 1'd0   ,
   FSM_1    = 1'd1
} fsm_code_t;

logic                               axis_valid_st;
logic    [AXIS_TDATA_WIDTH-1:0]     axis_data_st = '0;

logic                               shift_en;

fsm_code_t  state   =   FSM_IDLE;
fsm_code_t  next_state;

///////////////////////////////////////////////////////////////////////////////////
//Main body of the code
///////////////////////////////////////////////////////////////////////////////////

// Finite state machine
always_ff @(posedge i_clk) begin: curr_state_reg
    state <= next_state;
end: curr_state_reg

always_comb begin: next_state_logic

   shift_en =  1'b0;

   case (state)
      FSM_IDLE:
         if (i_data_vld) begin
            next_state  =  FSM_1;
            shift_en    =  1'b1;
         end
         else
            next_state  =  FSM_IDLE;

      FSM_1:
         if (m_axis_tready) begin
            if (i_data_vld) begin
               next_state  =  FSM_1;
               shift_en    =  1'b1;
            end
            else
               next_state  =  FSM_IDLE;
         end
         else
            next_state  =  FSM_1;

      default: next_state  =  FSM_IDLE;

   endcase

end: next_state_logic

always_ff @(posedge i_clk) begin
   if (shift_en)
      axis_data_st   <= i_data;
end

always_comb begin: gen_output
   m_axis_tvalid  =  (state == FSM_1)  ;
   m_axis_tdata   =  axis_data_st      ;

   o_read         =  shift_en          ;
end: gen_output

endmodule