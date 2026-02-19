//=====================================================================================
//		UART TX Module
//
//		Parameters:
//			CLK_HZ – clock signal frequency
//			BIT_RATE – UART speed
//			PAYLOAD_BITS - UART data bits
//			STOP_BITS - UART stop bits
//
//		Control signals:
//			clk – clock signal
//			rst_n – reset (Active-Low)
//			uart_tx_en - TX enable
//
//		Data:
//			uart_txd – UART TX signal
//			uart_tx_data - Transmitted data
//
//		UART Status:
//			uart_tx_busy - TX busy signal
//
//=====================================================================================

module uart_tx
#(
	parameter BIT_RATE = 9600,
	parameter CLK_HZ = 50_000_000,
	parameter PAYLOAD_BITS = 8,
	parameter STOP_BITS = 2
)
(
	input clk,
	input rst_n,
	output uart_txd,
	output uart_tx_busy,
	input uart_tx_en,
	input [PAYLOAD_BITS - 1:0] uart_tx_data
);

localparam BIT_P = 1_000_000_000 * 1/BIT_RATE; // Period
localparam CLK_P = 1_000_000_000 * 1/CLK_HZ; // Clock period

localparam CYCLES_PER_BIT = BIT_P/CLK_P; // Number of cycles per bit
localparam COUNT_REG_WIDTH = 1 + $clog2(CYCLES_PER_BIT * STOP_BITS); // Register size to storing bit duration
localparam BIT_COUNT_WIDTH = $clog2(PAYLOAD_BITS); // Register size to bit counter

reg txd_reg; // TX bit register
reg [PAYLOAD_BITS - 1:0] data_to_send; // Transmitted data register
reg [COUNT_REG_WIDTH - 1:0] cycle_counter; // Data bit clock counter
reg [BIT_COUNT_WIDTH:0] bit_counter; // Received bits counter
reg [1:0] cstate, nstate; // Current and next FSM state

//=====================================================================================
// FSM States
//=====================================================================================
localparam IDLE = 0; // Idle state
localparam START = 1; // Start TX state
localparam SEND = 2; // Data transmitting state
localparam STOP = 3; // Stop TX state

//=====================================================================================
// TX busy and output TX signal generation
//=====================================================================================
assign uart_tx_busy = cstate != IDLE;
assign uart_txd = txd_reg;

//=====================================================================================
// Next bit, payload done and stop done signals generation
//=====================================================================================
wire next_bit = cycle_counter == CYCLES_PER_BIT;
wire payload_done = bit_counter == PAYLOAD_BITS;
wire stop_done = bit_counter == STOP_BITS && cstate == STOP;

//=====================================================================================
// FSM, transition to the next state
//=====================================================================================
always @ (posedge clk, negedge rst_n) begin : p_fsm_state
	if (!rst_n) begin
		cstate <= IDLE;
	end
	else begin
		cstate <= nstate;
	end
end

//=====================================================================================
// FSM transition logic
//=====================================================================================
always @ (*) begin : p_n_fsm_state
	case (cstate)
		IDLE : nstate = uart_tx_en ? START : IDLE;
		START : nstate = next_bit ? SEND : START;
		SEND : nstate = payload_done ? STOP : SEND;
		STOP : nstate = stop_done ? IDLE : STOP;
		default : nstate = IDLE;
	endcase
end

//=====================================================================================
// Updating the output data register
//=====================================================================================
integer i = 0;
always @ (posedge clk, negedge rst_n) begin : p_data_to_send
	if (!rst_n) begin
		data_to_send <= {PAYLOAD_BITS{1'b0}};
	end
	else if (cstate == IDLE && uart_tx_en) begin
		data_to_send <= uart_tx_data;
	end
	else if (cstate == SEND && next_bit) begin
		for (i = PAYLOAD_BITS - 2; i >= 0; i = i - 1) begin
			data_to_send[i] <= data_to_send[i + 1];
		end
	end
end

//=====================================================================================
// Increment the bit counter when transitting the next bit
//=====================================================================================
always @ (posedge clk, negedge rst_n) begin : p_bit_counter
	if (!rst_n) begin
		bit_counter <= 4'b0;
	end
	else if (cstate != SEND && cstate != STOP) begin
		bit_counter <= 4'b0;
	end
	else if (cstate == SEND && nstate == STOP) begin
		bit_counter <= 4'b0;
	end
	else if (cstate == STOP && next_bit) begin
		bit_counter <= bit_counter + 1'b1;
	end
	else if (cstate == SEND && next_bit) begin
		bit_counter <= bit_counter + 1'b1;
	end
end

//=====================================================================================
// Data bit clock counter increment
//=====================================================================================
always @ (posedge clk, negedge rst_n) begin : p_cycle_counter
	if (!rst_n) begin
		cycle_counter <= {COUNT_REG_WIDTH{1'b0}};
	end
	else if (next_bit) begin
		cycle_counter <= {COUNT_REG_WIDTH{1'b0}};
	end
	else if (cstate == START || cstate == SEND || cstate == STOP) begin
		cycle_counter <= cycle_counter + 1'b1;
	end
end

//=====================================================================================
// Setting data from a data register to an TX output register
//=====================================================================================
always @ (posedge clk, negedge rst_n) begin : p_txd_reg
	if (!rst_n) begin
		txd_reg <= 1'b1;
	end
	else if (cstate == IDLE) begin
		txd_reg <= 1'b1;
	end
	else if (cstate == START) begin
		txd_reg <= 1'b0;
	end
	else if (cstate == SEND) begin
		txd_reg <= data_to_send[0];
	end
	else if (cstate == STOP) begin
		txd_reg <= 1'b1;
	end
end

endmodule