module transmitter(
    input wire clk,
    input wire i_Clock,
    input wire rst_n,
    input wire empty_tx,
    input wire parity_mode,
    input wire parity_en,
    input wire [7:0] data_tx,
    
    output reg tx_done_tick,
    output wire tx
);
    localparam IDLE   = 3'b000;
    localparam START  = 3'b001;
    localparam DATA   = 3'b010;
    localparam PARITY = 3'b011;
    localparam STOP   = 3'b100;

    reg [2:0] state_r, state_n;
    reg [3:0] s_r, s_n;        // Sample counter (counts to 15)
    reg [2:0] n_r, n_n;        // Bit counter (counts to 7)
    reg [7:0] data_r, data_n;
    reg tx_r, tx_n;
    reg parity_bit;

    // State and register updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_r <= IDLE;
            s_r     <= 0;
            n_r     <= 0;
            data_r  <= 0;
            tx_r    <= 1;
            parity_bit <= 0;
        end else begin
            state_r <= state_n;
            s_r     <= s_n;
            n_r     <= n_n;
            data_r  <= data_n;
            tx_r    <= tx_n;
        end
    end

    // Next state logic - matches diagram transitions
    always @(*) begin
        s_n             = s_r;
        n_n             = n_r;
        tx_n            = tx_r;
        data_n          = data_r;
        state_n         = state_r;
        tx_done_tick    = 1'b0;

        case (state_r)
            IDLE: begin
                tx_n = 1'b1;
                if (empty_tx == 1'b0) begin    // Matches diagram condition
                    state_n     = START;
                    s_n         = 0;
                    data_n      = data_tx;
                    parity_bit  = parity_mode ? ^data_tx : ~^data_tx;
                end
            end

            START: begin
                tx_n = 1'b0;
                if (i_Clock) begin
                    if (s_r == 15) begin
                        state_n = DATA;
                        s_n     = 0;
                        n_n     = 0;
                    end else begin
                        s_n = s_r + 1;
                    end
                end
            end

            DATA: begin
                tx_n = data_r[0];
                if (i_Clock) begin
                    if (s_r == 15) begin
                        s_n = 0;
                        data_n = {1'b0, data_r[7:1]};
                        if (n_r == 7) begin
                            state_n = parity_en ? PARITY : STOP;
                        end else begin
                            n_n = n_r + 1;
                        end
                    end else begin
                        s_n = s_r + 1;
                    end
                end
            end

            PARITY: begin
                tx_n = parity_bit;
                if (i_Clock) begin
                    if (s_r == 15) begin
                        state_n = STOP;
                        s_n     = 0;
                    end else begin
                        s_n     = s_r + 1;
                    end
                end
            end

            STOP: begin
                tx_n = 1'b1;
                if (i_Clock) begin
                    if (s_r == 15) begin
                        s_n             = 0;
                        state_n         = IDLE;
                        tx_done_tick    = 1'b1;
                    end else begin
                        s_n = s_r + 1;
                    end
                end
            end
        endcase
    end

    assign tx = tx_r;
endmodule