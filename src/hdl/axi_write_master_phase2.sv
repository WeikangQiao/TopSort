module axi_write_master_phase2 #(
  // Set to the address width of the interface
  parameter integer C_M_AXI_ADDR_WIDTH  = 64,
  // Set the data width of the interface
  parameter integer C_M_AXI_DATA_WIDTH  = 512,
  // Set the data width of the axis interface
  parameter integer C_M_AXIS_DATA_WIDTH  = 2048,
  // Set the id width of the interface
  parameter integer C_M_AXI_ID_WIDTH  = 16, 
  // Width of the ctrl_xfer_size_in_bytes input
  parameter integer C_XFER_SIZE_WIDTH   = 32,
  // Specifies the maximum number of AXI4 transactions that may be outstanding.
  parameter integer C_MAX_OUTSTANDING   = 32
)
(
  // AXI Interface
  input  logic                                    aclk                    ,

  // Control signals
  input  logic                                    ctrl_start              , // Pulse high for one cycle to begin reading
  output logic                                    ctrl_done               , // Pulses high for one cycle when transfer request is complete
  // The following ctrl signals are sampled when ctrl_start is asserted
  input  logic [C_M_AXI_ADDR_WIDTH-1:0]           ctrl_addr_offset        , // Starting Address offset
  input  logic [C_XFER_SIZE_WIDTH-1:0]            ctrl_xfer_size_in_bytes , // Length in number of bytes, limited by the address width.

  // AXI4 master interface (write only)
  axi_bus_wr_t.master                             m_axi                   ,

  // AXI4-Stream interface
  input  logic                                    s_axis_tvalid           ,
  output logic                                    s_axis_tready           ,
  input  logic  [C_M_AXIS_DATA_WIDTH-1:0]         s_axis_tdata
);

timeunit 1ps;
timeprecision 1ps;

///////////////////////////////////////////////////////////////////////////////
// functions
///////////////////////////////////////////////////////////////////////////////
function integer f_min (
  input integer a,
  input integer b
);
  f_min = (a < b) ? a : b;
endfunction

/////////////////////////////////////////////////////////////////////////////
// Local Parameters
/////////////////////////////////////////////////////////////////////////////
localparam integer LP_DW_BYTES                   = C_M_AXI_DATA_WIDTH/8;
localparam integer LP_LOG_DW_BYTES               = $clog2(LP_DW_BYTES);
localparam integer LP_MAX_BURST_LENGTH           = 256;   // Max AXI Protocol burst length
localparam integer LP_MAX_BURST_BYTES            = 4096;  // Max AXI Protocol burst size in bytes
localparam integer LP_AXI_BURST_LEN              = f_min(LP_MAX_BURST_BYTES/LP_DW_BYTES, LP_MAX_BURST_LENGTH);
localparam integer LP_LOG_BURST_LEN              = $clog2(LP_AXI_BURST_LEN);
localparam integer LP_LOG_MAX_W_TO_AW            = 8; // Allow up to 256 outstanding w to aw transactions
localparam integer LP_TOTAL_LEN_WIDTH            = C_XFER_SIZE_WIDTH-LP_LOG_DW_BYTES;
localparam integer LP_TRANSACTION_CNTR_WIDTH     = LP_TOTAL_LEN_WIDTH-LP_LOG_BURST_LEN;
localparam [C_M_AXI_ADDR_WIDTH-1:0] LP_ADDR_MASK = LP_DW_BYTES*LP_AXI_BURST_LEN - 1;
localparam integer LP_FIFO_DEPTH                 = 512;
localparam integer LP_FIFO_READ_LATENCY          = 0; // In fwft mode, the only applicable value is 0
localparam integer LP_FIFO_COUNT_WIDTH           = $clog2(LP_FIFO_DEPTH)+1;
localparam integer LP_OUTSTANDING_CNTR_WIDTH     = $clog2(C_MAX_OUTSTANDING+1);

/////////////////////////////////////////////////////////////////////////////
// Variables
/////////////////////////////////////////////////////////////////////////////
// Control
logic                                 done = 1'b0;
logic                                 has_partial_bursts;
logic                                 ctrl_start_d1 = 1'b0;
logic [C_M_AXI_ADDR_WIDTH-1:0]        addr_offset_r;
logic [LP_TOTAL_LEN_WIDTH-1:0]        total_len_r;
logic [LP_LOG_DW_BYTES   -1:0]        byte_remainder_r;
logic [LP_DW_BYTES   -1:0]            final_strb;
logic                                 start    = 1'b0;
logic                                 start_d1 = 1'b0;
logic [LP_TRANSACTION_CNTR_WIDTH-1:0] num_transactions;
logic [LP_LOG_BURST_LEN-1:0]          final_burst_len;
logic                                 single_transaction;
// FIFO read out data
logic [C_M_AXIS_DATA_WIDTH-1:0]       fifo_out_data;
logic                                 fifo_out_vld;
logic                                 fifo_rd;     
// Write data channel
logic                                 s_axis_tready_n;
logic [1:0]                           w_sel = '0;
logic                                 wxfer;       // Unregistered write data transfer
logic                                 wfirst = 1'b1;
logic                                 load_burst_cntr;
logic [LP_LOG_BURST_LEN-1:0]          wxfers_to_go;  // Used for simulation debug
logic [LP_TRANSACTION_CNTR_WIDTH-1:0] w_transactions_to_go;
logic                                 w_final_transaction;
logic                                 w_final_transfer;
logic                                 w_almost_final_transaction = 1'b0;
logic                                 w_running = 1'b0;
// Write address channel
logic                                 awxfer;
logic                                 awvalid_r    = 1'b0;
logic [C_M_AXI_ADDR_WIDTH-1:0]        addr;
logic                                 wfirst_d1    = 1'b0;
logic                                 wfirst_pulse = 1'b0;
logic [LP_LOG_MAX_W_TO_AW-1:0]        dbg_w_to_aw_outstanding;
logic                                 idle_aw;
logic [LP_TRANSACTION_CNTR_WIDTH-1:0] aw_transactions_to_go;
logic                                 aw_final_transaction;
// Write response channel
wire                                  bxfer;
logic [LP_TRANSACTION_CNTR_WIDTH-1:0] b_transactions_to_go;
logic                                 b_final_transaction;
logic                                 stall_aw;
logic [LP_OUTSTANDING_CNTR_WIDTH-1:0] outstanding_vacancy_count;

/////////////////////////////////////////////////////////////////////////////
// Control logic
/////////////////////////////////////////////////////////////////////////////
assign ctrl_done = done;

// Count the number of transfers and assert done when the last m_axi.bvalid is received.
always @(posedge aclk) begin
  done <= bxfer & b_final_transaction;
end

always @(posedge aclk) begin
  ctrl_start_d1 <= ctrl_start;
end

always @(posedge aclk) begin
  if (ctrl_start) begin
    // Round transfer size up to integer value of the axi interface data width. Convert to axi_arlen format which is length -1.
    total_len_r <= ctrl_xfer_size_in_bytes[0+:LP_LOG_DW_BYTES] > 0
                      ? ctrl_xfer_size_in_bytes[LP_LOG_DW_BYTES+:LP_TOTAL_LEN_WIDTH]
                      : ctrl_xfer_size_in_bytes[LP_LOG_DW_BYTES+:LP_TOTAL_LEN_WIDTH] - 1'b1;
    // Align transfer to burst length to avoid AXI protocol issues if starting address is not correctly aligned.
    addr_offset_r <= ctrl_addr_offset & ~LP_ADDR_MASK;
    byte_remainder_r <= ctrl_xfer_size_in_bytes[0+:LP_LOG_DW_BYTES]-1'b1;
  end
end

// Determine how many full burst to issue and if there are any partial bursts.
assign num_transactions = total_len_r[LP_LOG_BURST_LEN+:LP_TRANSACTION_CNTR_WIDTH];
assign has_partial_bursts = total_len_r[0+:LP_LOG_BURST_LEN] == '1 ? 1'b0 : 1'b1;

always @(posedge aclk) begin
  start <= ctrl_start_d1;
  final_burst_len  <= total_len_r[0+:LP_LOG_BURST_LEN];
end

// Special case if there is only 1 AXI transaction.
assign single_transaction = (num_transactions == '0) ? 1'b1 : 1'b0;

/////////////////////////////////////////////////////////////////////////////
// AXI Write Data Channel
/////////////////////////////////////////////////////////////////////////////
// Used to gate valid/ready signals with running so transfers don't occur before the
// xfer size is known.
always @(posedge aclk) begin
  w_running <= start            ? 1'b1 :
               w_final_transfer ? 1'b0 :
                                  w_running ;
end


  // xpm_fifo_sync: Synchronous FIFO
// Xilinx Parameterized Macro, Version 2017.4
xpm_fifo_sync # (
  .FIFO_MEMORY_TYPE    ( "block"              ) , // string; "auto", "block", "distributed", or "ultra";
  .ECC_MODE            ( "no_ecc"             ) , // string; "no_ecc" or "en_ecc";
  .FIFO_WRITE_DEPTH    ( LP_FIFO_DEPTH        ) , // positive integer
  .WRITE_DATA_WIDTH    ( C_M_AXIS_DATA_WIDTH  ) , // positive integer
  .WR_DATA_COUNT_WIDTH ( LP_FIFO_COUNT_WIDTH  ) , // positive integer, not used
  .PROG_FULL_THRESH    ( 10                   ) , // positive integer, not used
  .FULL_RESET_VALUE    ( 1                    ) , // positive integer; 0 or 1
  .USE_ADV_FEATURES    ( "1F1F"               ) , // string; "0000" to "1F1F";
  .READ_MODE           ( "fwft"               ) , // string; "std" or "fwft";
  .FIFO_READ_LATENCY   ( LP_FIFO_READ_LATENCY ) , // positive integer;
  .READ_DATA_WIDTH     ( C_M_AXIS_DATA_WIDTH  ) , // positive integer
  .RD_DATA_COUNT_WIDTH ( LP_FIFO_COUNT_WIDTH  ) , // positive integer, not used
  .PROG_EMPTY_THRESH   ( 10                   ) , // positive integer, not used
  .DOUT_RESET_VALUE    ( "0"                  ) , // string, don't care
  .WAKEUP_TIME         ( 0                    ) // positive integer; 0 or 2;
)
inst_xpm_fifo_sync (
  .sleep         ( 1'b0                     ) ,
  .rst           ( 1'b0                     ) ,
  .wr_clk        ( aclk                     ) ,
  .wr_en         ( s_axis_tvalid            ) ,
  .din           ( s_axis_tdata             ) ,
  .full          ( s_axis_tready_n          ) ,
  .overflow      (                          ) ,
  .prog_full     (                          ) ,
  .wr_data_count (                          ) ,
  .almost_full   (                          ) ,
  .wr_ack        (                          ) ,
  .wr_rst_busy   (                          ) ,
  .rd_en         ( fifo_rd                  ) ,
  .dout          ( fifo_out_data            ) ,
  .empty         (                          ) ,
  .prog_empty    (                          ) ,
  .rd_data_count (                          ) ,
  .almost_empty  (                          ) ,
  .data_valid    ( fifo_out_vld             ) ,
  .underflow     (                          ) ,
  .rd_rst_busy   (                          ) ,
  .injectsbiterr ( 1'b0                     ) ,
  .injectdbiterr ( 1'b0                     ) ,
  .sbiterr       (                          ) ,
  .dbiterr       (                          )
);

always_ff @( posedge aclk ) begin
    if (wxfer)
        w_sel <= w_sel + 1;
end

assign fifo_rd = (w_sel == 2'b11) & wxfer & w_running;

assign s_axis_tready = ~s_axis_tready_n;
assign m_axi.wvalid = fifo_out_vld & w_running;
mux_4_to_1 #(
   .RECORD_DATA_WIDTH   ( 512    )
)
u_wdata(
    .i_data_0           ( fifo_out_data[0+:512]     ) ,
    .i_data_1           ( fifo_out_data[512+:512]   ) ,
    .i_data_2           ( fifo_out_data[1024+:512]  ) ,
    .i_data_3           ( fifo_out_data[1536+:512]  ) ,
    .i_sel              ( w_sel                     ) ,

    .o_data             ( m_axi.wdata               ) 
);

assign wxfer = m_axi.wvalid & m_axi.wready;

assign w_final_transfer = m_axi.wlast & w_final_transaction & wxfer;
assign m_axi.wstrb   = m_axi.wlast & w_final_transaction ? final_strb : {(C_M_AXI_DATA_WIDTH/8){1'b1}};

always @(posedge aclk) begin
  final_strb[0] <= 1'b1;
  for (int i = 1; i < LP_DW_BYTES; i = i + 1) begin : loop
    final_strb[i] <= i > byte_remainder_r  ? 1'b0 : 1'b1;
  end
end

always @(posedge aclk) begin
  wfirst <= wxfer ? m_axi.wlast : wfirst;
end

// Load burst counter with partial burst if on final transaction or if there is only 1 transaction
assign load_burst_cntr = (wxfer & m_axi.wlast & w_almost_final_transaction) || (start & single_transaction);

axi_transaction_counter #(
  .C_WIDTH ( LP_LOG_BURST_LEN         ) ,
  .C_INIT  ( {LP_LOG_BURST_LEN{1'b1}} )
)
inst_burst_cntr (
  .clk        ( aclk            ) ,
  .load       ( load_burst_cntr ) ,
  .incr       ( 1'b0            ) ,
  .decr       ( wxfer           ) ,
  .load_value ( final_burst_len ) ,
  .count      ( wxfers_to_go    ) ,
  .is_zero    ( m_axi.wlast     )
);

axi_transaction_counter #(
  .C_WIDTH ( LP_TRANSACTION_CNTR_WIDTH         ) ,
  .C_INIT  ( {LP_TRANSACTION_CNTR_WIDTH{1'b0}} )
)
inst_w_transaction_cntr (
  .clk        ( aclk                 ) ,
  .load       ( start                ) ,
  .incr       ( 1'b0                 ) ,
  .decr       ( wxfer & m_axi.wlast  ) ,
  .load_value ( num_transactions     ) ,
  .count      ( w_transactions_to_go ) ,
  .is_zero    ( w_final_transaction  )
);

always @(*) begin
  w_almost_final_transaction <= (w_transactions_to_go == 1) ? 1'b1 : 1'b0;
end

/////////////////////////////////////////////////////////////////////////////
// AXI Write Address Channel
/////////////////////////////////////////////////////////////////////////////
// The address channel samples the data channel and send out transactions when
// first beat of m_axi.wdata is asserted. This ensures that address requests are not
// sent without data on the way.

assign m_axi.awvalid = awvalid_r;
assign awxfer = m_axi.awvalid & m_axi.awready;

always @(posedge aclk) begin
  awvalid_r <= ~idle_aw & ~awvalid_r & ~stall_aw ? 1'b1 :
               m_axi.awready         ? 1'b0 :
                                       awvalid_r;
end

assign m_axi.awaddr = addr;

always @(posedge aclk) begin
  addr <= start  ? addr_offset_r :
          awxfer ? addr + LP_DW_BYTES*LP_AXI_BURST_LEN :
                   addr;
end

assign m_axi.awburst  = 2'b01;
assign m_axi.awlen    = aw_final_transaction || (start & single_transaction) ? final_burst_len : LP_AXI_BURST_LEN- 1;
assign m_axi.awsize   = $clog2((C_M_AXI_DATA_WIDTH/8));
assign m_axi.awid     = {C_M_AXI_ID_WIDTH{1'b0}};

axi_transaction_counter #(
  .C_WIDTH (LP_LOG_MAX_W_TO_AW),
  .C_INIT ({LP_LOG_MAX_W_TO_AW{1'b0}})
)
inst_w_to_aw_cntr (
  .clk        ( aclk                    ) ,
  .load       ( 1'b0                    ) ,
  .incr       ( wfirst_pulse            ) ,
  .decr       ( awxfer                  ) ,
  .load_value ( '0                      ) ,
  .count      ( dbg_w_to_aw_outstanding ) ,
  .is_zero    ( idle_aw                 )
);

always @(posedge aclk) begin
  wfirst_d1 <= m_axi.wvalid & wfirst;
end

always @(posedge aclk) begin
  wfirst_pulse <= m_axi.wvalid & wfirst & ~wfirst_d1;
end

axi_transaction_counter #(
  .C_WIDTH ( LP_TRANSACTION_CNTR_WIDTH         ) ,
  .C_INIT  ( {LP_TRANSACTION_CNTR_WIDTH{1'b0}} )
)
inst_aw_transaction_cntr (
  .clk        ( aclk                   ) ,
  .load       ( start                  ) ,
  .incr       ( 1'b0                   ) ,
  .decr       ( awxfer                 ) ,
  .load_value ( num_transactions       ) ,
  .count      ( aw_transactions_to_go  ) ,
  .is_zero    ( aw_final_transaction   )
);

/////////////////////////////////////////////////////////////////////////////
// AXI Write Response Channel
/////////////////////////////////////////////////////////////////////////////
assign m_axi.bready = 1'b1;
assign bxfer = m_axi.bready & m_axi.bvalid;

axi_transaction_counter #(
  .C_WIDTH ( LP_TRANSACTION_CNTR_WIDTH         ) ,
  .C_INIT  ( {LP_TRANSACTION_CNTR_WIDTH{1'b0}} )
)
inst_b_transaction_cntr (
  .clk        ( aclk                 ) ,
  .load       ( start                ) ,
  .incr       ( 1'b0                 ) ,
  .decr       ( bxfer                ) ,
  .load_value ( num_transactions     ) ,
  .count      ( b_transactions_to_go ) ,
  .is_zero    ( b_final_transaction  )
);

// Keeps track of the number of outstanding transactions. Stalls
// when the value is reached so that the FIFO won't overflow.
// If no FIFO present, then just limit at max outstanding transactions.
axi_transaction_counter #(
  .C_WIDTH ( LP_OUTSTANDING_CNTR_WIDTH                       ) ,
  .C_INIT  ( C_MAX_OUTSTANDING[0+:LP_OUTSTANDING_CNTR_WIDTH] )
)
inst_aw_to_b_transaction_cntr (
  .clk        ( aclk                              ) ,
  .load       ( 1'b0                              ) ,
  .incr       ( awxfer                            ) ,
  .decr       ( bxfer                             ) ,
  .load_value ( {LP_OUTSTANDING_CNTR_WIDTH{1'b0}} ) ,
  .count      ( outstanding_vacancy_count         ) ,
  .is_zero    ( stall_aw                          )
);

endmodule : axi_write_master_phase2


