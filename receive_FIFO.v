module receive_FIFO #(
    parameter DEPTH = 4,
    parameter ADDR_WIDTH = 2
)(
    input  wire         clk, rst_n,
    input  wire         wr_en,
    input  wire         rd_en,
    input  wire [7:0]   data_in,

    output wire         empty,
    output wire         full,
    output reg  [7:0]   data_out
);
    reg [7:0] fifo_mem [0:DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_ptr, rd_ptr;
    reg [ADDR_WIDTH:0] count;

    reg wr_en_d, rd_en_d;               // Dùng để giữ trạng thái trước
    wire wr_en_rising = wr_en && ~wr_en_d;
    wire rd_en_rising = rd_en && ~rd_en_d;

    // Lưu lại trạng thái trước của wr_en, rd_en
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_en_d <= 0;
            rd_en_d <= 0;
        end else begin
            wr_en_d <= wr_en;
            rd_en_d <= rd_en;
        end
    end

    // Ghi dữ liệu vào FIFO
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
        end else if (wr_en_rising && !full) begin
            fifo_mem[wr_ptr] <= data_in;
            wr_ptr           <= wr_ptr + 1;
        end
    end

    // Đọc dữ liệu ra (mỗi khi có cạnh lên)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr   <= 0;
            data_out <= 8'b0;
        end else if (rd_en_rising && !empty) begin
            data_out <= fifo_mem[rd_ptr];
            rd_ptr   <= rd_ptr + 1;
        end
    end

    // Cập nhật số phần tử trong FIFO
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 0;
        end else begin
            case ({wr_en_rising && !full, rd_en_rising && !empty})
                2'b10: count    <= count + 1;  // Ghi
                2'b01: count    <= count - 1;  // Đọc
                default: count  <= count;      // Không đổi
            endcase
        end
    end

    assign empty = (count == 0);
    assign full  = (count == DEPTH);

endmodule
