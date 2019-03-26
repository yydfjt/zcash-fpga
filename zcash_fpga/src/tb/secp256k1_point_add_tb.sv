/*
  Copyright (C) 2019  Benjamin Devlin and Zcash Foundation

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/
`timescale 1ps/1ps

module secp256k1_point_add_tb ();
import common_pkg::*;
import secp256k1_pkg::*;

localparam CLK_PERIOD = 1000;

logic clk, rst;

if_axi_stream #(.DAT_BYTS(256*6/8)) in_if(clk); // Two points
if_axi_stream #(.DAT_BYTS(256*3/8)) out_if(clk);

if_axi_stream #(.DAT_BYTS(256*2/8), .CTL_BITS(8)) mult_in_if(clk);
if_axi_stream #(.DAT_BYTS(256/8), .CTL_BITS(8)) mult_out_if(clk);

if_axi_stream #(.DAT_BYTS(256*2/8), .CTL_BITS(8)) mod_in_if(clk);
if_axi_stream #(.DAT_BYTS(256/8), .CTL_BITS(8)) mod_out_if(clk);


jb_point_t in_p1, in_p2, out_p;

always_comb begin
  in_p1 = in_if.dat[0 +: 256*3]; 
  in_p2 = in_if.dat[256*3 +: 256*3]; 
  out_if.dat = out_p;
end

initial begin
  rst = 0;
  repeat(2) #(20*CLK_PERIOD) rst = ~rst;
end

initial begin
  clk = 0;
  forever #CLK_PERIOD clk = ~clk;
end

always_comb begin
  out_if.sop = 1;
  out_if.eop = 1;
  out_if.ctl = 0;
  out_if.mod = 0;
end

// Check for errors
always_ff @ (posedge clk)
  if (out_if.val && out_if.err)
    $error(1, "%m %t ERROR: output .err asserted", $time);

secp256k1_point_add secp256k1_point_add(
  .i_clk ( clk ),
  .i_rst ( rst ),
    // Input points
  .i_p1   ( in_p1      ),
  .i_p2   ( in_p2      ),
  .i_val ( in_if.val ),
  .o_rdy ( in_if.rdy ),
  .o_p   ( out_p     ),
  .o_err ( out_if.err ),
  .i_rdy ( out_if.rdy ),
  .o_val  ( out_if.val ) ,
  .o_mult_if ( mult_in_if ),
  .i_mult_if ( mult_out_if ),
  .o_mod_if ( mod_in_if ),
  .i_mod_if ( mod_out_if )
);

// Attach a mod reduction unit and multiply - mod unit
// In full design these could use dedicated multipliers or be arbitrated
secp256k1_mult_mod #(
  .CTL_BITS ( 8 )
)
secp256k1_mult_mod (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .i_dat_a ( mult_in_if.dat[0 +: 256] ),
  .i_dat_b ( mult_in_if.dat[256 +: 256] ),
  .i_val ( mult_in_if.val ),
  .i_err ( mult_in_if.err ),
  .i_ctl ( mult_in_if.ctl ),
  .o_rdy ( mult_in_if.rdy ),
  .o_dat ( mult_out_if.dat ),
  .i_rdy ( mult_out_if.rdy ),
  .o_val ( mult_out_if.val ),
  .o_ctl ( mult_out_if.ctl ),
  .o_err ( mult_out_if.err ) 
);

secp256k1_mod #(
  .USE_MULT ( 0 ),
  .CTL_BITS ( 8 )
)
secp256k1_mod (
  .i_clk( clk       ),
  .i_rst( rst       ),
  .i_dat( mod_in_if.dat  ),
  .i_val( mod_in_if.val  ),
  .i_err( mod_in_if.err  ),
  .i_ctl( mod_in_if.ctl  ),
  .o_rdy( mod_in_if.rdy  ),
  .o_dat( mod_out_if.dat ),
  .o_ctl( mod_out_if.ctl ),
  .o_err( mod_out_if.err ),
  .i_rdy( mod_out_if.rdy ),
  .o_val( mod_out_if.val )
);

task test_0();
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] expected,  get_dat;
  logic [255:0] in_a, in_b;
  jb_point_t p1, p2, p_exp, p_temp, p_out;
  $display("Running test_0...");
  
  //p1 = {x:3, y:4, z:1};
 // p2 = {x:1, y:2, z:1};
  
  /*p1 = {x:256'h79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798,
        y:256'h483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8,
        z:256'h0000000000000000000000000000000000000000000000000000000000000001};
  p2 = {x:256'h7d152c041ea8e1dc2191843d1fa9db55b68f88fef695e2c791d40444b365afc2,
        y:256'h56915849f52cc8f76f5fd7e4bf60db4a43bf633e1b1383f85fe89164bfadcbdb,
        z:256'h9075b4ee4d4788cabb49f7f81c221151fa2f68914d0aa833388fa11ff621a970};      
        */
  p1 = {x:256'h79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798,
        y:256'h483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8,
        z:256'h1};
  p2 = {x:256'h7d152c041ea8e1dc2191843d1fa9db55b68f88fef695e2c791d40444b365afc2,
        y:256'h56915849f52cc8f76f5fd7e4bf60db4a43bf633e1b1383f85fe89164bfadcbdb,
        z:256'h9075b4ee4d4788cabb49f7f81c221151fa2f68914d0aa833388fa11ff621a970};
  
        
  p_exp = add_jb_point(p1, p2);
  
  fork
    in_if.put_stream({p2, p1}, 256*6/8);
    out_if.get_stream(get_dat, get_len);
  join
  
  p_out = get_dat;
  
  $display("%d %d %d", on_curve(p1), on_curve(p2), on_curve(p_out));//, on_curve(p_temp));
  
  if (p_exp != p_out) begin
    $display("Expected:");
    print_jb_point(p_exp);
    $display("Was:");
    print_jb_point(p_out);
    $fatal(1, "%m %t ERROR: test_0 point was wrong", $time);
  end 
  
  $display("test_0 PASSED");
end
endtask;

function compare_point();
  
endfunction

initial begin
  out_if.rdy = 0;
  in_if.val = 0;
  #(40*CLK_PERIOD);
  
  test_0();

  #1us $finish();
end
endmodule