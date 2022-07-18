/**********************************************************************************
 *  This is the adder module that calculates the starting address for each channel.
**********************************************************************************/

module dsp_ch_addr #(
  parameter integer CHANNEL_OFFSET            = 0         
)
(
  input  logic                                    aclk                    ,

  input  logic [63:0]                             i_ptr                   ,

  output logic [63:0]                             o_ptr                      
);

///////////////////////////////////////////////////////////////////////////////////
//Declarations
///////////////////////////////////////////////////////////////////////////////////
localparam [8:0]     OPMODE      =   9'b00_000_11_11; // Z = 0, W = 0, X = A:B, Y = C
localparam [4:0]     INMODE      =   5'b00000    ; // Not used sincce we don't use preadder
localparam [3:0]     ALUMODE     =   4'b0000     ; // Z+W+X+Y+CIN: 
localparam [2:0]     CARRYINSEL  =   3'b000      ; // CIN = CARRYIN

logic [8:0]   opmode_code;
logic [4:0]   inmode_code;
logic [3:0]   alumode_code;
logic [2:0]   carry_in_sel;

logic [47:0]  op_AB ;
logic [47:0]  op_C  ;
logic [47:0]  op_P  ;

///////////////////////////////////////////////////////////////////////////////////
//Main body of the code
///////////////////////////////////////////////////////////////////////////////////

always_comb begin
  opmode_code   =   OPMODE      ;
  inmode_code   =   INMODE      ;
  alumode_code  =   ALUMODE     ;
  carry_in_sel  =   CARRYINSEL  ;

  op_AB         =   i_ptr[16+:48] ;
  op_C          =   {{31{1'b0}}, CHANNEL_OFFSET[0+:5], {12{1'b0}}};
  o_ptr         =   {op_P[0+:48], i_ptr[0+:16]}  ;
end

DSP48E2 #(
  .ACASCREG                     ( 1                     ) ,
  .ADREG                        ( 1                     ) ,
  .ALUMODEREG                   ( 1                     ) ,
  .AMULTSEL                     ( "A"                   ) ,
  .AREG                         ( 1                     ) ,
  .AUTORESET_PATDET             ( "NO_RESET"            ) ,
  .AUTORESET_PRIORITY           ( "RESET"               ) ,
  .A_INPUT                      ( "DIRECT"              ) ,
  .BCASCREG                     ( 1                     ) ,
  .BMULTSEL                     ( "B"                   ) ,
  .BREG                         ( 1                     ) ,
  .B_INPUT                      ( "DIRECT"              ) ,
  .CARRYINREG                   ( 1                     ) ,
  .CARRYINSELREG                ( 1                     ) ,
  .CREG                         ( 1                     ) ,
  .DREG                         ( 1                     ) ,
  .INMODEREG                    ( 1                     ) ,
  .IS_ALUMODE_INVERTED          ( 4'b0000               ) ,
  .IS_CARRYIN_INVERTED          ( 1'b0                  ) ,
  .IS_CLK_INVERTED              ( 1'b0                  ) ,
  .IS_INMODE_INVERTED           ( 5'b00000              ) ,
  .IS_OPMODE_INVERTED           ( 9'b000000000          ) ,
  .IS_RSTALLCARRYIN_INVERTED    ( 1'b0                  ) ,
  .IS_RSTALUMODE_INVERTED       ( 1'b0                  ) ,
  .IS_RSTA_INVERTED             ( 1'b0                  ) ,
  .IS_RSTB_INVERTED             ( 1'b0                  ) ,
  .IS_RSTCTRL_INVERTED          ( 1'b0                  ) ,
  .IS_RSTC_INVERTED             ( 1'b0                  ) ,
  .IS_RSTD_INVERTED             ( 1'b0                  ) ,
  .IS_RSTINMODE_INVERTED        ( 1'b0                  ) ,
  .IS_RSTM_INVERTED             ( 1'b0                  ) ,
  .IS_RSTP_INVERTED             ( 1'b0                  ) ,
  .MASK                         ( 48'h3FFFFFFFFFFF      ) ,
  .MREG                         ( 0                     ) ,
  .OPMODEREG                    ( 1                     ) ,
  .PATTERN                      ( 48'h000000000000      ) ,
  .PREADDINSEL                  ( "A"                   ) ,
  .PREG                         ( 1                     ) ,
  .RND                          ( 48'h000000000000      ) ,
  .SEL_MASK                     ( "MASK"                ) ,
  .SEL_PATTERN                  ( "PATTERN"             ) ,
  .USE_MULT                     ( "NONE"                ) ,
  .USE_PATTERN_DETECT           ( "NO_PATDET"           ) ,
  .USE_SIMD                     ( "ONE48"               ) ,
  .USE_WIDEXOR                  ( "FALSE"               ) ,
  .XORSIMD                      ( "XOR24_48_96"         ) 
)
u_dsp(
  .ACOUT                        ( /* Unused */          ) ,
  .BCOUT                        ( /* Unused */          ) ,
  .CARRYCASCOUT                 ( /* Unused */          ) ,
  .CARRYOUT                     ( /* Unused */          ) ,
  .MULTSIGNOUT                  ( /* Unused */          ) ,
  .OVERFLOW                     ( /* Unused */          ) ,
  .P                            ( op_P                  ) ,
  .PATTERNBDETECT               ( /* Unused */          ) ,
  .PATTERNDETECT                ( /* Unused */          ) ,
  .PCOUT                        ( /* Unused */          ) ,
  .UNDERFLOW                    ( /* Unused */          ) ,
  .XOROUT                       ( /* Unused */          ) ,

  .A                            ( op_AB[18+:30]         ) ,
  .ACIN                         ( '1                    ) ,
  .ALUMODE                      ( alumode_code          ) ,
  .B                            ( op_AB[0+:18]          ) ,
  .BCIN                         ( '1                    ) ,
  .C                            ( op_C                  ) ,
  .CARRYCASCIN                  ( '1                    ) ,
  .CARRYIN                      ( '1                    ) ,
  .CARRYINSEL                   ( carry_in_sel          ) ,
  .CEA1                         ( '1                    ) ,
  .CEA2                         ( '1                    ) ,
  .CEAD                         ( '0                    ) ,
  .CEALUMODE                    ( '1                    ) ,
  .CEB1                         ( '1                    ) ,
  .CEB2                         ( '1                    ) ,
  .CEC                          ( '1                    ) ,
  .CECARRYIN                    ( '0                    ) ,
  .CECTRL                       ( '1                    ) ,
  .CED                          ( '0                    ) ,
  .CEINMODE                     ( '1                    ) ,
  .CEM                          ( '0                    ) ,
  .CEP                          ( '1                    ) ,
  .CLK                          ( aclk                  ) ,
  .D                            ( '1                    ) ,
  .INMODE                       ( inmode_code           ) ,
  .MULTSIGNIN                   ( '0                    ) ,
  .OPMODE                       ( opmode_code           ) ,
  .PCIN                         ( '0                    ) ,
  .RSTA                         ( 1'b0                  ) ,
  .RSTALLCARRYIN                ( 1'b0                  ) ,
  .RSTALUMODE                   ( 1'b0                  ) ,
  .RSTB                         ( 1'b0                  ) ,
  .RSTC                         ( 1'b0                  ) ,
  .RSTCTRL                      ( 1'b0                  ) ,
  .RSTD                         ( 1'b0                  ) ,
  .RSTINMODE                    ( 1'b0                  ) ,
  .RSTM                         ( 1'b0                  ) ,
  .RSTP                         ( 1'b0                  ) 
);


endmodule