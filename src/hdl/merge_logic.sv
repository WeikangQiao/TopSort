/**********************************************************************************
 * This is the E-record merge logic: it reads data from two input fifos and writes
   data to the output fifos (coupler or write burst buffer).
 * It contains a E-record merge network and a selector logic to select the right 
   input to the merge network.
 * There should be at least 1 cycle bubble between two continuous streams to allow
   for the last bundle to be output
**********************************************************************************/
module merge_logic #(
    parameter integer  DATA_WIDTH   = 32,
    parameter integer  KEY_WIDTH    = 32,
    parameter integer  BUNDLE_WIDTH = 8
)
(
    input  logic                                    i_clk               ,

    input  logic [DATA_WIDTH*BUNDLE_WIDTH:0]        i_fifo_data_0       ,   // {last, data} from input fifo 0
    input  logic                                    i_fifo_data_0_vld   ,   // valid signal for data from input fifo 0
    input  logic [DATA_WIDTH*BUNDLE_WIDTH:0]        i_fifo_data_1       ,   // {last, data} from input fifo 1
    input  logic                                    i_fifo_data_1_vld   ,   // valid signal for data from input fifo 1
    input  logic                                    i_fifo_full         ,   // programmable full from output fifo

    output logic                                    o_fifo_0_read       ,   // enable signal for reading input fifo 0
    output logic                                    o_fifo_1_read       ,   // enable signal for reading input fifo 1
    output logic [DATA_WIDTH*BUNDLE_WIDTH:0]        o_fifo_data         ,   // output data
    output logic                                    o_fifo_write            // enable signal for writing output fifo
);

///////////////////////////////////////////////////////////////////////////////////
//Declarations
///////////////////////////////////////////////////////////////////////////////////
localparam VALUE_WIDTH = DATA_WIDTH - KEY_WIDTH;

typedef enum logic[2:0] {
    FSM_IDLE        =   3'b000, // Idle state
    FSM_MERGE       =   3'b001, // State for merging both input streams
    FSM_PASS_L      =   3'b010, // State for passing left stream: this happens when right stream reaches the end
    FSM_PASS_R      =   3'b011, // State for passing right stream: this happens when left stream reaches the end
    FSM_POP_LAST    =   3'b100  // State to allow the last bundle of the merge network to be output
} fsm_code_t;

typedef struct {
    logic                                   last;   
    logic   [DATA_WIDTH*BUNDLE_WIDTH-1:0]   data;
} data_lt;

fsm_code_t  state   =   FSM_IDLE;
fsm_code_t  next_state;

data_lt     in_data_0;      // Convert i_fifo_data_0 into local data type
data_lt     in_data_1;      // Convert i_fifo_data_1 into local data type

logic       key_comp;       // asserted if i_bundle_0 is less or equal than i_bunble_1

data_lt     mn_data_in;     // {data, last} input into the merge network
logic       mn_data_valid;  // valid signal into the merge network
logic       mn_data_sel;    // select signal into the merge network
logic       fifo_0_read;    // read signal into input fifo 0
logic       fifo_1_read;    // read signal into input fifo 1

data_lt     out_bundle;
logic       out_valid;

///////////////////////////////////////////////////////////////////////////////////
//Main body of the code
///////////////////////////////////////////////////////////////////////////////////

// Convert input data
always_comb begin: input_conv
    in_data_0.last  =  i_fifo_data_0[DATA_WIDTH*BUNDLE_WIDTH]       ;
    in_data_0.data  =  i_fifo_data_0[0+:DATA_WIDTH*BUNDLE_WIDTH]    ;
    in_data_1.last  =  i_fifo_data_1[DATA_WIDTH*BUNDLE_WIDTH]       ;
    in_data_1.data  =  i_fifo_data_1[0+:DATA_WIDTH*BUNDLE_WIDTH]    ;
end: input_conv

// Currently only compare the key
// For satellite data, we may need to compare the whole data
assign key_comp = in_data_0.data[VALUE_WIDTH +: KEY_WIDTH] <= in_data_1.data[VALUE_WIDTH +: KEY_WIDTH];

// Finite state machine
always_ff @(posedge i_clk) begin: curr_state_reg
    state <= next_state;
end: curr_state_reg

always_comb begin: next_state_logic
    next_state      =   state           ; // default is to stay in the current state

    mn_data_in.data =   in_data_0.data  ;
    mn_data_in.last =   1'b0            ;
    mn_data_valid   =   1'b0            ;
    mn_data_sel     =   1'b0            ;
    fifo_0_read     =   1'b0            ; 
    fifo_1_read     =   1'b0            ;      

    case (state)
        FSM_IDLE:
            if (~i_fifo_full & i_fifo_data_0_vld & i_fifo_data_1_vld) begin
                mn_data_valid   =   1'b1;
                if (key_comp) begin
                    mn_data_in.data =   in_data_0.data;
                    mn_data_sel     =   1'b0;
                    fifo_0_read     =   1'b1;
                    if (in_data_0.last)
                        next_state  =   FSM_PASS_R; //This special case is for initial sorted chunk size of 1
                    else
                        next_state  =   FSM_MERGE;
                end else begin
                    mn_data_in.data =   in_data_1.data;
                    mn_data_sel     =   1'b1;
                    fifo_1_read     =   1'b1;
                    if (in_data_1.last)
                        next_state  =   FSM_PASS_L; //This special case is for initial sorted chunk size of 1
                    else
                        next_state  =   FSM_MERGE;
                end
            end else
                next_state  =   FSM_IDLE;
        
        FSM_MERGE:
            if (~i_fifo_full & i_fifo_data_0_vld & i_fifo_data_1_vld) begin
                mn_data_in.last     =   1'b0;
                mn_data_valid       =   1'b1;
                if (key_comp) begin
                    mn_data_in.data =   in_data_0.data;
                    mn_data_sel     =   1'b0;
                    fifo_0_read     =   1'b1;
                    if (in_data_0.last) begin
                        next_state  =   FSM_PASS_R;
                    end else begin
                        next_state  =   FSM_MERGE;
                    end
                end else begin
                    mn_data_in.data =   in_data_1.data;
                    mn_data_sel     =   1'b1;
                    fifo_1_read     =   1'b1;
                    if (in_data_1.last) begin
                        next_state  =   FSM_PASS_L;                        
                    end else begin
                        next_state  =   FSM_MERGE;
                    end
                end
            end else
                next_state  =   FSM_MERGE;

        FSM_PASS_L: begin
            mn_data_in.data =   in_data_0.data;
            mn_data_sel     =   1'b0;
            if (~i_fifo_full & i_fifo_data_0_vld) begin
                mn_data_valid   =   1'b1;
                fifo_0_read     =   1'b1;
                if (in_data_0.last) begin
                    mn_data_in.last =   1'b1;
                    next_state      =   FSM_POP_LAST;
                end else begin
                    next_state      =   FSM_PASS_L;
                end
            end else
                next_state = FSM_PASS_L;
        end

        FSM_PASS_R: begin
            mn_data_in.data =   in_data_1.data;
            mn_data_sel     =   1'b1;
            if (~i_fifo_full & i_fifo_data_1_vld) begin
                mn_data_valid   =   1'b1;
                fifo_1_read     =   1'b1;
                if (in_data_1.last) begin
                    mn_data_in.last =   1'b1;
                    next_state      =   FSM_POP_LAST;
                end else begin
                    next_state      =   FSM_PASS_R;
                end
            end else 
                next_state  =   FSM_PASS_R;  
        end

        FSM_POP_LAST: begin
            next_state  =   FSM_IDLE;
        end   

        default:   next_state   =   FSM_IDLE;        
    endcase
end: next_state_logic

merge_network #(
    .DATA_WIDTH         ( DATA_WIDTH            ),
    .KEY_WIDTH          ( KEY_WIDTH             ),
    .BUNDLE_WIDTH       ( BUNDLE_WIDTH          )
)
u_merge_network(
    .i_clk              ( i_clk                 ),
    
    .i_bundle           ( mn_data_in.data       ),
    .i_bundle_v         ( mn_data_valid         ),
    .i_bundle_sel       ( mn_data_sel           ),  // 0: select i_bundle_0; 1: select i_bundle_1
    .i_bundle_last      ( mn_data_in.last       ),  // indicate it is the last input bundle for the current run
    
    .o_bundle           ( out_bundle.data       ),  //
    .o_bundle_v         ( out_valid             ),  //
    .o_bundle_last      ( out_bundle.last       )   // indicate it is the last output bundle for the current run
);

always_comb begin : gen_output
    o_fifo_0_read                               =   fifo_0_read;
    o_fifo_1_read                               =   fifo_1_read;
    o_fifo_data[0+:DATA_WIDTH*BUNDLE_WIDTH]     =   out_bundle.data;
    o_fifo_data[DATA_WIDTH*BUNDLE_WIDTH]        =   out_bundle.last;
    o_fifo_write                                =   out_valid;
end: gen_output

endmodule