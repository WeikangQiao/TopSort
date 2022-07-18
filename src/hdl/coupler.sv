/**********************************************************************************
 This module takes the input records, couples them into wider records at a ratio 
 of 2:1 and store them into the fifos
**********************************************************************************/
module coupler #(
    parameter integer  DATA_WIDTH       =   32,
    parameter integer  BUNDLE_WIDTH     =   8 ,
    parameter integer  FIFO_DEPTH       =   32,
    parameter integer  PROG_FULL_THRESH =   32
)
(
    input  logic                                    i_clk               ,

    input  logic [DATA_WIDTH*BUNDLE_WIDTH:0]        i_fifo_data         ,   // input data to the fifo: {last, data}
    input  logic                                    i_fifo_write        ,   // write enable signal to the fifo
    input  logic                                    i_fifo_read         ,   // read enable signal to the fifo

    output logic [2*DATA_WIDTH*BUNDLE_WIDTH:0]      o_fifo_data         ,   // output data from the fifo
    output logic                                    o_fifo_prog_full    ,   // programmable full from the fifo
    output logic                                    o_fifo_empty        
);

///////////////////////////////////////////////////////////////////////////////////
//Declarations
///////////////////////////////////////////////////////////////////////////////////
typedef struct {
    logic                                   last;   
    logic   [DATA_WIDTH*BUNDLE_WIDTH-1:0]   data;
} data_lt;

typedef struct {
    logic                                   last;   
    logic   [2*DATA_WIDTH*BUNDLE_WIDTH-1:0] data;
} data2_lt;

typedef enum logic[1:0] {
    FSM_IDLE    = 2'b00,    // Idle state
    FSM_ODD     = 2'b01,    // State that odd number of input comes in, temporarily hold it
    FSM_EVEN    = 2'b10     // State that even number of input comes in, push them into the FIFO
} fsm_code_lt;

data_lt         in_data             ;   // input data

data_lt         first_data  =   '{default:'0}   ;   // first data is the least significant half
data_lt         second_data =   '{default:'0}   ;   // second data is the most significant half

fsm_code_lt     state   =   FSM_IDLE;
fsm_code_lt     next_state  ;

logic   [2*DATA_WIDTH*BUNDLE_WIDTH:0]   fifo_in     ;   // Data to be written to the fifo
logic                                   fifo_write  ;   // Write enable signal to the fifo

///////////////////////////////////////////////////////////////////////////////////
//Main body of the code
///////////////////////////////////////////////////////////////////////////////////

// Convert input data
always_comb begin: input_conv
    in_data.last    =  i_fifo_data[DATA_WIDTH*BUNDLE_WIDTH]       ;
    in_data.data    =  i_fifo_data[0+:DATA_WIDTH*BUNDLE_WIDTH]    ;
end: input_conv

// Update the stored first & second data registers
always_ff @(posedge i_clk) begin : store_data
    if (i_fifo_write) begin
        second_data <=  in_data     ;
        first_data  <=  second_data ;
    end
end: store_data

// Finite state machine
always_ff @(posedge i_clk) begin: curr_state_reg
    state <= next_state;
end: curr_state_reg

always_comb begin: next_state_logic
    case (state)
        FSM_IDLE: 
            if (i_fifo_write)
                next_state  =   FSM_ODD;
            else
                next_state  =   FSM_IDLE;
        
        FSM_ODD:
            if (i_fifo_write)
                next_state  =   FSM_EVEN;
            else
                next_state  =   FSM_ODD;

        FSM_EVEN:
            if (i_fifo_write)
                next_state  =   FSM_ODD;
            else
                next_state  =   FSM_IDLE;

        default:
            next_state  =   FSM_IDLE;
    endcase
end: next_state_logic

assign  fifo_in     =   {second_data.last, second_data.data, first_data.data};
assign  fifo_write  =   state == FSM_EVEN;

qshift_fifo #(
  .FIFO_WIDTH           ( 2*DATA_WIDTH*BUNDLE_WIDTH+1   ),
  .FIFO_DEPTH           ( FIFO_DEPTH                    ),
  .PROG_FULL_THRESH     ( PROG_FULL_THRESH              )
) 
u_fifo (
  .i_clk                ( i_clk                         ),
  .i_din                ( fifo_in                       ),
  .i_wr_en              ( fifo_write                    ),
  .i_rd_en              ( i_fifo_read                   ),
  .o_dout               ( o_fifo_data                   ),
  .o_full               ( /* Unused */                  ), 
  .o_empty              ( o_fifo_empty                  ),
  .o_prog_full          ( o_fifo_prog_full              )
);

endmodule