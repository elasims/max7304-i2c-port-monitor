`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/31/2026 02:29:53 PM
// Design Name: 
// Module Name: i2c_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module i2c_tb;
    localparam TB_CLK_FREQ = 1_000_000;
    localparam TB_I2C_FREQ = 100_000;
    localparam OP_START=0, OP_WRITE=1, OP_READ=2, OP_STOP=3;

    reg clk, reset;
    reg start_op;
    reg [1:0] op_type;
    reg [7:0] wr_data;
    reg send_nack;
    wire i2c_done, i2c_busy, ack_rcv;
    wire [7:0] rd_bytes;
    wire sda, scl;

    top #(.CLK_FREQ(TB_CLK_FREQ), .I2C_FREQ(TB_I2C_FREQ)) dut (
        .clk(clk), .reset(reset), .sda(sda), .scl(scl),
        .start_op(start_op), .op_type(op_type), .wr_data(wr_data),
        .send_nack(send_nack), .i2c_done(i2c_done), .rd_bytes(rd_bytes),
        .ack_rcv(ack_rcv), .i2c_busy(i2c_busy)
    );

    max7304_model slave (.sda(sda), .scl(scl));
    pullup(sda);
    pullup(scl);

    initial clk = 0;
    always #500 clk = ~clk;

    task do_op(input [1:0] op, input [7:0] data, input nack);
        begin
            @(posedge clk);
            start_op  = 1; op_type = op; wr_data = data; send_nack = nack;
            @(posedge clk);
            start_op  = 0;
            @(negedge i2c_busy);
        end
    endtask

    initial begin
        reset=1; start_op=0; op_type=0; wr_data=0; send_nack=0;
        repeat (5) @(posedge clk);
        reset = 0;
        repeat (5) @(posedge clk);

        // write DIR register = 0xFF
        do_op(OP_START, 0, 0);
        do_op(OP_WRITE, 8'h38, 0);  // addr_w
        do_op(OP_WRITE, 8'h34, 0);  // reg = DIR
        do_op(OP_WRITE, 8'hFF, 0);  // data
        do_op(OP_STOP,  0, 0);

        #5000;

        // read VALUES register back
        do_op(OP_START, 0, 0);
        do_op(OP_WRITE, 8'h38, 0);  // addr_w
        do_op(OP_WRITE, 8'h3A, 0);  // reg = VALUES
        do_op(OP_START, 0, 0);
        do_op(OP_WRITE, 8'h39, 0);  // addr_r
        do_op(OP_READ,  0, 1);      // nack = last byte
        do_op(OP_STOP,  0, 0);

        $display("rd_bytes=%h ack_rcv=%b", rd_bytes, ack_rcv);
        #5000;
        $finish;
    end
endmodule

module max7304_model (
    inout wire sda,
    input wire scl
);
    reg [3:0] bit_cnt;
    reg [7:0] shift_reg;
    reg       reading;
    reg       got_addr;
    reg       drive_ack;
    localparam [7:0] TEST_BYTE = 8'h01;

    always @(negedge sda) begin
        if (scl) begin
            bit_cnt   <= 0;
            got_addr  <= 0;
            reading   <= 0;
            drive_ack <= 0;
        end
    end

    always @(posedge scl) begin
        if (bit_cnt < 8) begin
            shift_reg <= {shift_reg[6:0], sda};
            bit_cnt   <= bit_cnt + 1;
            if (bit_cnt == 7 && !got_addr) begin
                got_addr <= 1'b1;
                reading  <= sda;
            end
        end else begin
            // 9th clock = ack slot, then roll over for next byte
            bit_cnt   <= 0;
            drive_ack <= 1'b0;
        end
    end

    // Drive ACK (SDA low) during the 9th clock after each byte,
    // and drive read data back to master when in "reading" mode.
    always @(negedge scl) begin
        if (bit_cnt == 8) drive_ack <= 1'b1; // pull low for ack cell
    end

    assign sda = drive_ack                          ? 1'b0 :
                 (got_addr && reading && bit_cnt < 8) ? TEST_BYTE[7-bit_cnt] :
                 1'bz;

endmodule
