module receiver (
    input wire clk,
    input wire rst_n,
    input wire i_Clock,
    input wire rx,
    input wire parity_mode,     // 1: Even parity, 0: Odd parity
    input wire parity_enable,   // Enable parity check
    output reg rx_done_tick,
    output wire [7:0] data_in_rx,
    output wire error
);

    localparam IDLE   = 3'b000,
               START  = 3'b001,
               DATA   = 3'b010,
               PARITY = 3'b011,
               STOP   = 3'b100;

    reg [2:0] state_r, state_n;
    reg [3:0] s_r, s_n;         // Sample counter (counts to 15)
    reg [2:0] n_r, n_n;         // Bit counter (counts to 7)
    reg [7:0] data_r, data_n;
    reg parity_r, parity_n;
    reg error_r, error_n;

    // Synchronous state and register update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_r      <= IDLE;
            s_r          <= 0;
            n_r          <= 0;
            data_r       <= 0;
            parity_r     <= 0;
            error_r      <= 0;
            rx_done_tick <= 0;
        end else begin
            state_r      <= state_n;
            s_r          <= s_n;
            n_r          <= n_n;
            data_r       <= data_n;
            parity_r     <= parity_n;
            error_r      <= error_n;
            rx_done_tick <= (state_r == STOP) && (s_r == 15) && !error_r;
        end
    end

    // Next-state logic
    always @(*) begin
        state_n   = state_r;
        s_n       = s_r;
        n_n       = n_r;
        data_n    = data_r;
        parity_n  = parity_r;
        error_n   = error_r;

        case (state_r)
            IDLE: begin
                if (rx == 1'b0) begin
                    s_n     = 0;
                    n_n     = 0;
                    state_n = START;
                    error_n = 0;
                end
            end

            START: begin
                if (i_Clock) begin
                    s_n = s_r + 1;
                    if (s_r == 7) begin // middle of start bit
                        s_n     = 0;
                        state_n = DATA;
                    end
                end
            end

            DATA: begin
                if (i_Clock) begin
                    s_n = s_r + 1;
                    if (s_r == 15) begin
                        s_n     = 0;
                        data_n  = {rx, data_r[7:1]};
                        if (n_r == 7)
                            state_n = parity_enable ? PARITY : STOP;
                        else
                            n_n = n_r + 1;
                    end
                end
            end

            PARITY: begin
                if (i_Clock) begin
                    s_n = s_r + 1;
                    if (s_r == 15) begin
                        s_n        = 0;
                        parity_n   = rx;
                        state_n    = STOP;
                        error_n    = (parity_mode) ? (^data_r != rx) : (~^data_r != rx);
                    end
                end
            end

            STOP: begin
                if (i_Clock) begin
                    s_n = s_r + 1;
                    if (s_r == 15) begin
                        s_n     = 0;
                        state_n = IDLE;
                    end
                end
            end
        endcase
    end

    assign data_in_rx = data_r;
    assign error      = error_r;

endmodule
