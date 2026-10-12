`timescale 1 ns / 100 ps

//=====================================================================================
//		UART Testbench Module
//
//		The module first receives a data packet and then sends the same data packet.
//		The correctness of the transmission can be verified by monitoring the waveforms of the uart_rxd and uart_txd signals.
//		Waveforms of the start_bit_valid, uart_rx_valid, uart_tx_en and uart_tx_busy signals can also be output to detect the receive and transmission processes.
//
//=====================================================================================

module testbench;

//=====================================================================================
// Testbench parameters
//=====================================================================================
parameter CYCLES = 20;
parameter RESET_CYCLES = 10;

parameter CLK_HZ = 50_000_000; // Clock signal frequency
parameter BIT_RATE = 256000; // UART speed
parameter PAYLOAD_BITS = 8; // UART data bits
parameter STOP_BITS = 1; // UART stop bits
parameter PARITY_ENABLE = 1; // Parity bit
parameter PARITY_TYPE = 0; // Parity type

localparam BIT_P = 1_000_000_000 * 1/BIT_RATE; // Period
localparam CLK_P = 1_000_000_000 * 1/CLK_HZ; // Clock period
localparam CYCLES_PER_BIT = BIT_P/CLK_P; // Number of cycles per bit

//=====================================================================================
// Testbench signals
//=====================================================================================
logic clk;
logic rst_n;
logic [PAYLOAD_BITS - 1:0] uart_tx_data;
logic uart_tx_en;
logic uart_rxd;
logic uart_txd;
logic uart_tx_busy;
logic uart_rx_valid;
logic uart_rx_break;
logic uart_rx_parity_error;
logic [PAYLOAD_BITS - 1:0] uart_rx_data;
logic start_bit_valid;

logic [PAYLOAD_BITS - 1:0] data_to_receiver;
logic [PAYLOAD_BITS - 1:0] data_to_receiver_temp [0:1];
logic [PAYLOAD_BITS - 1:0] data_from_receiver;

int errors;

//=====================================================================================
// UART Top Level Module Instantiation with parameters
//=====================================================================================
UART_top #(.CLK_HZ(CLK_HZ), .BIT_RATE(BIT_RATE), .PAYLOAD_BITS(PAYLOAD_BITS), .STOP_BITS(STOP_BITS), .PARITY_ENABLE(PARITY_ENABLE), .PARITY_TYPE(PARITY_TYPE)) top
(
	.clk(clk),
	.rst_n(rst_n),
	.uart_rxd(uart_rxd),
	.uart_tx_data(uart_tx_data),
	.uart_tx_en(uart_tx_en),
	.uart_txd(uart_txd),
	.uart_tx_busy(uart_tx_busy),
	.uart_rx_valid(uart_rx_valid),
	.uart_rx_break(uart_rx_break),
	.uart_rx_parity_error(uart_rx_parity_error),
	.uart_rx_data(uart_rx_data),
	.start_bit_valid(start_bit_valid)
);

//=====================================================================================
// Clock signal generation
//=====================================================================================
initial begin
	clk = 0;
	forever clk = #(CLK_P/2) ~clk;
end

//=====================================================================================
// Receiving and Transmitting Data Task
//=====================================================================================
task automatic data_transfer (input logic [PAYLOAD_BITS - 1:0] data_rx, output logic [PAYLOAD_BITS - 1:0] data_tx);
	realtime start_uart, stop_uart;
	real speed;
	int i, j;
	logic parity_rx_calc;
	logic tx_parity_sampled;
	
	@(posedge clk);
	uart_tx_data = uart_rx_data;
	uart_tx_en = 1;
	@(posedge clk);
	uart_tx_en = 0;
	
	start_uart = $realtime;
	
//-------------------------------------------------------------------------------------
// Start bit
	for (j = 0; j < CYCLES_PER_BIT; j++) begin
		uart_rxd = 1'b0;
		@(posedge clk);
	end

//-------------------------------------------------------------------------------------
// Payload bits	
	for (i = 0; i < PAYLOAD_BITS; i++) begin
		for (j = 0; j < CYCLES_PER_BIT; j++) begin
			uart_rxd = data_rx[i];
			@(posedge clk);
			if (j == CYCLES_PER_BIT/2) begin
				data_tx = {uart_txd, data_tx[PAYLOAD_BITS - 1:1]};
			end
		end
	end
//-------------------------------------------------------------------------------------
// Parity bit
	if (PARITY_ENABLE) begin
		parity_rx_calc = (PARITY_TYPE == 0) ? ^data_rx : ~^data_rx;
		for (j = 0; j < CYCLES_PER_BIT; j++) begin
			uart_rxd = parity_rx_calc;
			@(posedge clk);
			if (j == CYCLES_PER_BIT / 2) begin
				tx_parity_sampled = uart_txd;
			end
		end
	end
	
//-------------------------------------------------------------------------------------
// Stop bits
	for (i = 0; i < STOP_BITS; i++) begin
		for (j = 0; j < CYCLES_PER_BIT; j++) begin
			uart_rxd = 1'b1;
			@(posedge clk);
		end
	end
	
	wait (uart_rx_valid);
	wait (!uart_tx_busy);
	stop_uart = $realtime;
	speed = 1_000_000_000.0 * (1 + PAYLOAD_BITS + (PARITY_ENABLE ? 1 : 0) + STOP_BITS)/(stop_uart - start_uart);

//-------------------------------------------------------------------------------------
// Check RX data	
	if (data_rx == uart_rx_data) begin
		$display("[%0t] [SUCCESS] Data to Receiver: %0b; Received Data: %0b.", $time, data_rx, uart_rx_data);
	end
	else begin
		$display("[%0t] [ERROR] Data to Receiver: %0b; Received Data: %0b.", $time, data_rx, uart_rx_data);
		errors++;
	end
	
//-------------------------------------------------------------------------------------
//	Check RX Parity Error flag
	if (PARITY_ENABLE && uart_rx_parity_error) begin
		$display("[%0t] [ERROR] Unexpected parity error flag on RX.", $time);
		errors++;
	end

//-------------------------------------------------------------------------------------
// Check TX data	
	data_to_receiver_temp[1] = data_to_receiver_temp[0];
	if (data_tx == data_to_receiver_temp[1]) begin
		$display("[%0t] [SUCCESS] Data from Receiver: %0b; Expected Data: %0b.", $time, data_tx, data_to_receiver_temp[1]);
	end
	else begin
		$display("[%0t] [ERROR] Data from Receiver: %0b; Expected Data: %0b.", $time, data_tx, data_to_receiver_temp[1]);
		errors++;
	end

//-------------------------------------------------------------------------------------
// Check TX Parity Bit
	if (PARITY_ENABLE) begin
		logic expected_tx_parity;
		expected_tx_parity = (PARITY_TYPE == 0) ? ^data_to_receiver_temp[1] : ~^data_to_receiver_temp[1];
		if (tx_parity_sampled == expected_tx_parity) begin
			$display("[%0t] [SUCCESS] TX Parity bit: %0b; Expected: %0b.", $time, tx_parity_sampled, expected_tx_parity);
		end
		else begin
			$display("[%0t] [ERROR] TX Parity bit: %0b; Expected: %0b.", $time, tx_parity_sampled, expected_tx_parity);
			errors++;
		end
	end

//-------------------------------------------------------------------------------------
// Check Baud Rate	
	if (speed > BIT_RATE * 0.95 && speed < BIT_RATE * 1.05) begin
		$display("[%0t] [SUCCESS] Baud Rate = %0d, correct.", $time, speed);
	end
	else begin
		$display("[%0t] [ERROR] Baud Rate = %0d, incorrect.", $time, speed);
		errors++;
	end
endtask

//=====================================================================================
// Setting test environment signals
//=====================================================================================
initial begin
	$display("\n\nSTARTING TESTBENCH FOR UART (BIT_RATE = %0d, PAYLOAD_BITS = %0d, STOP_BITS = %0d, PARITY_ENABLE = %0d, PARITY_TYPE = %0d)", BIT_RATE, PAYLOAD_BITS, STOP_BITS, PARITY_ENABLE, PARITY_TYPE);
	rst_n = 0;
	uart_rxd = 1;
	uart_tx_en = 0;
	uart_tx_data = 0;
	data_from_receiver = 0;
	data_to_receiver = 0;
	data_to_receiver_temp[0] = 0;
	data_to_receiver_temp[1] = 0;
	errors = 0;
	
	repeat (RESET_CYCLES) begin
		@(posedge clk);
	end
	rst_n = 1'b1;
	
	$display("\n\n=================================START OF TRANSMISSION=================================");
	repeat (CYCLES) begin
		data_to_receiver_temp[0] = data_to_receiver;
		data_to_receiver = $urandom();
		data_transfer(data_to_receiver, data_from_receiver);
	end
	
	if (errors > 0) begin
		$display("\n\n[%0t] [FAIL] TESTS FAILED! %0d errors detected!", $time, errors);
	end
	else begin
		$display("\n\n[%0t] [PASS] UART MODULE TESTS PASSED!", $time);
	end
	$stop;
	
end

endmodule