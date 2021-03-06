module ili9341_direct
(
  input            resetn,
  input            clk,
  input            iomem_valid,
  output reg       iomem_ready,
  input [3:0]      iomem_wstrb,
  input [31:0]     iomem_addr,
  input [31:0]     iomem_wdata,
  output [31:0]    iomem_rdata,
  output reg       nreset,
  output reg       cmd_data, // 1 => Data, 0 => Command
  output reg       write_edge, // Write signal on rising edge
  output reg [7:0] dout);

  reg [1:0] state = 0;
  reg [2:0] fast_state;
  reg [15:0] num_pixels;
  reg [19:0] pf;
  reg [15:0] back_color;
  reg [15:0] room_color;
  reg [4:0] pf_bit;
  reg [7:0] pf_y;
  reg [8:0] pf_x;
  reg [7:0] obj;
  reg flip;

  always @(posedge clk) begin
    iomem_ready <= 0;
    if (!resetn) begin
      state <= 0;
      fast_state <= 0;
      cmd_data <= 0;
      nreset <= 1;
      write_edge <= 0;
    end else if (iomem_valid && !iomem_ready) begin
      if (iomem_wstrb) begin
        iomem_ready <= 1;
        if (iomem_addr[7:0] == 'h08) cmd_data <= iomem_wdata; // dc
        else if (iomem_addr[7:0] == 'h0c) nreset <= iomem_wdata; // reset
        else if (iomem_addr[7:0] == 'h00) begin // xfer
          case (state)
            0 : begin
              write_edge <= 0;
              dout <= iomem_wdata[7:0];
              state <= 1;
              iomem_ready <= 0;
            end
            1 : begin
               write_edge <= 1;
               state <= 2;
               iomem_ready <= 0;
            end
            2 : begin
               write_edge <= 0;
               iomem_ready <= 1;
               state <= 0;
            end
          endcase
        end else if (iomem_addr[7:0] == 'h04) begin // fast xfer
          iomem_ready <= 0;
          case (fast_state)
            0 : begin
              num_pixels <= iomem_wdata[31:16];
              fast_state <= 1;
            end
            1: begin
              write_edge <= 0;
              dout <= iomem_wdata[15:8];
              fast_state <= 2;
            end
            2 : begin
               write_edge <= 1;
               fast_state <= 3;
            end
            3 : begin
               write_edge <= 0;
               dout <= iomem_wdata[7:0];
               fast_state <= 4;
            end
            4: begin
               write_edge <= 1;
               if (num_pixels == 1) begin
                 fast_state <= 5;
               end else begin
                 num_pixels <= num_pixels - 1;
                 fast_state <= 1;
              end
            end
            5: begin
               iomem_ready <= 1;
               write_edge <= 0;
               fast_state <= 0;
            end
          endcase
        end else if (iomem_addr[7:0] == 'h10) begin // Set PF values
          pf <= iomem_wdata[19:0];
        end else if (iomem_addr[7:0] == 'h14) begin // Set room colors
          back_color <= iomem_wdata[31:16];
          room_color <= iomem_wdata[15:0];
        end else if (iomem_addr[7:0] == 'h18) begin // Draw room 
          iomem_ready <= 0;
          
          case (fast_state)
            0 : begin
              num_pixels <= iomem_wdata[15:0];
              pf_bit <= 19;
              pf_x <= 0;
              pf_y <= 0;
              fast_state <= 1;
            end
            1: begin
              write_edge <= 0;
              dout <= (pf[pf_bit]) ? room_color[15:8] : back_color[15:8];
              fast_state <= 2;
            end
            2 : begin
               write_edge <= 1;
               fast_state <= 3;
            end
            3 : begin
               write_edge <= 0;
               dout <= (pf[pf_bit]) ? room_color[7:0] : back_color[7:0];
               fast_state <= 4;
            end
            4: begin
               write_edge <= 1;
               if (num_pixels == 1) begin
                 fast_state <= 5;
               end else begin
                 num_pixels <= num_pixels - 1;
                 pf_x <= (pf_x == 319 ? 0 : pf_x + 1);
                 if (pf_x == 319) pf_y <= pf_y + 1;
                 if (&pf_x[2:0] && pf_x != 159 && pf_x != 319) 
                   pf_bit <= (pf_x < 160 ? pf_bit - 1 : pf_bit + 1);
                 fast_state <= 1;
              end
            end
            5: begin
               iomem_ready <= 1;
               write_edge <= 0;
               fast_state <= 0;
            end
          endcase
        end else if (iomem_addr[7:0] == 'h1C) begin // Draw object 
          iomem_ready <= 0;
          
          case (fast_state)
            0 : begin
              obj <= iomem_wdata[7:0];
              flip <= iomem_wdata[8];
              num_pixels <= 16;
              pf_bit <= iomem_wdata[8] ? 0 : 7;
              fast_state <= 1;
            end
            1: begin
              write_edge <= 0;
              dout <= (obj[pf_bit]) ? room_color[15:8] : back_color[15:8];
              fast_state <= 2;
            end
            2 : begin
               write_edge <= 1;
               fast_state <= 3;
            end
            3 : begin
               write_edge <= 0;
               dout <= (obj[pf_bit]) ? room_color[7:0] : back_color[7:0];
               fast_state <= 4;
            end
            4: begin
               write_edge <= 1;
               if (num_pixels == 1) begin
                 fast_state <= 5;
               end else begin
                 num_pixels <= num_pixels - 1;
                 if (num_pixels[0]) pf_bit <= pf_bit + (flip ? 1 : -1);
                 fast_state <= 1;
              end
            end
            5: begin
               iomem_ready <= 1;
               write_edge <= 0;
               fast_state <= 0;
            end
          endcase
        end
      end
    end
  end

endmodule
