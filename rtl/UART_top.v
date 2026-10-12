//=====================================================================================
//		UART Top Level Module
//
//		Parameters:
//			CLK_HZ – clock signal frequency
//			BIT_RATE – UART speed
//			PAYLOAD_BITS - UART data bits
//			STOP_BITS - UART stop bits
//			PARITY_ENABLE - parity bit (0 - disable, 1 - enable)
//			PARITY_TYPE - parity type (0 - even, 1 - odd)
//
//		Control signals:
//			clk – clock signal
//			rst_n – reset (Active-Low)
//			uart_tx_en – TX start
//
//		Data:
//			uart_rxd – UART RX signal
//			uart_txd – UART TX signal
//			uart_rx_data - Received data
//			uart_tx_data - Transmitted data
//
//		UART Status:
//			uart_tx_busy – data transfer is in progress
//			uart_rx_valid - the received data is saved
//			uart_rx_break - RX break
//			uart_rx_parity_error - RX parity error
//			start_bit_valid - start bit valid signal
//
//=====================================================================================

module UART_top
#(
	parameter CLK_HZ = 50_000_000,
	parameter BIT_RATE = 256000,
	parameter PAYLOAD_BITS = 8,
	parameter STOP_BITS = 1,
	parameter PARITY_ENABLE = 1,
	parameter PARITY_TYPE = 0
)
(
	input clk,
	input rst_n,
	input uart_rxd,
	input [PAYLOAD_BITS - 1:0] uart_tx_data,
	input uart_tx_en,
	output uart_txd,
	output uart_tx_busy,
	output uart_rx_valid,
	output uart_rx_break,
	output uart_rx_parity_error,
	output [PAYLOAD_BITS - 1:0] uart_rx_data,
	output start_bit_valid
);

//=====================================================================================
// UART RX module
//=====================================================================================
uart_rx #(.BIT_RATE(BIT_RATE), .PAYLOAD_BITS(PAYLOAD_BITS), .CLK_HZ(CLK_HZ), .STOP_BITS(STOP_BITS), .PARITY_ENABLE(PARITY_ENABLE), .PARITY_TYPE(PARITY_TYPE)) i_uart_rx // Reciever
(
	.clk(clk),
	.rst_n(rst_n),
	.uart_rxd(uart_rxd),
	.uart_rx_en(1'b1),
	.uart_rx_break(uart_rx_break),
	.uart_rx_valid(uart_rx_valid),
	.uart_rx_parity_error(uart_rx_parity_error),
	.uart_rx_data(uart_rx_data),
	.start_bit_valid(start_bit_valid)
);

//=====================================================================================
// UART TX module
//=====================================================================================
uart_tx #(.BIT_RATE(BIT_RATE), .PAYLOAD_BITS(PAYLOAD_BITS), .CLK_HZ(CLK_HZ), .STOP_BITS(STOP_BITS), .PARITY_ENABLE(PARITY_ENABLE), .PARITY_TYPE(PARITY_TYPE)) i_uart_tx // Transmitter
(
	.clk(clk),
	.rst_n(rst_n),
	.uart_txd(uart_txd),
	.uart_tx_en(uart_tx_en),
	.uart_tx_busy(uart_tx_busy),
	.uart_tx_data(uart_tx_data)
);

endmodule