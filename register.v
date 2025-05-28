module register(
    // APB interface signals
    input wire clk, rst_n,
    input wire wr_en,
    input wire rd_en,
    input wire ready,
    input wire [3:0] strb,
    input wire [11:0] addr,
    output reg [15:0] rdata,
    input wire [15:0] wdata,

    // FIFO interface signals
    input wire [7:0] data_out_rx,    // From Receive_FIFO
    input wire full_tx,              // To/From Send_FIFO
    input wire full_rx,              // From Receive_FIFO
    input wire empty_tx,             // To Transmitter
    input wire empty_rx,             // Status
    
    // Control signals
    output reg [7:0] data_tx,        // To Send_FIFO
    output reg [15:0] baud_div,      // To Baud_rate_generator
    output reg tx_enable,            // To Send_FIFO
    output reg rx_enable,            // To Receive_FIFO
    output reg parity_mode,          // To Transmitter/Receiver
    output reg parity_enable,        // To Transmitter/Receiver
    
    // Interrupt handling
    input wire error,                 // From Receiver
    output wire interrupt              // To system
);
	localparam DATA_TX  = 12'h00;
	localparam DATA_RX  = 12'h04;
	localparam STATE    = 12'h08;
	localparam CONTROL  = 12'h0C;
	localparam BAUDDIV  = 12'h10;
	localparam IER      = 12'h14;
	localparam ISR      = 12'h18;
	
	reg ier_reg;  		// Interrupt Enable Register
	reg [2:0] isr_reg;  // Interrupt Status Register
	
	wire int_set;   // Set interrupt
	wire int_clr;   // Clear interrupt
	wire tx_fifo_int, rx_fifo_int, error_int;

	// Wire declarations for register selects
	wire data_tx_wr_sel;
	wire control_wr_sel;
	wire bauddiv_wr_sel;
	wire ier_wr_sel;
	wire isr_wr_sel;

	assign data_tx_wr_sel  = (addr == DATA_TX)  & wr_en;
	assign control_wr_sel  = (addr == CONTROL)  & wr_en;
	assign bauddiv_wr_sel  = (addr == BAUDDIV)  & wr_en;
	assign ier_wr_sel      = (addr == IER)      & wr_en;
	assign isr_wr_sel      = (addr == ISR)      & wr_en;

	// Write operation
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			data_tx <= 8'b0;
		end
		else if (data_tx_wr_sel) begin
			data_tx <= strb[0] ? wdata [7:0] : data_tx;
		end
	end
	
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			tx_enable     <= 1'b0;
			rx_enable     <= 1'b0;
			parity_enable <= 1'b0;
			parity_mode   <= 1'b0;
		end
		else if (control_wr_sel) begin
			tx_enable     <= strb[0]? wdata [0] : tx_enable;
			rx_enable     <= strb[0]? wdata [1] : rx_enable;
			parity_enable <= strb[0]? wdata [2] : parity_enable;
			parity_mode   <= strb[0]? wdata [3] : parity_mode;
		end
	end	
	
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			baud_div <= 16'b0;
		end else if (bauddiv_wr_sel) begin
			baud_div[7:0]  <= strb[0]? wdata [7:0] : baud_div[7:0];
			baud_div[15:8] <= strb[1]? wdata [15:8] : baud_div[15:8];
		end
	end		
	
	//------------------------ Interrupt ----------------------------
	// Interrupt enable/status control
	assign tx_fifo_int = full_tx;
	assign rx_fifo_int = full_rx;
	assign error_int = error;
	assign int_set = tx_fifo_int || rx_fifo_int || error_int;
	assign int_clr = isr_wr_sel && strb[0] && wdata[0];

	// Interrupt enable register
    always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			ier_reg <= 1'b0;
		end else if (ier_wr_sel) begin
			ier_reg <= (strb[0]) ? wdata[0] : ier_reg;
		end
	end

	// Interrupt Status Register control
	always @(posedge clk or negedge rst_n) begin
	    if (!rst_n) begin
	        isr_reg <= 3'b000;
	    end
	    else if (int_clr) begin
	        isr_reg <= 3'b000;
	    end
	    else begin
	        isr_reg[0] <= tx_fifo_int;
	        isr_reg[1] <= rx_fifo_int;
	        isr_reg[2] <= error_int;
	    end
	end
	
	// Generate interrupt signal
	assign interrupt = ier_reg & (|isr_reg);

	// Read operation
	always @(*) begin
		if (rd_en & ready) begin
			case (addr)
				DATA_TX	:    rdata = {8'b0,  data_tx};
				DATA_RX	:    rdata = {8'b0,  data_out_rx};
				STATE	:    rdata = {12'h0, empty_rx, empty_tx, full_rx, full_tx};
				CONTROL	:    rdata = {12'h0, parity_mode, parity_enable, rx_enable, tx_enable};				
				BAUDDIV	:    rdata = baud_div;
				IER		:    rdata = {15'h0, ier_reg};
				ISR		:    rdata = {13'h0, isr_reg};
				default	:    rdata = 16'b0;
			endcase
		end else begin
			rdata = 16'b0;
		end
	end

endmodule