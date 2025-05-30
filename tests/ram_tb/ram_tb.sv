`timescale 1ns/1ps

module ram_tb;

  // Necessary to create Waveform
  initial begin
      // Name as needed
      $dumpfile("ram_tb.vcd");
      $dumpvars(2, ram_tb);
      // $dumpvars(0);
  end

  initial begin
    #1000 $error("Timeout"); $finish();
  end

  logic clk;
  logic rst;

  // Wishbone signals
  logic wb_cyc;

  // Port A
  logic        pA_stb;
  logic [3:0]  pA_we;
  logic [10:0] pA_addr;
  logic [31:0] pA_data_in;
  logic        pA_stall;
  logic        pA_ack;
  logic [31:0] pA_data_out;

  // Port B
  logic        pB_stb;
  logic [3:0]  pB_we;
  logic [10:0] pB_addr;
  logic [31:0] pB_data_in;
  logic        pB_stall;
  logic        pB_ack;
  logic [31:0] pB_data_out;

  `ifdef USE_POWER_PINS
    wire VPWR;
    wire VGND;
    assign VPWR=1;
    assign VGND=0;
  `endif

  // Instantiate DUT
  ram dut (
    .clk_i(clk),
    .rst_i(rst),
    .wb_cyc_i(wb_cyc),
    .pA_wb_stb_i(pA_stb),
    .pA_wb_we_i(pA_we),
    .pA_wb_addr_i(pA_addr),
    .pA_wb_data_i(pA_data_in),
    .pA_wb_stall_o(pA_stall),
    .pA_wb_ack_o(pA_ack),
    .pA_wb_data_o(pA_data_out),
    .pB_wb_stb_i(pB_stb),
    .pB_wb_we_i(pB_we),
    .pB_wb_addr_i(pB_addr),
    .pB_wb_data_i(pB_data_in),
    .pB_wb_stall_o(pB_stall),
    .pB_wb_ack_o(pB_ack),
    .pB_wb_data_o(pB_data_out)
    `ifdef USE_POWER_PINS
      ,.VPWR(VPWR),
      .VGND(VGND)
    `endif
  );

  localparam CLK_PERIOD = 10; // localparam is a parameter that can't be changed from outside the module
  always begin
      #(CLK_PERIOD/2) 
      clk<=~clk;
  end

  task reset();
    clk = 0;
    rst = 0;
    wb_cyc = 0;
    pA_stb       = 1'b0;
    pA_we        = 4'b0000;
    pA_addr      = 11'b00000000000;
    pA_data_in   = 32'b0;
    pB_stb       = 1'b0;
    pB_we        = 4'b0000;
    pB_addr      = 11'b00000000000;
    pB_data_in   = 32'b0;
    #20;
    rst = 1;
  endtask

  task write_portA(input [10:0] addr, input [31:0] data, input [3:0] we);
    pA_addr = addr;
    pA_data_in = data;
    pA_we = we;
    pA_stb = 1;
    wb_cyc = 1;
    @(posedge clk);
    wait (pA_ack);
    @(posedge clk);
    pA_stb = 0;
    pA_we = 0;
    wb_cyc = 0;
  endtask

  task read_portA(input [10:0] addr);
    pA_addr = addr;
    pA_we = 4'b0;
    pA_stb = 1;
    wb_cyc = 1;
    @(posedge clk);
    wait (pA_ack);
    @(posedge clk);
    pA_stb = 0;
    wb_cyc = 0;
  endtask

  task write_portB(input [10:0] addr, input [31:0] data, input [3:0] we);
    pB_addr = addr;
    pB_data_in = data;
    pB_we = we;
    pB_stb = 1;
    wb_cyc = 1;
    @(posedge clk);
    wait (pB_ack);
    @(posedge clk);
    pB_stb = 0;
    pB_we = 0;
    wb_cyc = 0;
  endtask

  task read_portB(input [10:0] addr);
    pB_addr = addr;
    pB_we = 4'b0;
    pB_stb = 1;
    wb_cyc = 1;
    @(posedge clk);
    wait (pB_ack);
    @(posedge clk);
    pB_stb = 0;
    wb_cyc = 0;
  endtask

  initial begin
    rst = 1; // start rst high (off)
    // @(posedge clk);
    reset();

    $display(">>> Writing to Port A (RAM0) and Port B (RAM1)");
    write_portA(11'b00000000000, 32'hAAAA_AAAA, 4'hF); // RAM0
    write_portB(11'b10000000000, 32'hBBBB_BBBB, 4'hF); // RAM1

    $display(">>> Reading back from Port A and B");
    read_portA(11'b10000000000);
    $display("Port A Read Data: %h", pA_data_out);

    read_portB(11'b00000000000);
    $display("Port B Read Data: %h", pB_data_out);

    repeat (2) @(posedge clk)

    $display(">>> Simultaneous access to same RAM (RAM0) from both ports");
    fork
      write_portA(11'b00000000100, 32'h1111_1111, 4'hF);
      write_portB(11'b00000001000, 32'h2222_2222, 4'hF);
    join

    read_portA(11'b00000000100);
    $display("Port A (conflict) Read: %h", pA_data_out);
    assert(pA_data_out == 32'h1111_1111);
      else $error("Read: %0h, Expected = %0h", pA_data_out, 32'h1111_1111);

    read_portB(11'b00000001000);
    $display("Port B (conflict) Read: %h", pB_data_out);
    assert(pB_data_out == 32'h2222_2222);
      else $error("Read: %0h, Expected = %0h", pB_data_out, 32'h2222_2222);

    $display(">>> Testbench complete.");
    $finish();
  end

endmodule