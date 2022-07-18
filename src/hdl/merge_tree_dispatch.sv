/**********************************************************************************
 *  This is the rate converter that dispatches the inputs from the 512-bit axis 
    stream and feeds them into the corresponding leaf.
 *  The rate converter acts like a fwft fifo.
 *  In the initial runs, the last signal may not always align with s_axis_tlast,
    the user needs to manually check these runs
**********************************************************************************/
module merge_tree_dispatch #(
   parameter integer AXIS_TDATA_WIDTH      =   512 , 
   parameter integer INIT_SORTED_CHUNK     =   1   ,
   parameter integer RECORD_DATA_WIDTH     =   64
)
(
   input    logic                            i_clk          ,

   input    logic                            i_init_pass    ,

   input    logic                            s_axis_tvalid  ,
  	output   logic                            s_axis_tready  ,
  	input    logic [AXIS_TDATA_WIDTH-1:0]     s_axis_tdata   ,
  	input    logic                            s_axis_tlast   ,

   input    logic                            i_read         ,  
   output   logic [RECORD_DATA_WIDTH:0]      o_data         ,
   output   logic                            o_data_vld
);

///////////////////////////////////////////////////////////////////////////////////
//Declarations
///////////////////////////////////////////////////////////////////////////////////
localparam     DIFF_DATA_WIDTH         =  AXIS_TDATA_WIDTH - RECORD_DATA_WIDTH;

// If RECORD_DATA_WIDTH is 64, then each 512-bit AXIS data contains 8 records
typedef enum logic[3:0] {
   FSM_IDLE = 4'd8   ,
   FSM_1    = 4'd0   ,
   FSM_2    = 4'd1   ,
   FSM_3    = 4'd2   ,
   FSM_4    = 4'd3   ,
   FSM_5    = 4'd4   ,
   FSM_6    = 4'd5   ,
   FSM_7    = 4'd6   ,
   FSM_8    = 4'd7   
} fsm_code_t;

logic    [AXIS_TDATA_WIDTH-1:0]     axis_data_st   =  '0;
logic    [AXIS_TDATA_WIDTH-1:0]     axis_last_st;
logic                               axis_ready_st;

logic                               axis_handshake;

logic    [RECORD_DATA_WIDTH-1:0]    dispatch_record;
logic                               last_record;

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
   case (state)

      FSM_IDLE:
         if (s_axis_tvalid)
            next_state  =  FSM_1;
         else
            next_state  =  FSM_IDLE;

      FSM_1:
         if (i_read)
            next_state  =  FSM_2;
         else
            next_state  =  FSM_1;

      FSM_2:
         if (i_read)
            next_state  =  FSM_3;
         else
            next_state  =  FSM_2;

      FSM_3:
         if (i_read)
            next_state  =  FSM_4;
         else
            next_state  =  FSM_3;

      FSM_4:
         if (i_read)
            next_state  =  FSM_5;
         else
            next_state  =  FSM_4;

      FSM_5:
         if (i_read)
            next_state  =  FSM_6;
         else
            next_state  =  FSM_5;

      FSM_6:
         if (i_read)
            next_state  =  FSM_7;
         else
            next_state  =  FSM_6;

      FSM_7:
         if (i_read)
            next_state  =  FSM_8;
         else
            next_state  =  FSM_7;

      FSM_8:
         if (i_read) begin
            if (s_axis_tvalid)
               next_state  =  FSM_1;
            else
               next_state  =  FSM_IDLE;
         end
         else
            next_state  =  FSM_8;

      default:
         next_state  =  FSM_IDLE;
   endcase
end: next_state_logic

assign   axis_handshake =  s_axis_tvalid & axis_ready_st;

always_ff @(posedge i_clk) begin: cyclic_dispach
   if (axis_handshake)
      axis_data_st   <= s_axis_tdata;  // Store the axis data
end: cyclic_dispach

always_ff @(posedge i_clk) begin
   if (axis_handshake)
      axis_last_st   <= s_axis_tlast;
end

mux_8_to_1 #(
   .RECORD_DATA_WIDTH      ( RECORD_DATA_WIDTH     )
)
u_mux(
   .i_data_0               ( axis_data_st[0*RECORD_DATA_WIDTH+:RECORD_DATA_WIDTH]   ),
   .i_data_1               ( axis_data_st[1*RECORD_DATA_WIDTH+:RECORD_DATA_WIDTH]   ),
   .i_data_2               ( axis_data_st[2*RECORD_DATA_WIDTH+:RECORD_DATA_WIDTH]   ),
   .i_data_3               ( axis_data_st[3*RECORD_DATA_WIDTH+:RECORD_DATA_WIDTH]   ),
   .i_data_4               ( axis_data_st[4*RECORD_DATA_WIDTH+:RECORD_DATA_WIDTH]   ),
   .i_data_5               ( axis_data_st[5*RECORD_DATA_WIDTH+:RECORD_DATA_WIDTH]   ),
   .i_data_6               ( axis_data_st[6*RECORD_DATA_WIDTH+:RECORD_DATA_WIDTH]   ),
   .i_data_7               ( axis_data_st[7*RECORD_DATA_WIDTH+:RECORD_DATA_WIDTH]   ),
   .i_sel                  ( state[2:0]   ),

   .o_data                 ( dispatch_record)
);

assign   axis_ready_st  =  ( (state == FSM_IDLE) & s_axis_tvalid ) |
                           ( (state == FSM_8) & i_read & s_axis_tvalid );

generate
   if (INIT_SORTED_CHUNK == 1) begin: gen_case_1
      assign   last_record =  ( (state == FSM_8) & axis_last_st ) | i_init_pass;
   end: gen_case_1
   else begin
      localparam  LOG_INIT_SORTED_CHUNK   =  $clog2(INIT_SORTED_CHUNK);
      localparam  STATE_WITH_LAST_BIT     =  INIT_SORTED_CHUNK - 1;
      assign   last_record =  ( (state == FSM_8) & axis_last_st ) | 
                              ( i_init_pass && state[0+:LOG_INIT_SORTED_CHUNK] == STATE_WITH_LAST_BIT[0+:LOG_INIT_SORTED_CHUNK] );
   end
endgenerate

always_comb begin: gen_output 
   s_axis_tready  =  axis_ready_st;
   o_data         =  {last_record, dispatch_record};
   o_data_vld     =  (state != FSM_IDLE);
end: gen_output


endmodule