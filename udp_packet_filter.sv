// udp_packet_filter.sv - REVISION 3 (Recommended) for byte_counter and FSM transitions
/**
 * Module: udp_packet_filter - Filters UDP packets based on destination port.
 * Designed for low-latency market data processing.
 */
module udp_packet_filter (
    // --- System Inputs ---
    input  logic         clk,
    input  logic         reset,
    // --- Configuration ---
    input  logic [15:0]  udp_port_to_match,
    // --- Data Stream Interfaces ---
    packet_if.DUT stream_in_if,
    packet_if.DUT stream_out_if
);

    logic [7:0]   data_out_internal;
    logic         valid_out_internal;

    assign stream_out_if.data  = data_out_internal;
    assign stream_out_if.valid = valid_out_internal;

    assign stream_in_if.ready = 1'b1; // Always ready for simplicity


    typedef enum logic [2:0] {
        S_IDLE,
        S_PARSE_ETH_HEADER,
        S_PARSE_IP_HEADER,
        S_PARSE_UDP_HEADER,
        S_STREAM_PAYLOAD,
        S_DROP_PACKET
    } state_t;

    state_t current_state, next_state;
    logic [5:0] byte_counter; // This will now represent the *current* byte number being processed

    logic [15:0] captured_eth_type;
    logic        captured_ip_protocol_is_udp;
    logic [15:0] captured_dest_port;

    // --- Local Parameters for Packet Offsets and Protocol Values ---
    localparam ETHER_HDR_LEN    = 14;
    localparam IP_HDR_LEN       = 20;
    localparam UDP_HDR_LEN      = 8;

    localparam ETH_TYPE_H_OFFSET = 12; // Byte 12 (MSB of EtherType)
    localparam ETH_TYPE_L_OFFSET = 13; // Byte 13 (LSB of EtherType)

    localparam IP_PROTOCOL_OFFSET = 23; // Byte 23 (IP Protocol field)

    localparam UDP_DEST_PORT_H_OFFSET = 36; // Byte 36 (MSB of UDP Dest Port)
    localparam UDP_DEST_PORT_L_OFFSET = 37; // Byte 37 (LSB of UDP Dest Port)

    localparam ETHERTYPE_IPV4   = 16'h0800;
    localparam IP_PROTOCOL_UDP  = 8'h11;


    // --- State Register Block (Sequential Logic - always_ff) ---
    always_ff @(posedge clk) begin
        if (reset) begin
            current_state <= S_IDLE;
            byte_counter  <= 6'd0;
            captured_eth_type         <= 16'h0000;
            captured_ip_protocol_is_udp <= 1'b0;
            captured_dest_port          <= 16'h0000;
        end else begin
            current_state <= next_state;

            if (stream_in_if.valid) begin
                byte_counter <= byte_counter + 1; // Increment counter for the *next* byte position

                // Capture EtherType from input stream
                // The byte_counter here reflects the position of the data *currently* on stream_in_if.data
                if (current_state == S_PARSE_ETH_HEADER) begin
                    if (byte_counter == ETH_TYPE_H_OFFSET) begin
                        captured_eth_type[15:8] <= stream_in_if.data;
                    end else if (byte_counter == ETH_TYPE_L_OFFSET) begin
                        captured_eth_type[7:0] <= stream_in_if.data;
                    end
                end

                // Capture IP Protocol from input stream
                if (current_state == S_PARSE_IP_HEADER) begin
                    if (byte_counter == IP_PROTOCOL_OFFSET) begin
                        if (stream_in_if.data == IP_PROTOCOL_UDP) begin
                            captured_ip_protocol_is_udp <= 1'b1;
                        end else begin
                            captured_ip_protocol_is_udp <= 1'b0;
                        end
                    end
                end

                // Capture UDP Destination Port from input stream
                if (current_state == S_PARSE_UDP_HEADER) begin
                    if (byte_counter == UDP_DEST_PORT_H_OFFSET) begin
                        captured_dest_port[15:8] <= stream_in_if.data;
                    end else if (byte_counter == UDP_DEST_PORT_L_OFFSET) begin
                        captured_dest_port[7:0] <= stream_in_if.data;
                    end
                end
            end
            // Reset byte_counter if valid is low and we're transitioning to IDLE
            if (next_state == S_IDLE && !stream_in_if.valid) begin
                byte_counter <= 6'd0;
            end
        end
    end

    // --- Next-State and Datapath Logic Block (Combinational Logic - always_comb) ---
    always_comb begin
        next_state = current_state;
        valid_out_internal  = 1'b0;
        data_out_internal   = 8'h00;

        case (current_state)
            S_IDLE: begin
                if (stream_in_if.valid) begin
                    next_state = S_PARSE_ETH_HEADER;
                end
                // No byte_counter reset here; handled in always_ff based on !valid_in and next_state=IDLE
            end

            S_PARSE_ETH_HEADER: begin
                if (stream_in_if.valid) begin
                    // Decision based on the byte_counter value AFTER it has been incremented for the current data
                    if (byte_counter == ETH_TYPE_L_OFFSET) begin
                        if (captured_eth_type == ETHERTYPE_IPV4) begin
                            next_state = S_PARSE_IP_HEADER;
                        end else begin
                            next_state = S_DROP_PACKET;
                        end
                    end
                end else begin
                    next_state = S_IDLE;
                end
            end

            S_PARSE_IP_HEADER: begin
                if (stream_in_if.valid) begin
                    // Decision when byte_counter has reached the end of IP header.
                    if (byte_counter == (ETHER_HDR_LEN + IP_HDR_LEN - 1)) begin
                        if (captured_ip_protocol_is_udp) begin
                           next_state = S_PARSE_UDP_HEADER;
                        end else begin
                           next_state = S_DROP_PACKET;
                        end
                    end
                end else begin
                    next_state = S_IDLE;
                end
            end

            S_PARSE_UDP_HEADER: begin
                if (stream_in_if.valid) begin
                    // Decision when byte_counter has reached the end of UDP header.
                    if (byte_counter == (ETHER_HDR_LEN + IP_HDR_LEN + UDP_HDR_LEN - 1)) begin
                        if (captured_dest_port == udp_port_to_match) begin
                            next_state = S_STREAM_PAYLOAD;
                        end else begin
                            next_state = S_DROP_PACKET;
                        end
                    end
                end else begin
                    next_state = S_IDLE;
                end
            end

            S_STREAM_PAYLOAD: begin
                valid_out_internal = stream_in_if.valid;
                data_out_internal  = stream_in_if.data;
                if (!stream_in_if.valid) begin
                    next_state = S_IDLE;
                end
            end

            S_DROP_PACKET: begin
                valid_out_internal = 1'b0;
                data_out_internal = 8'h00;
                if (!stream_in_if.valid) begin
                    next_state = S_IDLE;
                end
            end

            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

endmodule