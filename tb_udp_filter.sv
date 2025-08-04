// tb_udp_filter.sv - Updated testbench with comprehensive directed test cases

// Include the interface definition
`include "packet_if.sv"

module tb_udp_filter;

    // -- Testbench System & Configuration Variables --
    logic         clk;
    logic         reset;
    logic [15:0]  udp_port_to_match; // Filter configuration for the DUT

    // -- Instantiate the Input Interface (for driving data INTO the DUT) --
    packet_if input_stream_if(clk, reset);

    // -- Instantiate the Output Interface (for receiving data FROM the DUT) --
    packet_if output_stream_if(clk, reset);


    // -- Instantiate the Design Under Test (DUT) --
    udp_packet_filter dut (
        .clk(clk),
        .reset(reset),
        .udp_port_to_match(udp_port_to_match),
        .stream_in_if(input_stream_if.DUT),
        .stream_out_if(output_stream_if.DUT)
    );

    // -- Clock Generator --
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period, 100MHz
    end

    // -- Monitor Block: Observes DUT's Output --
    // This block runs concurrently and reports valid output from the DUT.
    always @(posedge clk) begin
        if (!reset) begin
            if (output_stream_if.valid) begin
                $display("Time %0t: DUT -> TB: Valid Output, data_out = 0x%h", $time, output_stream_if.data);
            end
        end
    end

    // --- Helper Task to Send a Packet ---
    task send_packet(bit [7:0] packet_data[]);
        $display("Time %0t: --- Sending Packet (Size: %0d bytes) ---", $time, packet_data.size());
        foreach (packet_data[i]) begin
            @(posedge clk);
            input_stream_if.valid = 1;
            input_stream_if.data = packet_data[i];
            $display("Time %0t: TB -> DUT: Sending byte %0d: 0x%h", $time, i, input_stream_if.data);
        end
        @(posedge clk); // Hold last byte for one cycle, then de-assert valid
        input_stream_if.valid = 0; // Signal end of packet
        input_stream_if.data = 'hx; // 'X' out data when not valid
        $display("Time %0t: Packet send complete.", $time);
    endtask

    // --- Main Test Sequence ---
    initial begin
        // --- Packet Definitions ---
        // Packet to Pass (Dest Port = 1234)
        const bit [7:0] packet_pass[] = {
            // Eth: 14 bytes (0-13)
            'hFF, 'hFF, 'hFF, 'hFF, 'hFF, 'hFF, 'h11, 'h22, 'h33, 'h44, 'h55, 'h66, 'h08, 'h00,
            // IP: 20 bytes (14-33) - Protocol 0x11 (UDP)
            'h45, 'h00, 'h00, 'h26, 'hDE, 'hAD, 'h40, 'h00, 'h40, 'h11, 'hBE, 'hEF, 'h0A, 'h00, 'h00, 'h01, 'h0A, 'h00, 'h00, 'h02,
            // UDP: 8 bytes (34-41) - Dest Port 0x04D2 (1234)
            'hC0, 'hDE, 'h04, 'hD2, 'h00, 'h10, 'h00, 'h00,
            // Payload: 8 bytes (42-49)
            'hDE, 'hAD, 'hBE, 'hEF, 'hFE, 'hED, 'hCA, 'hFE
        }; // Total 50 bytes

        // Packet to Drop (UDP Port Mismatch - Dest Port = 1235)
        const bit [7:0] packet_drop_port_mismatch[] = {
            // Eth: 14 bytes (0-13)
            'hFF, 'hFF, 'hFF, 'hFF, 'hFF, 'hFF, 'h11, 'h22, 'h33, 'h44, 'h55, 'h66, 'h08, 'h00,
            // IP: 20 bytes (14-33) - Protocol 0x11 (UDP)
            'h45, 'h00, 'h00, 'h26, 'hDE, 'hAD, 'h40, 'h00, 'h40, 'h11, 'hBE, 'hEF, 'h0A, 'h00, 'h00, 'h01, 'h0A, 'h00, 'h00, 'h02,
            // UDP: 8 bytes (34-41) - Dest Port 0x04D3 (1235) <-- Mismatched port
            'hC0, 'hDE, 'h04, 'hD3, 'h00, 'h10, 'h00, 'h00,
            // Payload: 8 bytes (42-49)
            'hDE, 'hAD, 'hBE, 'hEF, 'hFE, 'hED, 'hCA, 'hFE
        }; // Total 50 bytes

        // Packet to Drop (Non-IPv4 EtherType - e.g., ARP 0x0806)
        const bit [7:0] packet_drop_non_ipv4[] = {
            'hFF, 'hFF, 'hFF, 'hFF, 'hFF, 'hFF, 'h11, 'h22, 'h33, 'h44, 'h55, 'h66, 'h08, 'h06, // EtherType 0x0806 (ARP)
            'h45, 'h00, 'h00, 'h26, 'hDE, 'hAD, 'h40, 'h00, 'h40, 'h11, 'hBE, 'hEF, 'h0A, 'h00, 'h00, 'h01, 'h0A, 'h00, 'h00, 'h02,
            'hC0, 'hDE, 'h04, 'hD2, 'h00, 'h10, 'h00, 'h00,
            'hDE, 'hAD, 'hBE, 'hEF, 'hFE, 'hED, 'hCA, 'hFE
        }; // Total 50 bytes

        // Packet to Drop (Non-UDP IP Protocol - e.g., ICMP 0x01)
        const bit [7:0] packet_drop_non_udp_ip[] = {
            'hFF, 'hFF, 'hFF, 'hFF, 'hFF, 'hFF, 'h11, 'h22, 'h33, 'h44, 'h55, 'h66, 'h08, 'h00,
            'h45, 'h00, 'h00, 'h26, 'hDE, 'hAD, 'h40, 'h00, 'h40, 'h01, 'hBE, 'hEF, 'h0A, 'h00, 'h00, 'h01, 'h0A, 'h00, 'h00, 'h02, // IP Protocol 0x01 (ICMP)
            'hC0, 'hDE, 'h04, 'hD2, 'h00, 'h10, 'h00, 'h00,
            'hDE, 'hAD, 'hBE, 'hEF, 'hFE, 'hED, 'hCA, 'hFE
        }; // Total 50 bytes

        // Packet to Drop (Runt Frame - ends before full headers parsed)
        const bit [7:0] packet_drop_runt_frame[] = {
            'hFF, 'hFF, 'hFF, 'hFF, 'hFF, 'hFF, 'h11, 'h22, 'h33, 'h44, 'h55, 'h66, 'h08, 'h00, // Ethernet + EtherType
            'h45, 'h00, 'h00, 'h26 // Only part of IP header
        }; // Total 18 bytes

        // Packet to Pass (Longer Payload - testing streaming up to byte_counter limit)
        // Max byte_counter is 63 (6'd63).
        // Eth (14) + IP (20) + UDP (8) + Payload (21) = 63 bytes.
        // So UDP len = 8+21 = 29 (0x001D)
        // IP total len = 20+8+21 = 49 (0x0031)
        const bit [7:0] packet_max_payload[] = { // Adjusted to be 63 bytes total
            // Eth: 14 bytes
            'hFF, 'hFF, 'hFF, 'hFF, 'hFF, 'hFF, 'h11, 'h22, 'h33, 'h44, 'h55, 'h66, 'h08, 'h00,
            // IP: 20 bytes (Total Len: 0x0031 = 49)
            'h45, 'h00, 'h00, 'h31, 'hDE, 'hAD, 'h40, 'h00, 'h40, 'h11, 'hBE, 'hEF, 'h0A, 'h00, 'h00, 'h01, 'h0A, 'h00, 'h00, 'h02,
            // UDP: 8 bytes (Len: 0x001D = 29)
            'hC0, 'hDE, 'h04, 'hD2, 'h00, 'h1D, 'h00, 'h00,
            // Payload: 21 bytes (Bytes 42-62, total 63 bytes in frame)
            'h00, 'h01, 'h02, 'h03, 'h04, 'h05, 'h06, 'h07, 'h08, 'h09, 'h0A, 'h0B, 'h0C, 'h0D, 'h0E, 'h0F, 'h10, 'h11, 'h12, 'h13, 'h14
        }; // Total 63 bytes (matches byte_counter max of 63, index 0 to 62)

        // NEW TEST CASE: Minimum Valid Packet (Eth 14 + IP 20 + UDP 8 + Payload 0 = 42 bytes)
        const bit [7:0] packet_min_valid[] = {
            // Eth: 14 bytes
            'hFF, 'hFF, 'hFF, 'hFF, 'hFF, 'hFF, 'h11, 'h22, 'h33, 'h44, 'h55, 'h66, 'h08, 'h00,
            // IP: 20 bytes (Total Len: 20 IP + 8 UDP + 0 Payload = 28 -> 0x001C)
            'h45, 'h00, 'h00, 'h1C, 'hDE, 'hAD, 'h40, 'h00, 'h40, 'h11, 'hBE, 'hEF, 'h0A, 'h00, 'h00, 'h01, 'h0A, 'h00, 'h00, 'h02,
            // UDP: 8 bytes (Len: 8 UDP + 0 Payload = 8 -> 0x0008)
            'hC0, 'hDE, 'h04, 'hD2, 'h00, 'h08, 'h00, 'h00
            // No payload
        }; // Total 42 bytes

        // NEW TEST CASE: Packet to Drop (IP Header Length != 5 - e.g., IHL=6, 24 bytes)
        const bit [7:0] packet_drop_ihl_not_5[] = {
            // Eth: 14 bytes
            'hFF, 'hFF, 'hFF, 'hFF, 'hFF, 'hFF, 'h11, 'h22, 'h33, 'h44, 'h55, 'h66, 'h08, 'h00,
            // IP: 24 bytes (IHL=6 -> 0x46) - Protocol 0x11 (UDP) - Total Len depends on payload
            'h46, 'h00, 'h00, 'h2E, 'hDE, 'hAD, 'h40, 'h00, 'h40, 'h11, 'hBE, 'hEF, 'h0A, 'h00, 'h00, 'h01, 'h0A, 'h00, 'h00, 'h02,
            'h00, 'h00, 'h00, 'h00, // IP Options (4 bytes)
            // UDP: 8 bytes - Dest Port 0x04D2 (1234)
            'hC0, 'hDE, 'h04, 'hD2, 'h00, 'h10, 'h00, 'h00,
            // Payload: 8 bytes
            'hDE, 'hAD, 'hBE, 'hEF, 'hFE, 'hED, 'hCA, 'hFE
        }; // Total 58 bytes

        // NEW TEST CASE: Packet to Drop (IP Fragmented - MF flag set)
        // Offset non-zero, or MF flag set. Here, setting MF flag (bit 1 of Flags)
        const bit [7:0] packet_drop_ip_fragment[] = {
            // Eth: 14 bytes
            'hFF, 'hFF, 'hFF, 'hFF, 'hFF, 'hFF, 'h11, 'h22, 'h33, 'h44, 'h55, 'h66, 'h08, 'h00,
            // IP: 20 bytes - Flags 0x20 (MF set), Frag Offset 0x0000
            'h45, 'h00, 'h00, 'h26, 'hDE, 'hAD, 'h20, 'h00, 'h40, 'h11, 'hBE, 'hEF, 'h0A, 'h00, 'h00, 'h01, 'h0A, 'h00, 'h00, 'h02,
            // UDP: 8 bytes - Dest Port 0x04D2 (1234)
            'hC0, 'hDE, 'h04, 'hD2, 'h00, 'h10, 'h00, 'h00,
            // Payload: 8 bytes
            'hDE, 'hAD, 'hBE, 'hEF, 'hFE, 'hED, 'hCA, 'hFE
        }; // Total 50 bytes


        // --- Test Scenarios ---

        // 1. Reset the DUT
        reset = 1;
        input_stream_if.valid = 0;
        @(posedge clk);
        @(posedge clk); // Hold reset for 2 cycles
        reset = 0;
        @(posedge clk);
        $display("Time %0t: Reset Released", $time);

        $display("\n --- Test Case 1: Packet to be ACCEPTED (Standard Pass) ---");
        udp_port_to_match = 16'd1234;
        send_packet(packet_pass);
        repeat (50) @(posedge clk); // Give DUT time to process and output

        $display("\n --- Test Case 2: Packet to be DROPPED (Port Mismatch, Port 1235) ---");
        udp_port_to_match = 16'd1234; // Filter still 1234
        send_packet(packet_drop_port_mismatch);
        repeat (50) @(posedge clk);

        $display("\n --- Test Case 3: Packet to be DROPPED (Non-IPv4 EtherType) ---");
        udp_port_to_match = 16'd1234; // Filter still 1234
        send_packet(packet_drop_non_ipv4);
        repeat (50) @(posedge clk);

        $display("\n --- Test Case 4: Packet to be DROPPED (Non-UDP IP Protocol) ---");
        udp_port_to_match = 16'd1234; // Filter still 1234
        send_packet(packet_drop_non_udp_ip);
        repeat (50) @(posedge clk);

        $display("\n --- Test Case 5: Packet to be DROPPED (Runt Frame) ---");
        udp_port_to_match = 16'd1234; // Filter still 1234
        send_packet(packet_drop_runt_frame);
        repeat (50) @(posedge clk);

        $display("\n --- Test Case 6: Packet to be ACCEPTED (Maximum Payload for byte_counter) ---");
        udp_port_to_match = 16'd1234;
        send_packet(packet_max_payload); // New: Max payload packet
        repeat (50) @(posedge clk);

        $display("\n --- Test Case 7: Packet to be ACCEPTED (Minimum Valid Packet) ---");
        udp_port_to_match = 16'd1234;
        send_packet(packet_min_valid); // New: Minimum valid packet
        repeat (50) @(posedge clk);

        

        $display("\n --- Test Case 8: Back-to-Back Packets (Pass followed by Drop) ---");
        udp_port_to_match = 16'd1234;
        send_packet(packet_pass); // First packet (pass)
        repeat (5) @(posedge clk); // Small gap
        send_packet(packet_drop_port_mismatch); // Second packet (drop)
        repeat (50) @(posedge clk);

        // --- Test Case 11: Reset during Packet Transmission ---
        $display("\n--- Test Case 9: Reset During Packet ---");
        udp_port_to_match = 16'd1234;
        send_packet(packet_pass[0+:20]); // Send first 20 bytes
        @(posedge clk);
        $display("Time %0t: Asserting Reset during packet.", $time);
        reset = 1; // Assert reset mid-packet
        @(posedge clk);
        @(posedge clk);
        reset = 0; // De-assert reset
        input_stream_if.valid = 0; // Ensure input is cleared
        input_stream_if.data = 'hx;
        @(posedge clk);
        $display("Time %0t: Sending new packet after mid-packet reset.", $time);
        send_packet(packet_pass); // Send a new valid packet after reset
        repeat (50) @(posedge clk);

        // --- End Simulation ---
        $display("\n--- All Test Cases Finished ---");
        $finish;
    end

endmodule