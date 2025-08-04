# run.do - Script to compile, simulate, and view waveforms for UDP Packet Filter

# 1. Cleanup previous simulation data
quit -sim
#vdel -all

# 2. Create a working library
vlib work

# 3. Compile the SystemVerilog files
#    Order: interfaces first, then modules that use them.
vlog -sv packet_if.sv
vlog -sv udp_packet_filter.sv
vlog -sv tb_udp_filter.sv

# 4. Define a Tcl procedure to add waveform signals
#    This PROCEURE DEFINITION MUST COME BEFORE IT IS CALLED.
proc add_wave_signals {} {
    # Remove any existing waves to start fresh
    delete wave *

    # Add all signals from the testbench top level
    add wave -recursive /tb_udp_filter/*

    # Add input stream interface signals (explicitly for clarity)
    add wave -group Input_Stream -r /tb_udp_filter/input_stream_if/*

    # Add output stream interface signals (explicitly for clarity)
    add wave -group Output_Stream -r /tb_udp_filter/output_stream_if/*

    # Specifically add DUT internal signals (e.g., FSM state, counters, captured values)
    # Adding these explicitly can be very helpful for debugging internal behavior.
    add wave -group DUT_Internals /tb_udp_filter/dut/current_state
    add wave -group DUT_Internals /tb_udp_filter/dut/next_state
    add wave -group DUT_Internals /tb_udp_filter/dut/byte_counter
    add wave -group DUT_Internals /tb_udp_filter/dut/captured_eth_type
    add wave -group DUT_Internals /tb_udp_filter/dut/captured_ip_protocol_is_udp
    add wave -group DUT_Internals /tb_udp_filter/dut/captured_dest_port
    add wave -group DUT_Internals /tb_udp_filter/dut/data_out_internal
    add wave -group DUT_Internals /tb_udp_filter/dut/valid_out_internal

    # Optional: Configure wave viewer layout (uncomment if you want to apply)
    # view wave
    # wave zoom full
    # configure wave -name {Wave} -hidemaximize 1
    # configure wave -name {Wave} -hideclose 1
}

# 5. Load the top-level testbench for simulation
#    `-gui` option forces ModelSim to open its graphical user interface.
#    `-do "..."` executes a sequence of commands immediately after loading the design.
#    Now, "add_wave_signals" will be a recognized command.
vsim -gui tb_udp_filter -do "add_wave_signals; run -all"


# 6. Run the simulation