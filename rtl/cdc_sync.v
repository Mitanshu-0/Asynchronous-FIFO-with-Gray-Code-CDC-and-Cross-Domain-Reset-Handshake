module cdc_sync #(
    parameter PTR_WIDTH = 5
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire [PTR_WIDTH-1:0] async_ptr,
    output reg  [PTR_WIDTH-1:0] sync_ptr
);

    reg [PTR_WIDTH-1:0] sync_ff1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_ff1 <= {PTR_WIDTH{1'b0}};
            sync_ptr <= {PTR_WIDTH{1'b0}};
        end else begin
            sync_ff1 <= async_ptr;
            sync_ptr <= sync_ff1;
        end
    end

endmodule
