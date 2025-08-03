// packet_if.sv - SystemVerilog Interface for Packet Streaming
// This interface defines the signals for a simple byte-stream connection,
// suitable for our UDP packet filter.

interface packet_if (input logic clk, input logic reset);

    // Data signals
    logic [7:0] data;
    logic       valid; // Indicates data is present
    logic       ready; // Backpressure signal (not used by your current DUT, but good practice)

    // Modports: Define how modules connect to this interface
    // 1. For the DUT (udp_packet_filter)
    modport DUT (
        input  data,
        input  valid,
        output ready, // DUT asserts ready when it can accept data
        input  clk,
        input  reset
    );

    // 2. For the Testbench (or a driver/monitor within the testbench)
    modport TB (
        output data,
        output valid,
        input  ready, // Testbench observes ready from DUT
        input  clk,
        input  reset
    );

    
    // You can also add clocking blocks or assertions here later if needed.
    // For now, simple direct signals are sufficient for this initial step.

    // Define some useful constants within the interface
    // These constants relate to the structure of an Ethernet + IPv4 + UDP packet.
    localparam ETHER_HDR_LEN    = 14;
    localparam IP_HDR_LEN       = 20; // Assumes fixed 20-byte IP header (no options)
    localparam UDP_HDR_LEN      = 8;

    localparam ETH_TYPE_OFFSET  = 12; // Byte 12, 13
    localparam IP_PROTOCOL_OFFSET = ETHER_HDR_LEN + 9; // Byte 23 (14 + 9)
    localparam UDP_DEST_PORT_OFFSET = ETHER_HDR_LEN + IP_HDR_LEN + 2; // Byte 36, 37 (14 + 20 + 2)

    localparam ETHERTYPE_IPV4   = 16'h0800;
    localparam IP_PROTOCOL_UDP  = 8'h11;

endinterface