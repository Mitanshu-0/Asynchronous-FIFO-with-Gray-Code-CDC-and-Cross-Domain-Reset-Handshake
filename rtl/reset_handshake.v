module reset_handshake (
    input  wire clk,
    input  wire rst_n,
    output reg  init_done,
    input  wire remote_init_done,
    input  wire remote_ready,
    output wire ready,
    output wire remote_ready_sync
);

    reg init_sync_ff1;
    reg init_sync_ff2;

    reg ready_sync_ff1;
    reg ready_sync_ff2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            init_done <= 1'b0;
        else
            init_done <= 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            init_sync_ff1 <= 1'b0;
            init_sync_ff2 <= 1'b0;
        end else begin
            init_sync_ff1 <= remote_init_done;
            init_sync_ff2 <= init_sync_ff1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready_sync_ff1 <= 1'b0;
            ready_sync_ff2 <= 1'b0;
        end else begin
            ready_sync_ff1 <= remote_ready;
            ready_sync_ff2 <= ready_sync_ff1;
        end
    end

    assign ready = init_done && init_sync_ff2;
    assign remote_ready_sync = ready_sync_ff2;

endmodule
