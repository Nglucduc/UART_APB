module top(
    // APB interface signals
    input  wire sys_clk,
    input  wire sys_rst_n,
    input  wire psel,
    input  wire pwrite,
    input  wire penable,
    input  wire [3:0] pstrb,
    input  wire [11:0] paddr,
    input  wire [15:0] pwdata,
    output wire [15:0] prdata,
    output wire pready,
    output wire interrupt,
    
    // UART interface
    input  wire rx,
    output wire tx
);
    // Internal signals for register file
    wire tx_enable;
    wire rx_enable;
    wire parity_mode;
    wire parity_enable;
    wire [7:0] data_tx;
    wire [15:0] baud_div;
    
    // FIFO signals
    wire tx_done_tick;
    wire full_tx;
    wire empty_tx;
    wire [7:0] data_out_tx;
    
    wire rx_done_tick;
    wire full_rx;
    wire empty_rx;
    wire [7:0] data_in_rx;
    wire [7:0] data_out_rx;
    
    // Other control signals
    wire rd_en, wr_en;
    wire i_Clock;
    wire error;
    
    // Interrupt control signals
    wire ier_wr_sel;
    wire isr_wr_sel;
    wire [0:0] int_wdata;
    wire [0:0] int_strb;

    // APB Slave interface
    apb_slave u_apb_slave (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .psel(psel),
        .pwrite(pwrite),
        .penable(penable),
        .rd_en(rd_en),
        .wr_en(wr_en),
        .pready(pready)
    );

    // Register file for control and status
    register u_register (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .addr(paddr),
        .wdata(pwdata),
        .strb(pstrb),
        .data_out_rx(data_out_rx),
        .full_tx(full_tx),
        .full_rx(full_rx),
        .empty_tx(empty_tx),
        .empty_rx(empty_rx),
        .ready(pready),
        .rdata(prdata),
        .interrupt(interrupt),
        .error(error),
        .baud_div(baud_div),
        .tx_enable(tx_enable),
        .rx_enable(rx_enable),
        .data_tx(data_tx),
        .parity_mode(parity_mode),
        .parity_enable(parity_enable)
    );

    // Baud rate generator
    baud_gen u_baud_gen (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .baud_div(baud_div),
        .i_Clock(i_Clock)
    );

    // Transmit FIFO
    send_FIFO u_send_FIFO (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .wr_en(tx_enable),
        .rd_en(tx_done_tick),
        .data_in(data_tx),
        .empty(empty_tx),
        .full(full_tx),
        .data_out(data_out_tx)
    );

    // Transmitter module
    transmitter u_transmitter (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .i_Clock(i_Clock),
        .empty_tx(empty_tx),
        .parity_mode(parity_mode),
        .parity_en(parity_enable),
        .data_tx(data_out_tx),
        .tx_done_tick(tx_done_tick),
        .tx(tx)
    );

    // Receive FIFO
    receive_FIFO u_receive_FIFO (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .wr_en(rx_done_tick),
        .rd_en(rx_enable),
        .data_in(data_in_rx),
        .empty(empty_rx),
        .full(full_rx),
        .data_out(data_out_rx)
    );

    // Receiver module
    receiver u_receiver (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .i_Clock(i_Clock),
        .rx(rx),
        .parity_mode(parity_mode),
        .parity_enable(parity_enable),
        .rx_done_tick(rx_done_tick),
        .data_in_rx(data_in_rx),
        .error(error)
    );

endmodule