module test_bench;
    // Input
    reg sys_clk;
    reg sys_rst_n;
    reg psel;
    reg pwrite;
    reg penable;

    reg [3:0] pstrb;
    reg [11:0] paddr;
    reg [15:0] pwdata;
    reg [15:0] exp_data;

    reg rx;

    // Outputs
    wire tx;
    wire pready;
    wire interrupt;
    wire [15:0] prdata;

    localparam CLK_PERIOD = 20;           // 20ns clock period (50MHz)
    
    // Register address
    localparam DATA_TX  = 12'h00;
    localparam DATA_RX  = 12'h04;
    localparam STATE    = 12'h08;
    localparam CONTROL  = 12'h0C;
    localparam BAUDDIV  = 12'h10;
    localparam IER      = 12'h14;
    localparam ISR      = 12'h18;

    // Common baud rate divisors for 50MHz clock
    localparam BAUD_9600    = 16'd325;    // 50MHz/(16*9600)
    localparam BAUD_19200   = 16'd162;    // 50MHz/(16*19200)
    localparam BAUD_38400   = 16'd81;     // 50MHz/(16*38400)
    localparam BAUD_115200  = 16'd27;     // 50MHz/(16*115200)
    localparam BAUD_460800  = 16'd7;      // 50MHz/(16*460800)
    localparam BAUD_3125000 = 16'd1;      // 50MHz/(16*3125000)

    //Instanstiate the Unit Under Test (UUT)
    top uut (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .psel(psel),
        .pwrite(pwrite),
        .penable(penable),
        .pstrb(pstrb),
        .paddr(paddr),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready),
        .interrupt(interrupt),
        .rx(rx),
        .tx(tx)
    );

    // Test parameters
    reg [31:0] error_count;
    reg [31:0] test_count;

    time last_clock_edge;
    time measured_period;

    // System clock - 50MHz
    initial begin
        sys_clk = 1'b0;
        forever #10 sys_clk = ~sys_clk; // 50MHz - 20ns
    end

    task reset;
        begin
            @(posedge sys_clk);
            sys_rst_n   = 1'b1;
            psel        = 1'b0;
            pwrite      = 1'b0;
            penable     = 1'b0;
            @(posedge sys_clk);
            sys_rst_n   = 1'b0;
            repeat (5) @(posedge sys_clk);
            sys_rst_n   = 1'b1;
            @(posedge sys_clk);
        end
    endtask

// CREATE TASK CHECK MODULE
    task apb_wr;
        input [3:0]     strobe;
        input [11:0]    address;
        input [15:0]    data;
        begin
            @(posedge sys_clk);
            psel    = 1'b1;
            pstrb   = strobe;
            paddr   = address;
            pwrite  = 1'b1;
            pwdata  = data;
            @(posedge sys_clk);
            penable = 1'b1;
            repeat (2) @(posedge sys_clk);
            psel    = 1'b0;
            penable = 1'b0;
            @(posedge sys_clk);
        end
    endtask

    task apb_rd;
        input [11:0] address;
        input [15:0] exp_data;
        begin
            @(posedge sys_clk);
            psel    = 1'b1;
            paddr   = address;
            pwrite  = 1'b0;
            @(posedge sys_clk);
            penable = 1'b1;
            wait (pready);
            #2;
            if (prdata !== exp_data) begin
                $display("[%0t] FAIL: addr: %h - Data: Exp = %h || Act = %h", $time, address, exp_data, prdata);
                error_count = error_count + 1;
            end else begin
                $display("[%0t] PASS: addr: %h - Data: %h", $time, address, prdata);
            end
            @(posedge sys_clk);
            psel        = 1'b0;
            penable     = 1'b0;
            test_count  = test_count + 1;
            @(posedge sys_clk);
        end
    endtask

    task apb_chk;
        input select;
        input write;
        input enable;
        input exp_pready;
        begin
            @(posedge sys_clk);
            psel    = select;
            pwrite  = write;
            penable = 1'b0;
            @(posedge sys_clk);
            penable = enable;
            @(posedge sys_clk);
            #2;
            if (pready !== exp_pready) begin
                $display("[%0t] FAILED - Pready: exp = %b, act = %b", $time, exp_pready, pready);
                error_count = error_count + 1;
            end else begin
                $display("[%0t] PASS - Pready: Value = %b", $time, pready);
            end
            test_count = test_count + 1;
            @(posedge sys_clk);
            psel    = 1'b0;
            penable = 1'b0;
            @(posedge sys_clk);
        end
    endtask

    task reg_wr_rd;
        input [3:0] strobe;
        input [11:0] address;
        input [15:0] data;
        input [15:0] exp_data;
        begin
            apb_wr(strobe, address, data);
            apb_rd(address, exp_data);
        end
    endtask

    task baud_chk;
        input [15:0] baud_div;
        input real expected_freq;
        begin
            @(posedge sys_clk);
            $display("\nTesting Baud Rate: Divisor=%d, Expected Freq=%f Hz", baud_div, expected_freq);
            apb_wr(4'hF, BAUDDIV, baud_div);
            // Wait for stable clock
            #(CLK_PERIOD * 10);
            // Measure actual frequency over multiple cycles
            last_clock_edge = 0;
            @(posedge uut.i_Clock);
            last_clock_edge = $time;
            @(posedge uut.i_Clock);
            measured_period = $time - last_clock_edge;
            // Check if measured frequency matches expected
            if (measured_period != (CLK_PERIOD * baud_div + CLK_PERIOD)) begin
                $display("ERROR: Baud clock period mismatch!");
                $display("Expected: %d ns, Measured: %d ns", CLK_PERIOD * baud_div + CLK_PERIOD, measured_period);
                error_count = error_count + 1;
            end else begin
                $display("Baud clock period correct: %d ns", measured_period);
            end
            test_count = test_count + 1;
            @(posedge sys_clk);
        end
    endtask

    task send_data_to_FIFO;
        input [15:0] data;
        begin
            @(posedge sys_clk);
            apb_wr(4'hF, DATA_TX, data);
            apb_wr(4'hF, CONTROL, 16'h0001);
            apb_wr(4'hF, CONTROL, 16'h0000);
            $display("[%0t] Transmitter data: %h ", $time, data);
        end
    endtask

    task tx_chk;
        input [7:0] data;
        input       parity_mode;
        input       parity_enable;
        reg [10:0]  exp_bits;    // start + 8 data + parity + stop
        reg         parity;
        integer     bit_total;
        integer     i;
        integer     local_error;
        begin
            @(posedge sys_clk);
        // Xây dựng khung dữ liệu mong đợi
            exp_bits[0] = 1'b0;
            for (i=0; i<8; i=i+1) begin
                exp_bits[i+1] = data[i];
            end
            bit_total   = 9;
            if (parity_enable) begin
                parity      = (parity_mode) ? ^data : ~^data;
                exp_bits[9] = parity;
                bit_total   = 10;
            end
            exp_bits[bit_total] = 1'b1;
            bit_total   = bit_total + 1;
        // Check
            @(negedge tx);
            @(posedge uut.i_Clock);
            for (i=0; i<bit_total; i=i+1) begin
                repeat (8) @(posedge uut.i_Clock);
                if (tx !== exp_bits[i]) begin
                    local_error = local_error + 1;
                end
                repeat (8) @(posedge uut.i_Clock);
            end

            if (local_error) begin
                $display("[%0t] Transmitter data FAIL", $time);
                error_count = error_count + 1;
            end else begin
                $display("[%0t] Transmitter data PASS", $time);
            end
            test_count = test_count + 1;
        end
    endtask

    task receive_rx;
        input       parity_enable;
        input       parity_bit;
        input [7:0] data;
        integer     i, n;
        reg [8:0]   data_rx;
        begin
            data_rx = {parity_bit, data};
            n       = parity_enable ? 9 : 8;
            @(posedge uut.i_Clock);
            // Start bit
            rx  = 1'b0;
            repeat (16) @(posedge uut.i_Clock);
            for (i=0; i<n; i=i+1) begin
                rx  = data_rx[i];
                repeat (16) @(posedge uut.i_Clock);
            end
            // Stop bit
            rx  = 1'b1;
            repeat (16) @(posedge uut.i_Clock);
        end
    endtask

    task read_data_rx;
        input [1:0]     parity_mode;   // 00: none, 01: odd, 11: even
        input [15:0]    data_rx;
        reg [15:0] ctrl_val1, ctrl_val2;
        begin
            case (parity_mode)
                2'b00: begin // No parity
                    ctrl_val1 = 16'h0002;
                    ctrl_val2 = 16'h0000;
                end
                2'b01: begin // Odd parity
                    ctrl_val1 = 16'h0006;
                    ctrl_val2 = 16'h0004;
                end
                2'b11: begin // Even parity
                    ctrl_val1 = 16'h000E;
                    ctrl_val2 = 16'h000C;
                end
                default: begin
                    ctrl_val1 = 16'h0002;
                    ctrl_val2 = 16'h0000;
                end
            endcase

            @(posedge sys_clk);
            apb_wr(4'hF, CONTROL, ctrl_val1);
            apb_wr(4'hF, CONTROL, ctrl_val2);
            apb_rd(DATA_RX, data_rx);
            @(posedge sys_clk);
        end
    endtask

    task int_chk;
        input exp_int;
        begin
            @(posedge sys_clk);
            if (interrupt != exp_int) begin
                $display("[%0t] FAIL: Interrupt Test - Expected: %b, Actual: %b", $time, exp_int, interrupt);
                error_count = error_count + 1;
            end else begin
                $display("[%0t] PASS: Interrupt Test - Expected: %b, Actual: %b", $time, exp_int, interrupt);
            end
            // Clear interrupt
            apb_wr(4'hF, ISR, 16'h0001);
            test_count = test_count + 1;
        end
    endtask

// MAIN TEST
    initial begin
        // Initialize
        error_count = 0;
        test_count  = 0;

        rx      = 1;
        psel    = 0;
        pstrb   = 0;
        paddr   = 0;
        pwdata  = 0;
        pwrite  = 0;
        penable = 0;

// APB_SLAVE
        $display("<<<===================================================>>>");
        $display("<<<----------------- APB_SLAVE ----------------------->>>");

        reset();
        $display("-------------------- APB Write --------------------------");
        apb_chk(1'b0, 1'b1, 1'b0, 1'b0);
        apb_chk(1'b0, 1'b1, 1'b1, 1'b0);
        apb_chk(1'b1, 1'b1, 1'b0, 1'b0);
        apb_chk(1'b1, 1'b1, 1'b1, 1'b1);    // Write valid

        $display("-------------------- APB Read ---------------------------");
        apb_chk(1'b0, 1'b0, 1'b0, 1'b0);
        apb_chk(1'b0, 1'b0, 1'b1, 1'b0);
        apb_chk(1'b1, 1'b0, 1'b0, 1'b0);
        apb_chk(1'b1, 1'b0, 1'b1, 1'b1);    // Read valid

        $display("-------------------- Back to Back Write -----------------");
        repeat (3) begin
            apb_chk(1'b1, 1'b1, 1'b1, 1'b1);
        end

        $display("-------------------- Alternating Write-Read -------------");
        repeat (3) begin
            apb_chk(1'b1, 1'b1, 1'b1, 1'b1);
            apb_chk(1'b1, 1'b0, 1'b1, 1'b1);
        end

        $display("-------------------- Reset During Transaction -----------");
        @(posedge sys_clk);
        psel        = 1'b1;
        pwrite      = 1'b1;
        penable     = 1'b0;
        @(posedge sys_clk);
        penable     = 1'b1;
        @(posedge sys_clk);
        sys_rst_n   = 1'b0;         // Reset signal
        @(posedge sys_clk);
        #2;
        if (pready !== 1'b0) begin
            $display("[%0t] FAILED - Pready: exp = %b, act = %b", $time, 1'b0, pready);
            error_count = error_count + 1;
        end else begin
            $display("[%0t] PASS - Pready: Value = %b", $time, pready);
        end
        test_count = test_count + 1;

        $display("---------- Hold PSEL HIGH for Multiple Cycles ----------");
        reset();
        // Check the transaction of write signal when change the input pwrite.
        @(posedge sys_clk);
        psel    = 1'b1;
        pwrite  = 1'b1;
        penable = 1'b0;
        @(posedge sys_clk);
        penable = 1'b1;
        @(posedge sys_clk);
        pwrite  = 1'b0;
        #2;
        if (uut.wr_en !== 1'b1) begin
            $display("[%0t] FAILED - Pwrite: exp = %b, act = %b", $time, 1'b1, uut.wr_en);
            error_count = error_count + 1;
        end else begin
            $display("[%0t] PASS - Pwrite = %b", $time, uut.wr_en);
        end
        test_count = test_count + 1;
        if (pready !== 1'b1) begin
            $display("[%0t] FAILED - Pready: exp = %b, act = %b", $time, 1'b1, pready);
            error_count = error_count + 1;
        end else begin
            $display("[%0t] PASS - Pready = %b", $time, pready);
        end
        test_count = test_count + 1;
        @(posedge sys_clk);
        pwrite  = 1'b1;
        #2;
        if (uut.rd_en !== 1'b1) begin
            $display("[%0t] FAILED - Pread: exp = %b, act = %b", $time, 1'b1, uut.rd_en);
            error_count = error_count + 1;
        end else begin
            $display("[%0t] PASS - Pread = %b", $time, uut.rd_en);
        end
        test_count = test_count + 1;
        if (pready !== 1'b1) begin
            $display("[%0t] FAILED - Pready: exp = %b, act = %b", $time, 1'b1, pready);
            error_count = error_count + 1;
        end else begin
            $display("[%0t] PASS - Pready = %b", $time, pready);
        end
        test_count = test_count + 1;
        @(posedge sys_clk);
        #2;
        if (uut.wr_en !== 1'b1) begin
            $display("[%0t] FAILED - Pwrite: exp = %b, act = %b", $time, 1'b1, uut.wr_en);
            error_count = error_count + 1;
        end else begin
            $display("[%0t] PASS - Pwrite = %b", $time, uut.wr_en);
        end
        test_count = test_count + 1;
        if (pready !== 1'b1) begin
            $display("[%0t] FAILED - Pready: exp = %b, act = %b", $time, 1'b1, pready);
            error_count = error_count + 1;
        end else begin
            $display("[%0t] PASS - Pready = %b", $time, pready);
        end
        test_count = test_count + 1;

// REGISTER
        $display("<<<===================================================>>>");
        $display("<<<----------------- REGISTER ------------------------>>>");
        
        $display("-------------------- RESET VALUE ------------------------");
        reset();
        apb_rd(DATA_TX, 16'h00);
        apb_rd(DATA_RX, 16'h00);
        apb_rd(STATE, 16'h0C);
        apb_rd(CONTROL, 16'h00);
        apb_rd(BAUDDIV, 16'h00);
        apb_rd(IER, 16'h00);
        apb_rd(ISR, 16'h00);

        $display("-------------------- DATA_TX ----------------------------");
        $display("----- Check all change of pstrobe -----");
        reset();
        reg_wr_rd(4'b0000, DATA_TX, 16'h0000, 16'h0000);
        reg_wr_rd(4'b0000, DATA_TX, 16'h5555, 16'h0000);
        reg_wr_rd(4'b0000, DATA_TX, 16'hAAAA, 16'h0000);
        reg_wr_rd(4'b0000, DATA_TX, 16'hFFFF, 16'h0000);

        reg_wr_rd(4'b0001, DATA_TX, 16'h0000, 16'h0000);
        reg_wr_rd(4'b0001, DATA_TX, 16'h5555, 16'h0055);
        reg_wr_rd(4'b0001, DATA_TX, 16'hAAAA, 16'h00AA);
        reg_wr_rd(4'b0001, DATA_TX, 16'hFFFF, 16'h00FF);

        reg_wr_rd(4'b0010, DATA_TX, 16'h0000, 16'h00FF);
        reg_wr_rd(4'b0010, DATA_TX, 16'h5555, 16'h00FF);
        reg_wr_rd(4'b0010, DATA_TX, 16'hAAAA, 16'h00FF);
        reg_wr_rd(4'b0010, DATA_TX, 16'hFFFF, 16'h00FF);

        reg_wr_rd(4'b0100, DATA_TX, 16'h0000, 16'h00FF);
        reg_wr_rd(4'b0100, DATA_TX, 16'h5555, 16'h00FF);
        reg_wr_rd(4'b0100, DATA_TX, 16'hAAAA, 16'h00FF);
        reg_wr_rd(4'b0100, DATA_TX, 16'hFFFF, 16'h00FF);

        reg_wr_rd(4'b1000, DATA_TX, 16'h0000, 16'h00FF);
        reg_wr_rd(4'b1000, DATA_TX, 16'h5555, 16'h00FF);
        reg_wr_rd(4'b1000, DATA_TX, 16'hAAAA, 16'h00FF);
        reg_wr_rd(4'b1000, DATA_TX, 16'hFFFF, 16'h00FF);

        $display("-------------------- BAUDRATE ---------------------------");
        reset();
        reg_wr_rd(4'hF, BAUDDIV, BAUD_9600, BAUD_9600);
        reg_wr_rd(4'hF, BAUDDIV, BAUD_19200, BAUD_19200);
        reg_wr_rd(4'hF, BAUDDIV, BAUD_38400, BAUD_38400);
        reg_wr_rd(4'hF, BAUDDIV, BAUD_115200, BAUD_115200);
        reg_wr_rd(4'hF, BAUDDIV, BAUD_3125000, BAUD_3125000);

        $display("-------------------- IER --------------------------------");
        reset();
        reg_wr_rd(4'hF, IER, 16'h0000, 16'h0000);
        reg_wr_rd(4'hF, IER, 16'h0001, 16'h0001);

// BAUDRATE
        $display("<<<===================================================>>>");
        $display("<<<----------------- BAUDRATE ------------------------>>>");
        reset();
        baud_chk(BAUD_9600, 9600);
        baud_chk(BAUD_19200, 19200);
        baud_chk(BAUD_38400, 38400);
        baud_chk(BAUD_115200, 115200);
        baud_chk(BAUD_460800, 460800);
        baud_chk(BAUD_3125000, 3125000);

// INTERRUPT
        $display("<<<===================================================>>>");
        $display("<<<----------------- INTERRUPT ----------------------->>>");
        reset();
        apb_wr(4'hF, BAUDDIV, BAUD_115200);
        apb_wr(4'hF, IER, 16'h0001);
        $display("----- Initial state - should not trigger interrupt -----");
        int_chk(1'b0);
        $display("----- Interrupt of Send_FIFO -----");
        send_data_to_FIFO(16'h0055);
        send_data_to_FIFO(16'h00A5);
        send_data_to_FIFO(16'h00AA);
        int_chk(1'b1);
        send_data_to_FIFO(16'h00FF);
        int_chk(1'b1);                  // Check when full data in Send_FIFO
        repeat (3) @(posedge sys_clk);
        int_chk(1'b1);                  // Verify interrupt stays asserted while full
        $display("----- Interrupt of Receive_FIFO -----");
        apb_wr(4'hF, BAUDDIV, BAUD_19200);
        receive_rx(0, 1'b0, 8'h37);
        receive_rx(0, 1'b0, 8'h5A);
        receive_rx(0, 1'b0, 8'h74);
        int_chk(1'b0); 
        receive_rx(0, 1'b0, 8'hFF);
        int_chk(1'b1);
        repeat (3) @(posedge sys_clk);
        int_chk(1'b1);


        $display("----- Disable interrupt while FIFO is full -----");
        apb_wr(4'hF, IER, 16'h0000);
        int_chk(1'b0);

// TRANSMITTER
        $display("<<<===================================================>>>");
        $display("<<<----------------- TRANSMITTER --------------------->>>");
        reset();
        @(posedge sys_clk);
        $display("---------- Test with no parity ----------");   
        $display("---------- Set Baudrate ----------");     
        apb_wr(4'hF, BAUDDIV, BAUD_115200);               
        @(posedge sys_clk);
            send_data_to_FIFO(16'h003C);    // Test data
            tx_chk(8'h3C, 0, 0);
        @(posedge sys_clk);
            send_data_to_FIFO(16'h00A7);    // Test data
            tx_chk(8'hA7, 0, 0);
        @(posedge sys_clk);
            send_data_to_FIFO(16'h0019);    // Test data
            tx_chk(8'h19, 0, 0);
        @(posedge sys_clk);
            send_data_to_FIFO(16'h00D2);    // Test data
            tx_chk(8'hD2, 0, 0);
        @(posedge sys_clk);
            send_data_to_FIFO(16'h00A5);    // Alternating pattern
            tx_chk(8'hA5, 0, 0);
        @(posedge sys_clk);
            send_data_to_FIFO(16'h0055);    // 01010101
            tx_chk(8'h55, 0, 0);
        @(posedge sys_clk);
            send_data_to_FIFO(16'h00AA);    // 10101010
            tx_chk(8'hAA, 0, 0);
        @(posedge sys_clk);
            send_data_to_FIFO(16'h00FF);    // All ones
            tx_chk(8'hFF, 0, 0);

        $display("---------- Test with odd parity ----------");
        reset();
        $display("---------- Set Baudrate ----------");
        apb_wr(4'hF, BAUDDIV, BAUD_115200);
        $display("---------- Enable parity ----------");
        apb_wr(4'hF, CONTROL, 16'h0004);    // Enable odd parity
        @(posedge sys_clk);
            send_data_to_FIFO(16'h003C);    // Test data
            tx_chk(8'h3C, 1, 1);
        @(posedge sys_clk);
            send_data_to_FIFO(16'h00A7);    // Test data
            tx_chk(8'hA7, 1, 1);
        @(posedge sys_clk);
            send_data_to_FIFO(16'h0019);    // Test data
            tx_chk(8'h19, 1, 1);
        @(posedge sys_clk);
            send_data_to_FIFO(16'h00D2);    // Test data
            tx_chk(8'hD2, 1, 1);
        @(posedge sys_clk);
            send_data_to_FIFO(16'h0000);    // All zeros
            tx_chk(8'h00, 1, 1);
        @(posedge sys_clk);
            send_data_to_FIFO(16'h00FF);    // All ones
            tx_chk(8'hFF, 1, 1);
        @(posedge sys_clk);
            send_data_to_FIFO(16'h0055);    // Alternating 0-1
            tx_chk(8'h55, 1, 1);
        @(posedge sys_clk);
            send_data_to_FIFO(16'h00AA);    // Alternating 1-0
            tx_chk(8'hAA, 1, 1);
        @(posedge sys_clk);
            send_data_to_FIFO(16'h0080);    // Single 1
            tx_chk(8'h80, 1, 1);
        @(posedge sys_clk);
            send_data_to_FIFO(16'h007F);    // Single 0
            tx_chk(8'h7F, 1, 1);

        $display("---------- Test with even parity ----------");
        reset();
        $display("---------- Set Baudrate ----------");
        apb_wr(4'hF, BAUDDIV, BAUD_115200);
        $display("---------- Enable parity ----------");
        apb_wr(4'hF, CONTROL, 16'h000C);    // Enable even parity
        @(posedge sys_clk);
            send_data_to_FIFO(16'h003C);    // Test data
            tx_chk(8'h3C, 0, 1);
        @(posedge sys_clk);
            send_data_to_FIFO(16'h00A7);    // Test data
            tx_chk(8'hA7, 0, 1);
        @(posedge sys_clk);
            send_data_to_FIFO(16'h0019);    // Test data
            tx_chk(8'h19, 0, 1);
        @(posedge sys_clk);
            send_data_to_FIFO(16'h00D2);    // Test data
            tx_chk(8'hD2, 0, 1);
        @(posedge sys_clk);
            send_data_to_FIFO(16'h0000);    // All zeros
            tx_chk(8'h00, 0, 1);
        @(posedge sys_clk);
            send_data_to_FIFO(16'h00FF);    // All ones
            tx_chk(8'hFF, 0, 1);
        @(posedge sys_clk);
            send_data_to_FIFO(16'h0055);    // Alternating 0-1
            tx_chk(8'h55, 0, 1);
        @(posedge sys_clk);
            send_data_to_FIFO(16'h00AA);    // Alternating 1-0
            tx_chk(8'hAA, 0, 1);
        @(posedge sys_clk);
            send_data_to_FIFO(16'h0080);    // Single 1
            tx_chk(8'h80, 0, 1);
        @(posedge sys_clk);
            send_data_to_FIFO(16'h007F);    // Single 0
            tx_chk(8'h7F, 0, 1);
            
        $display("---------- Test FIFO full condition ----------");
        reset();
        $display("---------- Set Baudrate ----------");
        apb_wr(4'hF, BAUDDIV, BAUD_19200);
        @(posedge sys_clk);
            send_data_to_FIFO(16'h0037);    // Fill FIFO
            tx_chk(8'h37, 0, 0);
            send_data_to_FIFO(16'h005A);
            tx_chk(8'h5A, 0, 0);
            send_data_to_FIFO(16'h0074);
            tx_chk(8'h74, 0, 0);
            send_data_to_FIFO(16'h00FF);
            tx_chk(8'hFF, 0, 0);

// RECEIVER
        $display("<<<===================================================>>>");
        $display("<<<----------------- RECEIVER ------------------------>>>");
        
        $display("------------- Receive data with no parity ---------------");
        $display("----- Alternating Write-Read in Receive_FIFO -----");
        reset();
        apb_wr(4'hF, BAUDDIV, BAUD_115200);
        receive_rx(0, 1'b0, 8'h00);
        read_data_rx(2'b00, 16'h0000);
        receive_rx(0, 1'b0, 8'h55);
        read_data_rx(2'b00, 16'h0055);
        receive_rx(0, 1'b0, 8'hAA);
        read_data_rx(2'b00, 16'h00AA);
        receive_rx(0, 1'b0, 8'hFF);
        read_data_rx(2'b00, 16'h00FF);
        receive_rx(0, 1'b0, 8'h74);
        read_data_rx(2'b00, 16'h0074);
        receive_rx(0, 1'b0, 8'hAF);
        read_data_rx(2'b00, 16'h00AF);
        $display("----- Check write FULL data in FIFO -----");
        reset();
        apb_wr(4'hF, BAUDDIV, BAUD_19200);
        receive_rx(0, 1'b0, 8'h37);
        receive_rx(0, 1'b0, 8'h5A);
        receive_rx(0, 1'b0, 8'h74);
        receive_rx(0, 1'b0, 8'hFF);
        read_data_rx(2'b00, 16'h0037);
        read_data_rx(2'b00, 16'h005A);
        read_data_rx(2'b00, 16'h0074);
        read_data_rx(2'b00, 16'h00FF);
        
        $display("------------- Receive data with Odd parity --------------");
        $display("----- Alternating Write-Read in Receive_FIFO -----");
        reset();
        apb_wr(4'hF, BAUDDIV, BAUD_115200);
        apb_wr(4'hF, CONTROL, 16'h0004);
        receive_rx(1, 1'b1, 8'h3C);
        read_data_rx(2'b01, 16'h003C);
        receive_rx(1, 1'b0, 8'hA7);
        read_data_rx(2'b01, 16'h00A7);
        receive_rx(1, 1'b0, 8'h19);
        read_data_rx(2'b01, 16'h0019);
        receive_rx(1, 1'b1, 8'hD2);
        read_data_rx(2'b01, 16'h00D2);
        $display("----- Check write FULL data in FIFO -----");
        reset();
        apb_wr(4'hF, BAUDDIV, BAUD_19200);
        apb_wr(4'hF, CONTROL, 16'h0004);
        receive_rx(1, 1'b1, 8'hD2);
        receive_rx(1, 1'b0, 8'h19);
        receive_rx(1, 1'b0, 8'hA7);
        receive_rx(1, 1'b1, 8'h3C);
        read_data_rx(2'b01, 16'h00D2);
        read_data_rx(2'b01, 16'h0019);
        read_data_rx(2'b01, 16'h00A7);
        read_data_rx(2'b01, 16'h003C);
        
        $display("------------- Receive data with Even parity -------------");
        $display("----- Alternating Write-Read in Receive_FIFO -----");
        reset();
        apb_wr(4'hF, BAUDDIV, BAUD_115200);
        apb_wr(4'hF, CONTROL, 16'h000C);
        receive_rx(1, 1'b0, 8'h3C);
        read_data_rx(2'b11, 16'h003C);
        receive_rx(1, 1'b1, 8'hA7);
        read_data_rx(2'b11, 16'h00A7);
        receive_rx(1, 1'b1, 8'h19);
        read_data_rx(2'b11, 16'h0019);
        receive_rx(1, 1'b0, 8'hD2);
        read_data_rx(2'b11, 16'h00D2);
        $display("----- Check write FULL data in FIFO -----");
        reset();
        apb_wr(4'hF, BAUDDIV, BAUD_19200);
        apb_wr(4'hF, CONTROL, 16'h000C);
        receive_rx(1, 1'b0, 8'hD2);
        receive_rx(1, 1'b1, 8'h19);
        receive_rx(1, 1'b1, 8'hA7);
        receive_rx(1, 1'b0, 8'h3C);
        read_data_rx(2'b11, 16'h00D2);
        read_data_rx(2'b11, 16'h0019);
        read_data_rx(2'b11, 16'h00A7);
        read_data_rx(2'b11, 16'h003C);

// TEST SUMMARY
        $display("\n========  Test Summary ========");
        $display("Total Tests: %d", test_count);
        $display("Total Errors: %d", error_count);
        if (error_count == 0)
            $display("TEST PASSED");
        else
            $display("TEST FAILED");

        #100;
        $finish;
    end
    
endmodule
