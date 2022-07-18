/**********************************************************************************
 This module generates the scalar arguments,
**********************************************************************************/
module control_s_axil #
(
    parameter   S_AXI_ADDR_WIDTH  =   6
)
(
    input  logic                            i_clk       ,

    // axi4 lite slave signals
    input  logic [S_AXI_ADDR_WIDTH-1:0]     i_awaddr    ,
    input  logic                            i_awvalid   ,
    output logic                            o_awready   ,

    input  logic [32-1:0]                   i_wdata     ,
    input  logic [4-1:0]                    i_wstrb     ,
    input  logic                            i_wvalid    ,
    output logic                            o_wready    ,

    output logic [1:0]                      o_bresp     ,
    output logic                            o_bvalid    ,
    input  logic                            i_bready    ,

    input  logic [S_AXI_ADDR_WIDTH-1:0]     i_araddr    ,
    input  logic                            i_arvalid   ,
    output logic                            o_arready   ,

    output logic [32-1:0]                   o_rdata     ,
    output logic [1:0]                      o_rresp     ,
    output logic                            o_rvalid    ,
    input  logic                            i_rready    ,

    // user signals
    output logic                            o_interrupt ,

    output logic                            o_ap_start  ,
    input  logic                            i_ap_done   ,
    input  logic                            i_ap_ready  ,
    input  logic                            i_ap_idle   ,
    
    output logic [63:0]                     o_size      ,
    output logic [7:0]                      o_num_pass  ,
    output logic [63:0]                     o_ptr_0
);

//------------------------Address Info-------------------
// 0x00 : Control signals
//        bit 0  - ap_start (Read/Write/COH)
//        bit 1  - ap_done (Read/COR)
//        bit 2  - ap_idle (Read)
//        bit 3  - ap_ready (Read)
//        bit 7  - auto_restart (Read/Write)
//        others - reserved
// 0x04 : Global Interrupt Enable Register
//        bit 0  - Global Interrupt Enable (Read/Write)
//        others - reserved
// 0x08 : IP Interrupt Enable Register (Read/Write)
//        bit 0  - Channel 0 (ap_done)
//        bit 1  - Channel 1 (ap_ready)
//        others - reserved
// 0x0c : IP Interrupt Status Register (Read/TOW)
//        bit 0  - Channel 0 (ap_done)
//        bit 1  - Channel 1 (ap_ready)
//        others - reserved
// 0x010 : Data signal of size
//         bit 31~0 - size[31:0] (Read/Write)
// 0x014 : Data signal of size
//         bit 31~0 - size[63:32] (Read/Write)
// 0x018 : Data signal of num_pass
//         bit 07~0 - num_pass[7:0] (Read/Write)
// 0x1c  : Data signal of ptr_0
//         bit 31~0 - ptr_0[31:0] (Read/Write)
// 0x20 :  Data signal of ptr_0
//         bit 31~0 - ptr_0[63:32] (Read/Write)
// (SC = Self Clear, COR = Clear on Read, TOW = Toggle on Write, COH = Clear on Handshake)

///////////////////////////////////////////////////////////////////////////////////
//Declarations
///////////////////////////////////////////////////////////////////////////////////
//------------------------Parameter----------------------
//Address code for control registers
localparam
    ADDR_AP_CTRL            =   9'h000  ,
    ADDR_GIE                =   9'h004  ,
    ADDR_IER                =   9'h008  ,
    ADDR_ISR                =   9'h00c  ,
    ADDR_SIZE_0             =   9'h010  ,
    ADDR_SIZE_1             =   9'h014  ,
    ADDR_NUM_PASS           =   9'h018  ,
    ADDR_PTR_0_0            =   9'h01c  ,
    ADDR_PTR_0_1            =   9'h020  ;

//FSM code for write
localparam
    WRIDLE                  =   2'd0    ,
    WRDATA                  =   2'd1    ,
    WRRESP                  =   2'd2    ;
//FSM code for read
localparam
    RDIDLE                  =   2'd0    ,
    RDDATA                  =   2'd1    ;

localparam
    ADDR_BITS               =   9       ;

//------------------------Local signal-------------------
    logic                         aw_hs;

    logic  [1:0]                  w_curr_state  =   WRIDLE;
    logic  [1:0]                  w_next_state;
    logic  [ADDR_BITS-1:0]        w_addr = 'b0;
    logic  [31:0]                 w_mask;
    logic                         w_hs;
    
    logic                         ar_hs;

    logic  [1:0]                  r_curr_state  =   RDIDLE;
    logic  [1:0]                  r_next_state;
    logic [ADDR_BITS-1:0]         r_addr;
    logic  [31:0]                 r_data;
    logic                         r_hs;
    
    // internal registers
    logic                         int_ap_idle;
    logic                         int_ap_ready;
    logic                         int_ap_done       = 'b0;
    logic                         int_ap_start      = 'b0;
    logic                         int_auto_restart  = 'b0;
    logic                         int_gie           = 'b0;
    logic  [1:0]                  int_ier           = '0 ;
    logic  [1:0]                  int_isr           = '0 ;
    logic  [63:0]                 int_size          = '0 ;
    logic  [7:0]                  int_num_pass      = '0 ;
    logic  [63:0]                 int_ptr_0         = '0 ;


///////////////////////////////////////////////////////////////////////////////////
//Main body of the code
///////////////////////////////////////////////////////////////////////////////////

//------------------------AXI Lite AWRITE & WRITE------------------
// Assign output
assign o_awready    =   (w_curr_state == WRIDLE);
assign o_wready     =   (w_curr_state == WRDATA);
assign o_bresp      =   2'b00;
assign o_bvalid     =   (w_curr_state == WRRESP);

assign aw_hs        =   i_awvalid & o_awready;
assign w_hs         =   i_wvalid & o_wready;
assign w_mask       =   { {8{i_wstrb[3]}}, {8{i_wstrb[2]}}, {8{i_wstrb[1]}}, {8{i_wstrb[0]}} };

// w_curr_state
always @(posedge i_clk) begin
    w_curr_state <= w_next_state;
end

// w_next_state
always @(*) begin
    case (w_curr_state)
        WRIDLE:
            if (i_awvalid)
                w_next_state = WRDATA;
            else
                w_next_state = WRIDLE;
        WRDATA:
            if (i_wvalid)
                w_next_state = WRRESP;
            else
                w_next_state = WRDATA;
        WRRESP:
            if (i_bready)
                w_next_state = WRIDLE;
            else
                w_next_state = WRRESP;
        default:
            w_next_state = WRIDLE;
    endcase
end

// Extract waddr
always_ff @(posedge i_clk) begin
    if (aw_hs)
        w_addr <= i_awaddr[ADDR_BITS-1:0];
end

//------------------------AXI Lite ARREAD & READ------------------
// Assign output
assign o_arready    =   (r_curr_state == RDIDLE);
assign o_rdata      =   r_data;
assign o_rresp      =   2'b00;
assign o_rvalid     =   (r_curr_state == RDDATA);

assign ar_hs        =   i_arvalid & o_arready;
assign r_hs         =   i_rready & o_rvalid;
assign r_addr       =   i_araddr[ADDR_BITS-1:0];

// r_curr_state
always_ff @(posedge i_clk) begin
    r_curr_state <= r_next_state;
end

// r_next_state
always @(*) begin
    case (r_curr_state)
        RDIDLE:
            if (i_arvalid)
                r_next_state = RDDATA;
            else 
                r_next_state = RDIDLE;
        RDDATA:
            if (r_hs)
                r_next_state = RDIDLE;
            else
                r_next_state = RDDATA;
        default:
            r_next_state = RDIDLE;
    endcase
end

// r_data
always_ff @(posedge i_clk) begin
    r_data <= 'b0;
    if (ar_hs) begin
        case (r_addr)
            ADDR_AP_CTRL: begin
                r_data[0]   <= int_ap_start;
                r_data[1]   <= int_ap_done;
                r_data[2]   <= int_ap_idle;
                r_data[3]   <= int_ap_ready;
                r_data[7]   <= int_auto_restart;
            end
            ADDR_GIE: begin
                r_data <= int_gie;
            end
            ADDR_IER: begin
                r_data <= int_ier;
            end
            ADDR_ISR: begin
                r_data <= int_isr;
            end
            ADDR_SIZE_0: begin
                r_data <= int_size[0+:32];
            end
            ADDR_SIZE_1: begin
                r_data <= int_size[32+:32];
            end
            ADDR_NUM_PASS: begin
                r_data <= {24'b0, int_num_pass[0+:8]};
            end
            ADDR_PTR_0_0: begin
                r_data <= int_ptr_0[31:0];
            end
            ADDR_PTR_0_1: begin
                r_data <= int_ptr_0[63:32];
            end

            /*
            We omit other pointers as current XDMA flow doesn't support host-side reads.
            */

            default: begin
                r_data <= '0;
            end
        endcase
    end
end

//------------------------Register logic for read-----------------
assign int_ap_idle  = i_ap_idle;
assign int_ap_ready = i_ap_ready;

// int_ap_done
always_ff @(posedge i_clk) begin
    if (i_ap_done)
        int_ap_done <= 1'b1;
    else if (ar_hs && r_addr == ADDR_AP_CTRL)
        int_ap_done <= 1'b0;    // Clear on read
end

//------------------------Register logic for write-----------------
// int_ap_start
always_ff @(posedge i_clk) begin
    if (w_hs && w_addr == ADDR_AP_CTRL && i_wstrb[0] && i_wdata[0])
        int_ap_start <= 1'b1;
    else if (int_ap_ready)
        int_ap_start <= int_auto_restart; // Clear on handshake/auto restart
end

// int_auto_restart
always_ff @(posedge i_clk ) begin
    if (w_hs && w_addr == ADDR_AP_CTRL && i_wstrb[0])
        int_auto_restart <= i_wdata[7];
end

// int_gie
always_ff @(posedge i_clk ) begin
    if (w_hs && w_addr == ADDR_GIE && i_wstrb[0])
        int_gie <= i_wdata[0];
end

// int_ier
always_ff @(posedge i_clk ) begin
    if (w_hs && w_addr == ADDR_IER && i_wstrb[0])
        int_ier <= i_wdata[1:0];
end

// int_isr[0]
always_ff @(posedge i_clk ) begin
    if (int_ier[0] & i_ap_done)
        int_isr[0] <= 1'b1;
    else if (w_hs && w_addr == ADDR_ISR && i_wstrb[0])
        int_isr[0] <= int_isr[0] ^ i_wdata[0];  // Toggle on write
end

// int_isr[1]
always_ff @(posedge i_clk ) begin
    if (int_ier[1] & i_ap_ready)
        int_isr[1] <= 1'b1;
    else if (w_hs && w_addr == ADDR_ISR && i_wstrb[0])
        int_isr[1] <= int_isr[1] ^ i_wdata[1];  // Toggle on write
end

// int_size[32-1:0]
always @(posedge i_clk) begin
    if (w_hs && w_addr == ADDR_SIZE_0)
        int_size[0+:32] <= (i_wdata[0+:32] & w_mask) | (int_size[0+:32] & ~w_mask);
end

// int_size[32-1:0]
always @(posedge i_clk) begin
    if (w_hs && w_addr == ADDR_SIZE_1)
        int_size[32+:32] <= (i_wdata[0+:32] & w_mask) | (int_size[32+:32] & ~w_mask);
end

// int_num_pass[7:0]
always_ff @(posedge i_clk) begin
    if (w_hs && w_addr == ADDR_NUM_PASS)
        int_num_pass[0+:8] <=  (i_wdata[0+:8] & w_mask[0+:8]) | (int_num_pass[0+:8] & ~w_mask[0+:8]);
end

// int_ptr_0[31:0]
always_ff @(posedge i_clk) begin
    if (w_hs && w_addr == ADDR_PTR_0_0)
        int_ptr_0[0+:32] <=  (i_wdata[0+:32] & w_mask) | (int_ptr_0[0+:32] & ~w_mask);
end

// int_ptr_0[63:32]
always_ff @(posedge i_clk) begin
    if (w_hs && w_addr == ADDR_PTR_0_1)
        int_ptr_0[32+:32] <=  (i_wdata[0+:32] & w_mask) | (int_ptr_0[32+:32] & ~w_mask);
end


// User output
always_comb begin : gen_usr_output
    o_interrupt     = int_gie & (|int_isr)  ;
    o_ap_start      = int_ap_start          ;
    o_size          = int_size              ;
    o_num_pass      = int_num_pass          ;
    o_ptr_0         = int_ptr_0             ;
end: gen_usr_output

endmodule