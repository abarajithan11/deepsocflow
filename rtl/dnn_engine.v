`timescale 1ns/1ps
`define VERILOG
`include "../params/params.svh"
`undef  VERILOG

module dnn_engine #(
    parameter   S_PIXELS_WIDTH_LF  = `S_PIXELS_WIDTH_LF  ,
                S_WEIGHTS_WIDTH_LF = `S_WEIGHTS_WIDTH_LF ,
                M_OUTPUT_WIDTH_LF  = `M_OUTPUT_WIDTH_LF  ,
                ROWS               = `ROWS               ,
                COLS               = `COLS               ,
                WORD_WIDTH         = `WORD_WIDTH         , 
                WORD_WIDTH_ACC     = `WORD_WIDTH_ACC     ,
                TUSER_WIDTH        = `TUSER_WIDTH        ,

    localparam  M_DATA_WIDTH_HF_CONV    = COLS  * ROWS  * WORD_WIDTH_ACC,
                M_DATA_WIDTH_HF_CONV_DW = ROWS  * WORD_WIDTH_ACC
  )(
    input  wire aclk,
    input  wire aresetn,

    output wire s_axis_pixels_tready,
    input  wire s_axis_pixels_tvalid,
    input  wire s_axis_pixels_tlast ,
    input  wire [S_PIXELS_WIDTH_LF  -1:0]              s_axis_pixels_tdata,
    input  wire [S_PIXELS_WIDTH_LF/WORD_WIDTH-1:0]     s_axis_pixels_tkeep,

    output wire s_axis_weights_tready,
    input  wire s_axis_weights_tvalid,
    input  wire s_axis_weights_tlast ,
    input  wire [S_WEIGHTS_WIDTH_LF -1:0]              s_axis_weights_tdata,
    input  wire [S_WEIGHTS_WIDTH_LF/WORD_WIDTH -1:0]   s_axis_weights_tkeep,

    input  wire m_axis_tready,
    output wire m_axis_tvalid,
    output wire m_axis_tlast ,
    output wire [M_OUTPUT_WIDTH_LF               -1:0] m_axis_tdata,
    output wire [M_OUTPUT_WIDTH_LF/WORD_WIDTH_ACC-1:0] m_axis_tkeep
  ); 

  /* WIRES */

  wire input_m_axis_tready;
  wire input_m_axis_tvalid;
  wire input_m_axis_tlast ;
  wire [WORD_WIDTH*ROWS    -1:0] input_m_axis_pixels_tdata;
  wire [WORD_WIDTH*COLS    -1:0] input_m_axis_weights_tdata;
  wire [TUSER_WIDTH        -1:0] input_m_axis_tuser        ;

  wire conv_m_axis_tready;
  wire conv_m_axis_tvalid;
  wire conv_m_axis_tlast ;
  wire [TUSER_WIDTH          -1:0] conv_m_axis_tuser;
  wire [M_DATA_WIDTH_HF_CONV -1:0] conv_m_axis_tdata; // cgmu

  wire dw_s_axis_tready;
  wire dw_s_axis_tvalid;
  wire dw_s_axis_tlast ;
  wire [TUSER_WIDTH    -1:0] dw_s_axis_tuser ;
  wire [M_DATA_WIDTH_HF_CONV_DW -1:0] dw_s_axis_tdata ;


  axis_input_pipe input_pipe (
    .aclk                      (aclk    ),
    .aresetn                   (aresetn ),
    .s_axis_pixels_tready      (s_axis_pixels_tready       ), 
    .s_axis_pixels_tvalid      (s_axis_pixels_tvalid       ), 
    .s_axis_pixels_tlast       (s_axis_pixels_tlast        ), 
    .s_axis_pixels_tdata       (s_axis_pixels_tdata        ), 
    .s_axis_pixels_tkeep       (s_axis_pixels_tkeep        ), 
    .s_axis_weights_tready     (s_axis_weights_tready      ),
    .s_axis_weights_tvalid     (s_axis_weights_tvalid      ),
    .s_axis_weights_tlast      (s_axis_weights_tlast       ),
    .s_axis_weights_tdata      (s_axis_weights_tdata       ),
    .s_axis_weights_tkeep      (s_axis_weights_tkeep       ),
    .m_axis_tready             (input_m_axis_tready        ),      
    .m_axis_tvalid             (input_m_axis_tvalid        ),     
    .m_axis_tlast              (input_m_axis_tlast         ),     
    .m_axis_pixels_tdata       (input_m_axis_pixels_tdata  ),
    .m_axis_weights_tdata      (input_m_axis_weights_tdata ), // CMG_flat
    .m_axis_tuser              (input_m_axis_tuser         )
  );
  proc_engine PROC_ENGINE (
    .clk            (aclk    ),
    .resetn         (aresetn ),
    .s_valid        (input_m_axis_tvalid        ),
    .s_ready        (input_m_axis_tready        ),
    .s_last         (input_m_axis_tlast         ),
    .s_user         (input_m_axis_tuser         ),
    .s_data_pixels  (input_m_axis_pixels_tdata  ),
    .s_data_weights (input_m_axis_weights_tdata ),
    .m_valid        (conv_m_axis_tvalid         ),
    .m_ready        (conv_m_axis_tready         ),
    .m_data         (conv_m_axis_tdata          ),
    .m_last         (conv_m_axis_tlast          ),
    .m_user         (conv_m_axis_tuser          )
    );
  axis_out_shift OUT (
    .aclk    (aclk   ),
    .aresetn (aresetn),
    .s_ready (conv_m_axis_tready    ),
    .s_valid (conv_m_axis_tvalid    ),
    .s_data  (conv_m_axis_tdata     ),
    .s_user  (conv_m_axis_tuser     ),
    .s_last  (conv_m_axis_tlast     ),
    .m_ready (dw_s_axis_tready),
    .m_valid (dw_s_axis_tvalid),
    .m_data  (dw_s_axis_tdata ),
    .m_user  (dw_s_axis_tuser ),
    .m_last  (dw_s_axis_tlast )
  );

  alex_axis_adapter_any #(
    .S_DATA_WIDTH  (M_DATA_WIDTH_HF_CONV_DW),
    .M_DATA_WIDTH  (M_OUTPUT_WIDTH_LF),
    .S_KEEP_ENABLE (1),
    .M_KEEP_ENABLE (1),
    .S_KEEP_WIDTH  (M_DATA_WIDTH_HF_CONV_DW/WORD_WIDTH_ACC),
    .M_KEEP_WIDTH  (M_OUTPUT_WIDTH_LF/WORD_WIDTH_ACC),
    .ID_ENABLE     (0),
    .DEST_ENABLE   (0),
    .USER_ENABLE   (0)
  ) DW_OUT (
    .clk           (aclk    ),
    .rst           (~aresetn),
    .s_axis_tready (dw_s_axis_tready),
    .s_axis_tvalid (dw_s_axis_tvalid),
    .s_axis_tdata  (dw_s_axis_tdata ),
    .s_axis_tkeep  ({(M_DATA_WIDTH_HF_CONV_DW/WORD_WIDTH_ACC){1'b1}}),
    .s_axis_tlast  (dw_s_axis_tlast ),
    .m_axis_tready (m_axis_tready),
    .m_axis_tvalid (m_axis_tvalid),
    .m_axis_tdata  (m_axis_tdata ),
    .m_axis_tkeep  (m_axis_tkeep ),
    .m_axis_tlast  (m_axis_tlast )
  );
endmodule