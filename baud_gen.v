module baud_gen(
    input wire clk,
    input wire rst_n,
    input wire [15:0] baud_div, 
    output reg i_Clock    // Changed to reg since it's driven by flip-flop in diagram
);
    reg [15:0] counter;   // Renamed for clarity

    // Counter logic with increment (+1 in diagram)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 16'b0;
        end else if (counter == baud_div) begin  // Reset condition from comparator
            counter <= 16'b0;
        end else begin
            counter <= counter + 1'b1;  // +1 increment as shown
        end
    end

    // Clock generation (representing the mux and flip-flop in diagram)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i_Clock <= 1'b0;
        end else begin
            i_Clock <= (counter == baud_div);  // Mux selection based on comparison
        end
    end
endmodule