//=====================================================================================
//		UART RX Module
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
//			uart_rx_en - RX enable
//
//		Data:
//			uart_rxd – UART RX signal
//			uart_rx_data - Received data
//
//		UART Status:
//			uart_rx_valid - the received data is saved
//			uart_rx_break - RX break
//			start_bit_valid - start bit valid signal
//
//=====================================================================================

module uart_rx
#(
	parameter BIT_RATE = 9600,
	parameter CLK_HZ = 50_000_000,
	parameter PAYLOAD_BITS = 8,
	parameter STOP_BITS = 2
)	
(
	input clk,
	input rst_n,
	input uart_rxd,
	input uart_rx_en,
	output uart_rx_break,
	output uart_rx_valid,
	output reg [PAYLOAD_BITS - 1:0] uart_rx_data,
	output start_bit_valid
);


localparam BIT_P = 1_000_000_000 * 1/BIT_RATE; // Period
localparam CLK_P = 1_000_000_000 * 1/CLK_HZ; // Clock period

localparam CYCLES_PER_BIT = BIT_P/CLK_P; // Number of cycles per bit
localparam COUNT_REG_WIDTH = 1 + $clog2(CYCLES_PER_BIT * STOP_BITS); // Register size to storing bit duration
localparam BIT_COUNT_WIDTH = $clog2(PAYLOAD_BITS); // Register size to bit counter

reg rxd_reg, rxd_reg_0; // Synchronizing registers for RX
reg [PAYLOAD_BITS - 1:0] recieved_data; // Data register
reg [COUNT_REG_WIDTH - 1:0] cycle_counter; // Data bit clock counter
reg [BIT_COUNT_WIDTH:0] bit_counter; // Received bits counter
reg bit_sample; // Register for sampling in the middle of the bit
reg [1:0] cstate, nstate; // Current and next FSM state

//=====================================================================================
// FSM States
//=====================================================================================
localparam IDLE = 0; // Idle state
localparam START = 1; // Start RX state
localparam RECV = 2; // Data receiving state
localparam STOP = 3; // Stop RX state

//=====================================================================================
// break and valid generation
//=====================================================================================
assign uart_rx_break = uart_rx_valid && ~|recieved_data; // RX break
assign uart_rx_valid = cstate == STOP && nstate == IDLE; // The data was received

//=====================================================================================
// RX port sinchronization
//=====================================================================================
always @ (posedge clk, negedge rst_n) begin : p_rxd_reg
	if (!rst_n) begin
		rxd_reg <= 1'b1;
		rxd_reg_0 <= 1'b1;
	end
	else if (uart_rx_en) begin
		rxd_reg <= rxd_reg_0;
		rxd_reg_0 <= uart_rxd;
	end
end

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
// RX output register
//=====================================================================================
always @ (posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		uart_rx_data <= {PAYLOAD_BITS{1'b0}};
	end
	else if (cstate == STOP) begin
		uart_rx_data <= recieved_data;
	end
end
//=====================================================================================
// Start bit valid signal generation
//=====================================================================================
assign start_bit_valid = cstate == START && cycle_counter == CYCLES_PER_BIT/2 && rxd_reg != 1'b1;

//=====================================================================================
// Next bit and payload done signals generation
//=====================================================================================
wire next_bit = cstate != STOP && cycle_counter == CYCLES_PER_BIT || cstate == STOP && cycle_counter == CYCLES_PER_BIT * STOP_BITS;
wire payload_done = bit_counter == PAYLOAD_BITS;

//=====================================================================================
// FSM transition logic
//=====================================================================================
always @ (*) begin : p_n_fsm_state
	case (cstate)
		IDLE : nstate = rxd_reg ? IDLE : START;
		START : nstate = cycle_counter == CYCLES_PER_BIT/2 && !start_bit_valid ? IDLE : next_bit ? RECV : START;
		RECV : nstate = payload_done ? STOP : RECV;
		STOP : nstate = next_bit ? IDLE : STOP;
		default : nstate = IDLE;
	endcase
end

//=====================================================================================
// Updating the data register
//=====================================================================================
integer i = 0;
always @ (posedge clk, negedge rst_n) begin : p_recieved_data
	if (!rst_n) begin
		recieved_data <= {PAYLOAD_BITS{1'b0}};
	end
	else if (cstate == IDLE) begin
		recieved_data <= {PAYLOAD_BITS{1'b0}};
	end
	else if (cstate == RECV && next_bit) begin
		recieved_data[PAYLOAD_BITS - 1] <= bit_sample;
		for (i = PAYLOAD_BITS - 2; i >= 0; i = i - 1) begin
			recieved_data[i] <= recieved_data[i + 1];
		end
	end
end

//=====================================================================================
// Increment the bit counter when a new bit is received
//=====================================================================================
always @ (posedge clk, negedge rst_n) begin : p_bit_counter
	if (!rst_n) begin
		bit_counter <= 4'b0;
	end
	else if (cstate != RECV) begin
		bit_counter <= 4'b0;
	end
	else if (cstate == RECV && next_bit) begin
		bit_counter <= bit_counter + 1'b1;
	end
end

//=====================================================================================
// Bit capture at the center of the data bit clock counter
//=====================================================================================
always @ (posedge clk, negedge rst_n) begin : p_bit_sample
	if (!rst_n) begin
		bit_sample <= 1'b0;
	end
	else if (cycle_counter == CYCLES_PER_BIT/2) begin
		bit_sample <= rxd_reg;
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
	else if (cstate == START || cstate == RECV || cstate == STOP) begin
		cycle_counter <= cycle_counter + 1'b1;
	end
end

endmodule