
module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
)(
    input  wire                  wr_clk,
    input  wire                  wr_rst_n,
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire                  full,
    output wire                  overflow,

    input  wire                  rd_clk,
    input  wire                  rd_rst_n,
    input  wire                  rd_en,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire                  empty,
    output wire                  underflow
);

    // pointer width = addr width + 1 extra MSB, used to disambiguate
    // full vs empty when read/write pointers wrap around the buffer
    localparam PTR_WIDTH = ADDR_WIDTH + 1;

    wire wr_local_rst_n;
    wire rd_local_rst_n;

    // async assert / sync de-assert reset synchronizer, one per domain
    reset_sync u_wr_reset_sync (
        .clk(wr_clk),
        .arst_n(wr_rst_n),
        .srst_n(wr_local_rst_n)
    );

    reset_sync u_rd_reset_sync (
        .clk(rd_clk),
        .arst_n(rd_rst_n),
        .srst_n(rd_local_rst_n)
    );

    wire wr_init_done;
    wire rd_init_done;
    wire wr_ready;
    wire rd_ready;
    wire wr_remote_ready_sync;
    wire rd_remote_ready_sync;

    // cross-domain reset handshake: each domain waits for the other
    // domain's init_done/ready before it will let its own pointer move
    reset_handshake u_wr_handshake (
        .clk(wr_clk),
        .rst_n(wr_local_rst_n),
        .init_done(wr_init_done),
        .remote_init_done(rd_init_done),
        .remote_ready(rd_ready),
        .ready(wr_ready),
        .remote_ready_sync(wr_remote_ready_sync)
    );

    reset_handshake u_rd_handshake (
        .clk(rd_clk),
        .rst_n(rd_local_rst_n),
        .init_done(rd_init_done),
        .remote_init_done(wr_init_done),
        .remote_ready(wr_ready),
        .ready(rd_ready),
        .remote_ready_sync(rd_remote_ready_sync)
    );

    wire wr_fifo_enable;
    wire rd_fifo_enable;

    // controllers only run once both local reset AND remote handshake
    // have completed - otherwise pointers/flags are held at reset
    assign wr_fifo_enable =
        wr_ready &&
        wr_remote_ready_sync;

    assign rd_fifo_enable =
        rd_ready &&
        rd_remote_ready_sync;

    wire [ADDR_WIDTH-1:0] wr_addr;
    wire [ADDR_WIDTH-1:0] rd_addr;

    wire [PTR_WIDTH-1:0] wr_ptr_bin;
    wire [PTR_WIDTH-1:0] wr_ptr_gray;

    wire [PTR_WIDTH-1:0] rd_ptr_bin;
    wire [PTR_WIDTH-1:0] rd_ptr_gray;

    // pointers synced into the opposite clock domain, Gray-coded
    wire [PTR_WIDTH-1:0] rd_ptr_gray_sync;
    wire [PTR_WIDTH-1:0] wr_ptr_gray_sync;

    write_controller #(
        .ADDR_WIDTH(ADDR_WIDTH)
    )
    u_write_controller (
        .wr_clk(wr_clk),
        .wr_rst_n(wr_local_rst_n),
        .wr_en(wr_en),
        .fifo_enable(wr_fifo_enable),
        .rd_ptr_gray_sync(rd_ptr_gray_sync),
        .wr_addr(wr_addr),
        .wr_ptr_bin(wr_ptr_bin),
        .wr_ptr_gray(wr_ptr_gray),
        .full(full),
        .overflow(overflow)
    );

    read_controller #(
        .ADDR_WIDTH(ADDR_WIDTH)
    )
    u_read_controller (
        .rd_clk(rd_clk),
        .rd_rst_n(rd_local_rst_n),
        .rd_en(rd_en),
        .fifo_enable(rd_fifo_enable),
        .wr_ptr_gray_sync(wr_ptr_gray_sync),
        .rd_addr(rd_addr),
        .rd_ptr_bin(rd_ptr_bin),
        .rd_ptr_gray(rd_ptr_gray),
        .empty(empty),
        .underflow(underflow)
    );

    // read pointer -> write domain (2-FF synchronizer)
    cdc_sync #(
        .PTR_WIDTH(PTR_WIDTH)
    )
    u_sync_read_to_write (
        .clk(wr_clk),
        .rst_n(wr_local_rst_n),
        .async_ptr(rd_ptr_gray),
        .sync_ptr(rd_ptr_gray_sync)
    );

    // write pointer -> read domain (2-FF synchronizer)
    cdc_sync #(
        .PTR_WIDTH(PTR_WIDTH)
    )
    u_sync_write_to_read (
        .clk(rd_clk),
        .rst_n(rd_local_rst_n),
        .async_ptr(wr_ptr_gray),
        .sync_ptr(wr_ptr_gray_sync)
    );

    fifo_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    )
    u_fifo_memory (
        .wr_clk(wr_clk),
        .wr_en(
            wr_en &&
            !full &&
            wr_fifo_enable
        ),
        .wr_addr(wr_addr),
        .wr_data(wr_data),

        .rd_clk(rd_clk),
        .rd_en(
            rd_en &&
            !empty &&
            rd_fifo_enable
        ),
        .rd_addr(rd_addr),
        .rd_data(rd_data)
    );

endmodule


// =====================================================================
// Async assert / sync de-assert reset synchronizer
// =====================================================================
module reset_sync (
    input  wire clk,
    input  wire arst_n,
    output wire srst_n
);

    reg [1:0] sync_ff;

    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            sync_ff <= 2'b00;
        end
        else begin
            sync_ff <= {sync_ff[0], 1'b1};
        end
    end

    assign srst_n = sync_ff[1];

endmodule



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

    // local domain declares itself initialized one cycle after reset lifts
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            init_done <= 1'b0;
        end
        else begin
            init_done <= 1'b1;
        end
    end

    // 2-FF synchronizer: remote init_done into this clock domain
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            init_sync_ff1 <= 1'b0;
            init_sync_ff2 <= 1'b0;
        end
        else begin
            init_sync_ff1 <= remote_init_done;
            init_sync_ff2 <= init_sync_ff1;
        end
    end

    // 2-FF synchronizer: remote ready into this clock domain
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready_sync_ff1 <= 1'b0;
            ready_sync_ff2 <= 1'b0;
        end
        else begin
            ready_sync_ff1 <= remote_ready;
            ready_sync_ff2 <= ready_sync_ff1;
        end
    end

    // ready once locally initialized AND remote domain's init is synced in
    assign ready =
        init_done &&
        init_sync_ff2;

    assign remote_ready_sync =
        ready_sync_ff2;

endmodule


// =====================================================================
// 2-FF Gray-code pointer synchronizer (CDC)
// =====================================================================
module cdc_sync #(
    parameter PTR_WIDTH = 5
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire [PTR_WIDTH-1:0]  async_ptr,
    output reg  [PTR_WIDTH-1:0]  sync_ptr
);

    reg [PTR_WIDTH-1:0] sync_ff1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_ff1 <= {PTR_WIDTH{1'b0}};
            sync_ptr <= {PTR_WIDTH{1'b0}};
        end
        else begin
            sync_ff1 <= async_ptr;
            sync_ptr <= sync_ff1;
        end
    end

endmodule


// =====================================================================
// Dual-port memory array, no reset - qualified externally by
// wr_en/rd_en (which already factor in full/empty/fifo_enable)
// =====================================================================
module fifo_memory #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
)(
    input  wire                  wr_clk,
    input  wire                  wr_en,
    input  wire [ADDR_WIDTH-1:0] wr_addr,
    input  wire [DATA_WIDTH-1:0] wr_data,

    input  wire                  rd_clk,
    input  wire                  rd_en,
    input  wire [ADDR_WIDTH-1:0] rd_addr,
    output reg  [DATA_WIDTH-1:0] rd_data
);

    localparam FIFO_DEPTH = (1 << ADDR_WIDTH);

    reg [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];

    always @(posedge wr_clk) begin
        if (wr_en) begin
            mem[wr_addr] <= wr_data;
        end
    end

    always @(posedge rd_clk) begin
        if (rd_en) begin
            rd_data <= mem[rd_addr];
        end
    end

endmodule


// =====================================================================
// Write-side pointer/full/overflow logic
// =====================================================================
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
            wr_ptr_bin_next =
                wr_ptr_bin + 1'b1;
        else
            wr_ptr_bin_next =
                wr_ptr_bin;
    end

    always @(*) begin
        wr_ptr_gray_next =
            wr_ptr_bin_next ^
            (wr_ptr_bin_next >> 1);
    end

    // full when next write pointer equals read pointer with top two
    // MSBs inverted (Gray-code wrap-around comparison)
    always @(*) begin
        full_compare_ptr =
            rd_ptr_gray_sync;
        full_compare_ptr[ADDR_WIDTH] =
            ~rd_ptr_gray_sync[ADDR_WIDTH];
        full_compare_ptr[ADDR_WIDTH-1] =
            ~rd_ptr_gray_sync[ADDR_WIDTH-1];
    end

    always @(*) begin
        full_next =
            (wr_ptr_gray_next == full_compare_ptr);
    end

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr_bin  <= {ADDR_WIDTH+1{1'b0}};
            wr_ptr_gray <= {ADDR_WIDTH+1{1'b0}};
            full        <= 1'b0;
            overflow    <= 1'b0;
        end
        else if (!fifo_enable) begin
            // held in reset state until the cross-domain handshake completes
            wr_ptr_bin  <= {ADDR_WIDTH+1{1'b0}};
            wr_ptr_gray <= {ADDR_WIDTH+1{1'b0}};
            full        <= 1'b0;
            overflow    <= 1'b0;
        end
        else begin
            wr_ptr_bin  <= wr_ptr_bin_next;
            wr_ptr_gray <= wr_ptr_gray_next;
            full        <= full_next;
            overflow    <= wr_en && full;
        end
    end

    assign wr_addr =
        wr_ptr_bin[ADDR_WIDTH-1:0];

endmodule


// =====================================================================
// Read-side pointer/empty/underflow logic
// =====================================================================
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
            rd_ptr_bin_next =
                rd_ptr_bin + 1'b1;
        else
            rd_ptr_bin_next =
                rd_ptr_bin;
    end

    always @(*) begin
        rd_ptr_gray_next =
            rd_ptr_bin_next ^
            (rd_ptr_bin_next >> 1);
    end

    // empty when next read pointer catches up to the synced write pointer
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
        end
        else if (!fifo_enable) begin
            // held in reset state until the cross-domain handshake completes
            rd_ptr_bin  <= {ADDR_WIDTH+1{1'b0}};
            rd_ptr_gray <= {ADDR_WIDTH+1{1'b0}};
            empty       <= 1'b1;
            underflow   <= 1'b0;
        end
        else begin
            rd_ptr_bin  <= rd_ptr_bin_next;
            rd_ptr_gray <= rd_ptr_gray_next;
            empty       <= empty_next;
            underflow   <= rd_en && empty;
        end
    end

    assign rd_addr =
        rd_ptr_bin[ADDR_WIDTH-1:0];

endmodule
