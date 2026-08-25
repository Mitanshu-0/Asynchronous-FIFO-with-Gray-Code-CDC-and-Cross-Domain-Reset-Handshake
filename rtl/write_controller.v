module write_controller #(
    parameter ADDR_WIDTH = 4
)(
    input  wire                  wr_clk,
    input  wire                  wr_rst_n,
    input  wire                  wr_en,
    input  wire                  fifo_enable,
    input  wire [ADDR_WIDTH:0]   rd_ptr_gray_sync,
    output wire [ADDR_WIDTH-1:0] wr_addr,
    output reg  [ADDR_WIDTH:0]   wr_ptr_bin,
    output reg  [ADDR_WIDTH:0]   wr_ptr_gray,
    output reg                   full,
    output reg                   overflow
);

    reg [ADDR_WIDTH:0] wr_ptr_bin_next;
    reg [ADDR_WIDTH:0] wr_ptr_gray_next;
    reg [ADDR_WIDTH:0] full_compare_ptr;
    reg full_next;

    wire write_accept;

    assign write_accept =
        wr_en &&
        !full &&
        fifo_enable;

    always @(*) begin
        if (write_accept)
            wr_ptr_bin_next = wr_ptr_bin + 1'b1;
        else
            wr_ptr_bin_next = wr_ptr_bin;
    end

    always @(*) begin
        wr_ptr_gray_next =
            wr_ptr_bin_next ^
            (wr_ptr_bin_next >> 1);
    end

    // Full: next write Gray pointer matches read pointer with wrap bits inverted.
    always @(*) begin
        full_compare_ptr = rd_ptr_gray_sync;
        full_compare_ptr[ADDR_WIDTH] =
            ~rd_ptr_gray_sync[ADDR_WIDTH];
        full_compare_ptr[ADDR_WIDTH-1] =
            ~rd_ptr_gray_sync[ADDR_WIDTH-1];
    end

    always @(*) begin
        full_next = (wr_ptr_gray_next == full_compare_ptr);
    end

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr_bin  <= {ADDR_WIDTH+1{1'b0}};
            wr_ptr_gray <= {ADDR_WIDTH+1{1'b0}};
            full        <= 1'b0;
            overflow    <= 1'b0;
        end else if (!fifo_enable) begin
            wr_ptr_bin  <= {ADDR_WIDTH+1{1'b0}};
            wr_ptr_gray <= {ADDR_WIDTH+1{1'b0}};
            full        <= 1'b0;
            overflow    <= 1'b0;
        end else begin
            wr_ptr_bin  <= wr_ptr_bin_next;
            wr_ptr_gray <= wr_ptr_gray_next;
            full        <= full_next;
            overflow    <= wr_en && full;
        end
    end

    assign wr_addr = wr_ptr_bin[ADDR_WIDTH-1:0];

endmodule
