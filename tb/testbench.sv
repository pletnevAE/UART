`timescale 1 ns / 100 ps

//=====================================================================================
//		UART Testbench Module
//
//		The module first receives a data packet and then sends the same data packet.
//		Receive and transmission are repeated 4 times.
//		The correctness of the transmission can be verified by monitoring the waveforms of the uart_rxd and uart_txd signals.
//		Waveforms of the start_bit_valid, uart_rx_valid, uart_tx_en and uart_tx_busy signals can also be output to detect the receive and transmission processes.
//
//=====================================================================================

module testbench;

//=====================================================================================
// Testbench parameters
//=====================================================================================
parameter Tt = 20; // Clock period
parameter CYCLES = 20;

parameter CLK_HZ = 50_000_000; // Clock signal frequency
parameter BIT_RATE = 256000; // UART speed
parameter PAYLOAD_BITS = 8; // UART data bits
parameter STOP_BITS = 1; // UART stop bits

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
logic [PAYLOAD_BITS - 1:0] uart_rx_data;
logic start_bit_valid;

logic [PAYLOAD_BITS - 1:0] data_to_receiver;
logic [PAYLOAD_BITS - 1:0] data_to_receiver_temp [0:1];
logic [PAYLOAD_BITS - 1:0] data_from_receiver;

int errors;

//=====================================================================================
// UART Top Level Module Instantiation with parameters
//=====================================================================================
UART_top #(.CLK_HZ(CLK_HZ), .BIT_RATE(BIT_RATE), .PAYLOAD_BITS(PAYLOAD_BITS), .STOP_BITS(STOP_BITS)) top
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
	.uart_rx_data(uart_rx_data),
	.start_bit_valid(start_bit_valid)
);

//=====================================================================================
// Clock signal generation
//=====================================================================================
initial begin
	clk = 0;
	forever clk = #(Tt/2) ~clk;
end

//=====================================================================================
// Receiving and Transmitting Data Task
//=====================================================================================
task automatic data_transfer (input logic [PAYLOAD_BITS - 1:0] data_rx, output logic [PAYLOAD_BITS - 1:0] data_tx);
	realtime start_uart, stop_uart;
	real speed;
	int i, j;
	@(posedge clk);
	uart_tx_data = uart_rx_data;
	uart_tx_en = 1;
	@(posedge clk);
	uart_tx_en = 0;
	
	start_uart = $realtime;
	
	for (j = 0; j < CYCLES_PER_BIT; j++) begin
		uart_rxd = 1'b0;
		@(posedge clk);
	end
	
	for (i = 0; i < PAYLOAD_BITS; i++) begin
		for (j = 0; j < CYCLES_PER_BIT; j++) begin
			uart_rxd = data_rx[i];
			@(posedge clk);
			if (j == CYCLES_PER_BIT/2) begin
				data_tx = {uart_txd, data_tx[PAYLOAD_BITS - 1:1]};
			end
		end
	end
	for (i = 0; i < STOP_BITS; i++) begin
		for (j = 0; j < CYCLES_PER_BIT; j++) begin
			uart_rxd = 1'b1;
			@(posedge clk);
		end
	end
	
	wait (uart_rx_valid);
	wait (!uart_tx_busy);
	stop_uart = $realtime;
	speed = 1_000_000_000.0 * (1 + PAYLOAD_BITS + STOP_BITS)/(stop_uart - start_uart);
	
	if (data_rx == uart_rx_data) begin
		$display("[%0t] SUCCESS: Data to Receiver: %0b; Received Data: %0b.", $time, data_rx, uart_rx_data);
	end
	else begin
		$display("[%0t] ERROR: Data to Receiver: %0b; Received Data: %0b.", $time, data_rx, uart_rx_data);
		errors++;
	end
	
	data_to_receiver_temp[1] = data_to_receiver_temp[0];
	if (data_tx == data_to_receiver_temp[1]) begin
		$display("[%0t] SUCCESS: Data from Receiver: %0b; Expected Data: %0b.", $time, data_tx, data_to_receiver_temp[1]);
	end
	else begin
		$display("[%0t] ERROR: Data from Receiver: %0b; Expected Data: %0b.", $time, data_tx, data_to_receiver_temp[1]);
		errors++;
	end
	
	if (speed > BIT_RATE * 0.95 && speed < BIT_RATE * 1.05) begin
		$display("[%0t] SUCCESS: Baud Rate = %0d, correct.", $time, speed);
	end
	else begin
		$display("[%0t] ERROR: Baud Rate = %0d, incorrect.", $time, speed);
		errors++;
	end
endtask

//=====================================================================================
// Setting test environment signals
//=====================================================================================
initial begin
	rst_n = 0;
	uart_rxd = 1;
	uart_tx_en = 0;
	uart_tx_data = 0;
	data_from_receiver = 0;
	data_to_receiver = 0;
	data_to_receiver_temp[0] = 0;
	data_to_receiver_temp[1] = 0;
	
	repeat(2) @(posedge clk);
	rst_n = 1;
	
	$display("\n\n=================================START OF TRANSMISSION=================================");
	repeat (CYCLES) begin
		data_to_receiver_temp[0] = data_to_receiver;
		data_to_receiver = $urandom();
		data_transfer(data_to_receiver, data_from_receiver);
	end
	
	if (errors > 0) begin
		$display("\n\n[%0t] TESTS FAILED! %0d errors detected!", $time, errors);
	end
	else begin
		$display("\n\n[%0t] UART MODULE TESTS PASSED!", $time);
	end
	$stop;
	
end

endmodule