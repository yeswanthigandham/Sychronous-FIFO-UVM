// Synchronous FIFO with proper dout, full/empty, and reset
interface intf #(parameter DEPTH=8, DWIDTH=16) (input logic clk);
    logic        rstn;
    logic        rd_en;
    logic        wr_en;
    logic        empty;
    logic        full;
    logic [DWIDTH-1:0] din;
    logic [DWIDTH-1:0] dout;
endinterface

module sync_fifo #(parameter DEPTH=8, DWIDTH=16)
(
    input                     rstn,   // Active low reset
    input                     clk,    // Clock
    input                     wr_en,  // Write enable
    input                     rd_en,  // Read enable
    input  [DWIDTH-1:0]       din,    // Data written into FIFO
    output reg [DWIDTH-1:0]   dout,   // Data read from FIFO
    output                     empty, // FIFO is empty when high
    output                     full   // FIFO is full when high
);

    // Pointer width calculation
    localparam PTR_WIDTH = $clog2(DEPTH);

    reg [PTR_WIDTH-1:0] wptr;      // write pointer
    reg [PTR_WIDTH-1:0] rptr;      // read pointer
    reg [DWIDTH-1:0] fifo[0:DEPTH-1]; // FIFO storage

    // --------------------------
    // Write logic
    // --------------------------
    always @(posedge clk) begin
        if (!rstn) begin
            wptr <= 0;
        end else if (wr_en && !full) begin
            fifo[wptr] <= din;
            wptr <= wptr + 1;
        end
    end

    // --------------------------
    // Read logic
    // --------------------------
    always @(posedge clk) begin
        if (!rstn) begin
            rptr <= 0;
            dout <= 0;
        end else if (rd_en && !empty) begin
            dout <= fifo[rptr];
            rptr <= rptr + 1;
        end else begin
            dout <= dout; // hold previous value
        end
    end

    // --------------------------
    // Full and Empty flags
    // --------------------------
    assign full  = ((wptr + 1) % DEPTH) == rptr; // next write wraps to read ptr
    assign empty = (wptr == rptr);

    // --------------------------
    // Simulation monitor
    // --------------------------
    initial begin
      $monitor("[%0t] [FIFO] rstn=%0b,wr_en=%0b din=0x%0h rd_en=%0b dout=0x%0h empty=%0b full=%0b",
                 $time,rstn, wr_en, din, rd_en, dout, empty, full);
    end

endmodule
