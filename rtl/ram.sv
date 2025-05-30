`timescale 1ns/1ps

module ram (
    input   clk_i,
    input   rst_i,

    input   wb_cyc_i,       // any time a wishbone transaction is taking place

    input pA_wb_stb_i,    // true for any bus transaction request
    input [3:0] pA_wb_we_i,     // true for any write requests
    input [10:0] pA_wb_addr_i,   // contains the address of the request
    input [31:0] pA_wb_data_i,

    input pB_wb_stb_i,    
    input [3:0] pB_wb_we_i, 
    input [10:0] pB_wb_addr_i,  
    input [31:0] pB_wb_data_i,

    output pA_wb_stall_o,  // will be true on any cycle when the slave cannot accept a request from the master, and false any time a request can be accepted
    output logic pA_wb_ack_o,    // response from the slave, indicating that the request has been completed
    output logic [31:0] pA_wb_data_o,    // data returned by the slave to the bus master as a result of any read request

    output pB_wb_stall_o,  
    output logic pB_wb_ack_o,   
    output logic [31:0] pB_wb_data_o   

    `ifdef USE_POWER_PINS
        ,input logic VPWR,
        input logic VGND
    `endif
);

    logic [7:0] word_addr_A, word_addr_B;
    logic       selA, selB;
    logic precedence;

    assign word_addr_A = pA_wb_addr_i[9:2];
    assign selA        = pA_wb_addr_i[10];

    assign word_addr_B = pB_wb_addr_i[9:2];
    assign selB        = pB_wb_addr_i[10];

    logic conflict;
    assign conflict = pA_wb_stb_i && pB_wb_stb_i && (selA == selB);

    assign pA_wb_stall_o = conflict && pB_wb_stb_i && precedence;
    assign pB_wb_stall_o = conflict && pA_wb_stb_i && ~precedence;

    typedef struct packed {
        logic       valid;
        logic [3:0] we;
        logic       sel;
        logic [7:0] addr;
        logic [31:0] data_in;
    } ram_req_t;

    ram_req_t reqA_d, reqB_d;

    always_ff @(posedge clk_i or negedge rst_i) begin
        if (!rst_i) begin
            precedence <= '0;
            reqA_d <= '0;
            reqB_d <= '0;
            pA_wb_ack_o <= 0;
            pB_wb_ack_o <= 0;
        end else begin
            precedence <= ~precedence;
            // Capture A request
            if (pA_wb_stb_i && !pA_wb_stall_o) begin
                reqA_d.valid   <= 1;
                reqA_d.we      <= pA_wb_we_i;
                reqA_d.sel     <= selA;
                reqA_d.addr    <= word_addr_A;
                reqA_d.data_in <= pA_wb_data_i;
            end else begin
                reqA_d.valid <= 0;
            end

            // Capture B request
            if (pB_wb_stb_i && !pB_wb_stall_o) begin
                reqB_d.valid   <= 1;
                reqB_d.we      <= pB_wb_we_i;
                reqB_d.sel     <= selB;
                reqB_d.addr    <= word_addr_B;
                reqB_d.data_in <= pB_wb_data_i;
            end else begin
                reqB_d.valid <= 0;
            end

            // ACK after 1 cycle
            pA_wb_ack_o <= reqA_d.valid;
            pB_wb_ack_o <= reqB_d.valid;
        end
    end

    logic  en0;
    logic [3:0] we0;
    logic [7:0]  addr0;
    logic [31:0] din0, dout0;

    logic en1;
    logic [3:0]  we1;
    logic [7:0]  addr1;
    logic [31:0] din1, dout1;

    // Default disables
    always_comb begin
        // Default
        en0 = 0; we0 = 0; addr0 = 0; din0 = 0;
        en1 = 0; we1 = 0; addr1 = 0; din1 = 0;

        // Port A routing
        if (pA_wb_stb_i && !pA_wb_stall_o) begin
            if (!selA) begin
                en0 = 1; we0 = pA_wb_we_i; addr0 = word_addr_A; din0 = pA_wb_data_i;
            end else begin
                en1 = 1; we1 = pA_wb_we_i; addr1 = word_addr_A; din1 = pA_wb_data_i;
            end
        end

        // Port B routing
        if (pB_wb_stb_i && !pB_wb_stall_o) begin
            if (!selB) begin
                en0 = 1; we0 = pB_wb_we_i; addr0 = word_addr_B; din0 = pB_wb_data_i;
            end else begin
                en1 = 1; we1 = pB_wb_we_i; addr1 = word_addr_B; din1 = pB_wb_data_i;
            end
        end
    end

    // -----------------------------
    // Connect RAM outputs
    // -----------------------------
    always_ff @(posedge clk_i) begin
        if (reqA_d.valid)
            pA_wb_data_o <= reqA_d.sel ? dout1 : dout0;

        if (reqB_d.valid)
            pB_wb_data_o <= reqB_d.sel ? dout1 : dout0;
    end

    // -----------------------------
    // Instantiate Single-Port RAM Macros
    // -----------------------------
    DFFRAM256x32 ram0 (
        .CLK (clk_i),
        .WE0 (we0),
        .EN0 (en0),
        .Di0 (din0),
        .Do0 (dout0),
        .A0  (addr0)
    );

    DFFRAM256x32 ram1 (
        .CLK (clk_i),
        .WE0 (we1),
        .EN0 (en1),
        .Di0 (din1),
        .Do0 (dout1),
        .A0  (addr1)
    );

endmodule