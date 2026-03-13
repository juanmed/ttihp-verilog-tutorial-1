/*
 * Bentayga VGA Bouncing Text
 * Font: 8×8 pixels, scale 4 → each char = 32×32px
 * Text block: 8 chars × 32px = 256px wide, 32px tall
 */
`default_nettype none

module tt_um_vga_example(
  input  wire [7:0] ui_in,
  output wire [7:0] uo_out,
  input  wire [7:0] uio_in,
  output wire [7:0] uio_out,
  output wire [7:0] uio_oe,
  input  wire       ena,
  input  wire       clk,
  input  wire       rst_n
);

  // ── VGA wires ─────────────────────────────────────────────────────
  wire hsync, vsync, video_active;
  wire [1:0] R, G, B;
  wire [9:0] pix_x, pix_y;

  assign uo_out  = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  assign uio_out = 0;
  assign uio_oe  = 0;
  wire _unused_ok = &{ena, ui_in, uio_in};

  hvsync_generator hvsync_gen(
    .clk(clk), .reset(~rst_n),
    .hsync(hsync), .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x), .vpos(pix_y)
  );

  // ── Bouncing position registers ───────────────────────────────────
  // Text block is 256px wide (8 chars × 8px × scale4) and 32px tall
  // Safe X range: 0 – 383  (640 − 256 − 1)
  // Safe Y range: 0 – 447  (480 − 32  − 1)
  reg [9:0] text_x, text_y;
  reg       dir_x, dir_y;   // 0 = positive direction, 1 = negative

  always @(posedge vsync or negedge rst_n) begin
    if (!rst_n) begin
      text_x <= 10'd60;
      text_y <= 10'd200;
      dir_x  <= 1'b0;
      dir_y  <= 1'b0;
    end else begin
      // X bounce
      if (!dir_x) begin
        if (text_x >= 10'd383) dir_x <= 1'b1;
        else                   text_x <= text_x + 1'b1;
      end else begin
        if (text_x == 10'd0)   dir_x <= 1'b0;
        else                   text_x <= text_x - 1'b1;
      end
      // Y bounce
      if (!dir_y) begin
        if (text_y >= 10'd447) dir_y <= 1'b1;
        else                   text_y <= text_y + 1'b1;
      end else begin
        if (text_y == 10'd0)   dir_y <= 1'b0;
        else                   text_y <= text_y - 1'b1;
      end
    end
  end

  // ── Hit-test and font addressing ──────────────────────────────────
  wire in_text = video_active
               && (pix_x >= text_x) && (pix_x < text_x + 10'd256)
               && (pix_y >= text_y) && (pix_y < text_y + 10'd32);

  wire [9:0] rel_x    = pix_x - text_x;
  wire [9:0] rel_y    = pix_y - text_y;

  // Scale = 4 (power of 2 → use bit slices, no divider needed)
  // char index  : rel_x[7:5]  (rel_x / 32)
  // font col    : rel_x[4:2]  ((rel_x % 32) / 4, i.e. 0-7)
  // font row    : rel_y[4:2]  (rel_y / 4, i.e. 0-7)
  wire [2:0] char_idx  = rel_x[7:5];
  wire [2:0] char_px_x = rel_x[4:2];
  wire [2:0] char_px_y = rel_y[4:2];

  // ── Font ROM: "Bentayga" ─────────────────────────────────────────
  // 8 chars × 8 rows = 64 entries; index = {char_idx, char_px_y}
  // Bit 7 = leftmost pixel of each row
  reg [7:0] font_row;
  always @(*) begin
    case ({char_idx, char_px_y})
      // ── B ──────────────────────────  ████ / █..█ / ████ / █..█ / ████
      6'd0:  font_row = 8'hF0; // ████....
      6'd1:  font_row = 8'h88; // █...█...
      6'd2:  font_row = 8'h88; // █...█...
      6'd3:  font_row = 8'hF0; // ████....
      6'd4:  font_row = 8'h88; // █...█...
      6'd5:  font_row = 8'h88; // █...█...
      6'd6:  font_row = 8'hF0; // ████....
      6'd7:  font_row = 8'h00;
      // ── e ──────────────────────────
      6'd8:  font_row = 8'h70; // .███....
      6'd9:  font_row = 8'h88; // █...█...
      6'd10: font_row = 8'h88; // █...█...
      6'd11: font_row = 8'hF8; // █████...
      6'd12: font_row = 8'h80; // █.......
      6'd13: font_row = 8'h88; // █...█...
      6'd14: font_row = 8'h70; // .███....
      6'd15: font_row = 8'h00;
      // ── n ──────────────────────────
      6'd16: font_row = 8'h00;
      6'd17: font_row = 8'h00;
      6'd18: font_row = 8'hD8; // ██.██...
      6'd19: font_row = 8'hC8; // ██..█...
      6'd20: font_row = 8'h88; // █...█...
      6'd21: font_row = 8'h88;
      6'd22: font_row = 8'h88;
      6'd23: font_row = 8'h00;
      // ── t ──────────────────────────
      6'd24: font_row = 8'h20; // ..█.....
      6'd25: font_row = 8'h20;
      6'd26: font_row = 8'hF8; // █████...
      6'd27: font_row = 8'h20; // ..█.....
      6'd28: font_row = 8'h20;
      6'd29: font_row = 8'h20;
      6'd30: font_row = 8'h18; // ...██...
      6'd31: font_row = 8'h00;
      // ── a ──────────────────────────
      6'd32: font_row = 8'h00;
      6'd33: font_row = 8'h70; // .███....
      6'd34: font_row = 8'h08; // ....█...
      6'd35: font_row = 8'h78; // .████...
      6'd36: font_row = 8'h88; // █...█...
      6'd37: font_row = 8'h98; // █..██...
      6'd38: font_row = 8'h68; // .██.█...
      6'd39: font_row = 8'h00;
      // ── y ──────────────────────────
      6'd40: font_row = 8'h00;
      6'd41: font_row = 8'h88; // █...█...
      6'd42: font_row = 8'h88;
      6'd43: font_row = 8'h50; // .█.█....
      6'd44: font_row = 8'h20; // ..█.....
      6'd45: font_row = 8'h20;
      6'd46: font_row = 8'h20;
      6'd47: font_row = 8'h00;
      // ── g ──────────────────────────
      6'd48: font_row = 8'h00;
      6'd49: font_row = 8'h70; // .███....
      6'd50: font_row = 8'h88; // █...█...
      6'd51: font_row = 8'h88;
      6'd52: font_row = 8'h78; // .████...
      6'd53: font_row = 8'h08; // ....█...
      6'd54: font_row = 8'h70; // .███....
      6'd55: font_row = 8'h00;
      // ── a (second) ─────────────────
      6'd56: font_row = 8'h00;
      6'd57: font_row = 8'h70;
      6'd58: font_row = 8'h08;
      6'd59: font_row = 8'h78;
      6'd60: font_row = 8'h88;
      6'd61: font_row = 8'h98;
      6'd62: font_row = 8'h68;
      6'd63: font_row = 8'h00;
      default: font_row = 8'h00;
    endcase
  end

  // MSB of font_row = leftmost pixel; char_px_x=0 → bit 7
  wire pixel_on = in_text && font_row[7 - char_px_x];

  // ── Color output ──────────────────────────────────────────────────
  // White text over a shifting color-field background
  wire [1:0] bg_R = {pix_x[7], pix_y[6]};
  wire [1:0] bg_G = {pix_y[7], pix_x[6]};
  wire [1:0] bg_B = {pix_x[6] ^ pix_y[7], 1'b1};

  assign R = video_active ? (pixel_on ? 2'b11 : bg_R) : 2'b00;
  assign G = video_active ? (pixel_on ? 2'b11 : bg_G) : 2'b00;
  assign B = video_active ? (pixel_on ? 2'b11 : bg_B) : 2'b00;

endmodule