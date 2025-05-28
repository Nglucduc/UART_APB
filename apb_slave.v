module apb_slave(
    input wire sys_clk,
    input wire sys_rst_n,
    input wire psel,
    input wire pwrite,
    input wire penable,

    output reg rd_en,
    output reg wr_en,
    output wire pready
);
    assign pready = (wr_en || rd_en) && penable;

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            wr_en   = 1'b0;
            rd_en   = 1'b0;
        end else begin
            if (psel && penable) begin
                if (pwrite) begin
                    wr_en   = 1'b1;
                    rd_en   = 1'b0;
                end else begin
                    wr_en   = 1'b0;
                    rd_en   = 1'b1;
                end
            end else begin
                wr_en   = 1'b0;
                rd_en   = 1'b0;
            end
        end
    end
endmodule