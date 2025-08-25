`timescale 1ns/1ps

module tb_byte_stream_adder;
    // Parameters
    localparam DATA_WIDTH = 8;
    localparam STREAM_LENGTH = 16;
    localparam CLK_PERIOD = 10;  // 10ns = 100MHz
    
    // Signals for DUT
    logic clock;
    logic reset;
    logic [DATA_WIDTH-1:0] a_data;
    logic a_valid;
    logic a_ready;
    logic [DATA_WIDTH-1:0] b_data;
    logic b_valid;
    logic b_ready;
    logic [DATA_WIDTH:0] sum_data;
    logic sum_valid;
    logic sum_ready;
    
    // Test variables
    int byte_count;
    int error_count;
    
    // Instantiate the DUT
    byte_stream_adder #(
        .DATA_WIDTH(DATA_WIDTH),
        .STREAM_LENGTH(STREAM_LENGTH)
    ) dut (
        .clock(clock),
        .reset(reset),
        .a_data(a_data),
        .a_valid(a_valid),
        .a_ready(a_ready),
        .b_data(b_data),
        .b_valid(b_valid),
        .b_ready(b_ready),
        .sum_data(sum_data),
        .sum_valid(sum_valid),
        .sum_ready(sum_ready)
    );
    
    // Clock generation
    always begin
        clock = 0; #(CLK_PERIOD/2);
        clock = 1; #(CLK_PERIOD/2);
    end
    
    // Waveform dump
    initial begin
        $dumpfile("dumpfile.fst");
        $dumpvars(0);
    end
    
    // Main test
    initial begin
        $display("TEST START");
        
        // Initialize and reset
        a_data = 0; a_valid = 0;
        b_data = 0; b_valid = 0;
        sum_ready = 1;
        byte_count = 0;
        error_count = 0;
        
        reset = 1;
        repeat(3) @(posedge clock);
        reset = 0;
        @(posedge clock);
        
        // Test Case 1: Simple sequential addition
        for (int i = 0; i < STREAM_LENGTH; i++) begin
            // Generate test data - simple incrementing pattern
            a_data = i;
            b_data = STREAM_LENGTH - i - 1;
            a_valid = 1;
            b_valid = 1;
            
            // Wait until handshake completes
            while (!(a_valid && b_valid && a_ready && b_ready)) @(posedge clock);
            
            // Check result on next cycle
            @(posedge clock);
            if (sum_valid) begin
                if (sum_data !== (i + (STREAM_LENGTH - i - 1))) begin
                    $display("LOG: %0t : ERROR : tb_byte_stream_adder : dut.sum_data : expected_value: %0d actual_value: %0d", 
                             $time, i + (STREAM_LENGTH - i - 1), sum_data);
                    error_count++;
                end else begin
                    $display("LOG: %0t : INFO : tb_byte_stream_adder : dut.sum_data : expected_value: %0d actual_value: %0d", 
                             $time, i + (STREAM_LENGTH - i - 1), sum_data);
                end
                byte_count++;
            end
        end
        
        // Test Case 2: Back pressure test
        // First ensure input handshake is not happening
        a_valid = 0;
        b_valid = 0;
        sum_ready = 0;  // Create backpressure
        @(posedge clock);
        
        // Now set up test values
        a_data = 8'hAA;  // 170 in decimal
        b_data = 8'h55;  // 85 in decimal
        a_valid = 1;
        b_valid = 1;
        
        repeat(3) @(posedge clock);  // Wait a few cycles with backpressure
        
        // Verify inputs are not accepted during backpressure
        if (a_ready || b_ready) begin
            $display("LOG: %0t : ERROR : tb_byte_stream_adder : Inputs should not be ready during backpressure", $time);
            error_count++;
        end
        
        // Release backpressure
        sum_ready = 1;
        
        // Wait for handshake to complete
        while (!(a_valid && b_valid && a_ready && b_ready)) @(posedge clock);
        
        // Need to wait one more cycle for the data to appear at output
        @(posedge clock);
        
        // Verify backpressure result
        if (sum_data !== 9'h0FF) begin
            $display("LOG: %0t : ERROR : tb_byte_stream_adder : dut.sum_data : expected_value: %0d actual_value: %0d", 
                     $time, 9'h0FF, sum_data);
            error_count++;
        end else begin
            $display("LOG: %0t : INFO : tb_byte_stream_adder : dut.sum_data : expected_value: %0d actual_value: %0d", 
                     $time, 9'h0FF, sum_data);
        end
        
        // Final status
        if (error_count == 0) begin
            $display("TEST PASSED");
        end else begin
            $display("TEST FAILED: %0d errors detected", error_count);
            $error("Test failed with errors");
        end
        
        // Allow some time for signals to settle
        repeat(5) @(posedge clock);
        $finish;
    end
endmodule
