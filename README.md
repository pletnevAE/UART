# UART
The **UART** transceiver module implements a parameterized serial communication interface (TTL/RC-232). Data transmission is supported in full-duplex, half-duplex and simplex modes.

![alt text](img/UART.png)

Typical applications:
+ Receiving and transmitting data from a terminal or microcontroller;
+ Logging and debugging;
+ Communication between boards or modules within an FPGA-based system.

Clone the Repo:
```
git clone https://github.com/pletnevAE/UART.git
```

## Project Hierarchy
+ **UART_top.v** - top-level UART module;
+ **uart_rx.v** - UART receiver;
+ **uart_tx.v** - UART transmitter;
+ **testbench.sv** - testbench module;
+ **UART.sdc** - SDC constraints file.

## Architecture
The module implements a UART transceiver in which:
+ The top-level module instantiates separate receiver and transmitter modules;
+ The baud rate, payload size, and number of stop bits are parameterized;
+ Data reception and transmission are controlled by FSMs;
+ The receiver includes start-bit validation logic;
+ Incoming data is sampled at the middle of each bit period;
+ Bit transmission and reception order is from LSB to MSB.

## Interface
### Parameters:
+ `CLK_HZ` - `clk` frequency;
+ `BIT_RATE` - baud rate;
+ `PAYLOAD_BITS` - number of transmitted/received data bits;
+ `STOP_BITS` - number of stop bits.
### Input Signals:
+ `clk` - Clock Signal;
+ `rst_n` - Asynchronous Active-Low Reset;
+ `uart_rxd` - UART RX Signal;
+ `uart_tx_data` - data to be transmitted from the FPGA;
+ `uart_tx_en` - transmission enable signal from the FPGA.
### Output Signals:
+ `uart_txd` - UART TX signal;
+ `uart_tx_busy` - transmitter busy indicator;
+ `uart_rx_valid` - reception complete indicator;
+ `uart_rx_break` - reception break signal;
+ `uart_rx_data` - received data;
+ `start_bit_valid` - start-bit validation signal.

## Utilization
The project was synthesized for the 10M50DAF484C6GES FPGA on the DE10-Lite board using Quartus 22.1 Standard Edition. For `CLK_HZ = 50000000`, `BIT_RATE = 256000`, `PAYLOAD_BITS = 8`, `STOP_BITS = 1`, without additional optimization modes, the following results were obtained:
| FPGA | LUT | FF | Fmax, MHz | Hold Slack, ns | Setup Slack, ns |
|:--:|:--:|:--:|:--:|:--:|:--:|
| 10M50DAF484C6GES | 106 | 62 | 226.3 | 0.331 | 15.581 |

## Simulation
Simulation was performed in ModelSim 10.6d. The **testbench.sv** file emulates full-duplex UART communication using random data packets. Data received during a previous transmission is sent back by the transmitter during the next transmission cycle. The testbench checks the correctness of received and sent data, as well as checks the data transfer speed, and displays messages about successful/unsuccessful transfer in the console.
The number of verification cycles is defined by the `CYCLES` variable in the testbench.

If errors are detected, the total number of errors is printed at the end of the simulation.

If testing is successful, the following message is displayed in the console:
```
UART MODULE TESTS PASSED!
```
Waveforms window:
![alt text](img/waveforms.png)