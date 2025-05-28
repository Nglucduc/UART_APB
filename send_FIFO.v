module send_FIFO (
    input wire clk, rst_n,
    input wire wr_en,
    input wire rd_en,
    input wire [7:0] data_in,

    output wire empty,
    output wire full,
    output wire [7:0] data_out
);

    // FIFO depth
    localparam DEPTH = 4;
    localparam ADDR_WIDTH = 2; // log2(DEPTH)

    // FIFO memory
    reg [7:0] fifo_mem [DEPTH-1:0];

    // Read and Write pointers
    reg [ADDR_WIDTH-1:0] wr_ptr, rd_ptr;

    // Counter to track number of elements
    reg [ADDR_WIDTH:0] fifo_count;

    // Output register
    reg [7:0] data_out_reg;
    assign data_out = data_out_reg;

    // Status flags
    assign empty = (fifo_count == 0);
    assign full  = (fifo_count == DEPTH);

    // Write logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
        end else if (wr_en && !full) begin
            fifo_mem[wr_ptr] <= data_in;
            wr_ptr           <= wr_ptr + 1;
        end
    end

    // Read logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr       <= 0;
            data_out_reg <= 8'd0;
        end else begin
            if (!empty) begin
                data_out_reg <= fifo_mem[rd_ptr];
            end
            if (rd_en && !empty) begin
                rd_ptr       <= rd_ptr + 1;
            end
        end
    end

    // FIFO counter logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_count <= 0;
        end else begin
            case ({wr_en && !full, rd_en && !empty})
                2'b10: fifo_count   <= fifo_count + 1; // write only
                2'b01: fifo_count   <= fifo_count - 1; // read only
                default: fifo_count <= fifo_count;   // no change or both (write+read)
            endcase
        end
    end

endmodule