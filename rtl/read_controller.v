module read_controller #(
    parameter ADDR_WIDTH = 4
)(
    input  wire                  rd_clk,
    input  wire                  rd_rst_n,
    input  wire                  rd_en,
    input  wire                  fifo_enable,
    input  wire [ADDR_WIDTH:0]   wr_ptr_gray_sync,
    output wire [ADDR_WIDTH-1:0] rd_addr,
    output reg  [ADDR_WIDTH:0]   rd_ptr_bin,
    output reg  [ADDR_WIDTH:0]   rd_ptr_gray,
    output reg                   empty,
    output reg                   underflow
);

    reg [ADDR_WIDTH:0] rd_ptr_bin_next;
    reg [ADDR_WIDTH:0] rd_ptr_gray_next;
    reg empty_next;

    wire read_accept;

    assign read_accept =
        rd_en &&
        !empty &&
        fifo_enable;

    always @(*) begin
        if (read_accept)
            rd_ptr_bin_next = rd_ptr_bin + 1'b1;
        else
            rd_ptr_bin_next = rd_ptr_bin;
    end

    always @(*) begin
        rd_ptr_gray_next =
            rd_ptr_bin_next ^
            (rd_ptr_bin_next >> 1);
    end

    always @(*) begin
        empty_next =
            (rd_ptr_gray_next == wr_ptr_gray_sync);
    end

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr_bin  <= {ADDR_WIDTH+1{1'b0}};
            rd_ptr_gray <= {ADDR_WIDTH+1{1'b0}};
            empty       <= 1'b1;
            underflow   <= 1'b0;
        end else if (!fifo_enable) begin
            rd_ptr_bin  <= {ADDR_WIDTH+1{1'b0}};
            rd_ptr_gray <= {ADDR_WIDTH+1{1'b0}};
            empty       <= 1'b1;
            underflow   <= 1'b0;
        end else begin
            rd_ptr_bin  <= rd_ptr_bin_next;
            rd_ptr_gray <= rd_ptr_gray_next;
            empty       <= empty_next;
            underflow   <= rd_en && empty;
        end
    end

    assign rd_addr = rd_ptr_bin[ADDR_WIDTH-1:0];

endmodule
