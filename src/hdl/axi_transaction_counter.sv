////////////////////////////////////////////////////////////////////////////////
// This is a counter for axi transaction
// 
////////////////////////////////////////////////////////////////////////////////
module axi_transaction_counter #(
  parameter integer       C_WIDTH   =   4               ,
  parameter [C_WIDTH-1:0] C_INIT    =   {C_WIDTH{1'b0}}
)
(
  input  logic                  clk         ,
  input  logic                  load        ,
  input  logic                  incr        ,
  input  logic                  decr        ,
  input  logic [C_WIDTH-1:0]    load_value  ,
  output logic [C_WIDTH-1:0]    count       ,
  output logic                  is_zero
);

///////////////////////////////////////////////////////////////////////////////////
//Declarations
///////////////////////////////////////////////////////////////////////////////////
// Local Parameters
localparam [C_WIDTH-1:0]  LP_ZERO  = {C_WIDTH{1'b0}};
localparam [C_WIDTH-1:0]  LP_ONE   = {{C_WIDTH-1{1'b0}},1'b1};
localparam [C_WIDTH-1:0]  LP_MAX   = {C_WIDTH{1'b1}};

// Variables
logic [C_WIDTH-1:0] count_r   =   C_INIT;
logic               is_zero_r =   (C_INIT == LP_ZERO);

///////////////////////////////////////////////////////////////////////////////////
//Main body of the code
///////////////////////////////////////////////////////////////////////////////////


always_ff @(posedge clk) begin
  if (load)
    count_r <= load_value;
  else if (incr & ~decr)
    count_r <= count_r + 1'b1;
  else if (~incr & decr)
    count_r <= count_r - 1'b1;
  else
    count_r <= count_r;
end

always_ff @(posedge clk) begin
  if (load)
    is_zero_r <= (load_value == LP_ZERO);
  else
    is_zero_r <= incr ^ decr ? (decr && (count_r == LP_ONE)) || (incr && (count_r == LP_MAX)) : is_zero_r;
end

always_comb begin : gen_output
  count     =   count_r   ;
  is_zero   =   is_zero_r ;
end: gen_output

endmodule : axi_transaction_counter