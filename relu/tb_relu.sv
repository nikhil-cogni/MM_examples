`timescale 1ns/1ps

module tb_relu();
    // Parameters
    parameter DATA_WIDTH = 8;
    parameter TEST_COUNT = 100;
    
    // Signals
    logic signed [DATA_WIDTH-1:0] data_in;
    logic [DATA_WIDTH-1:0] data_out;
    logic [DATA_WIDTH-1:0] expected_out;
    
    // Clock and reset
    logic clock = 0;
    logic reset = 1;
    
    // Instantiate the DUT
    relu #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .data_in(data_in),
        .data_out(data_out)
    );
    
    // Clock generation
    always #5 clock = ~clock;
    
    // ReLU reference model
    function automatic logic [DATA_WIDTH-1:0] relu_function(logic signed [DATA_WIDTH-1:0] input_val);
        return (input_val[DATA_WIDTH-1]) ? '0 : input_val;
    endfunction
    
    // Test variables
    int error_count = 0;
    int test_number = 0;
    
    // Main test process
    initial begin
        $display("TEST START");
        
        // Reset sequence
        reset = 1;
        @(posedge clock);
        reset = 0;
        @(posedge clock);
        
        // Test cases
        
        // 1. Test positive values
        for (int i = 0; i < TEST_COUNT/4; i++) begin
            test_number++;
            data_in = $urandom_range(1, 2**(DATA_WIDTH-1)-1); // Positive values
            expected_out = relu_function(data_in);
            #1; // Wait for combinational logic to settle
            
            check_result(test_number, "POSITIVE");
        end
        
        // 2. Test negative values
        for (int i = 0; i < TEST_COUNT/4; i++) begin
            test_number++;
            data_in = -$urandom_range(1, 2**(DATA_WIDTH-1)); // Negative values
            expected_out = relu_function(data_in);
            #1; // Wait for combinational logic to settle
            
            check_result(test_number, "NEGATIVE");
        end
        
        // 3. Test zero
        test_number++;
        data_in = 0;
        expected_out = relu_function(data_in);
        #1; // Wait for combinational logic to settle
        
        check_result(test_number, "ZERO");
        
        // 4. Test edge cases
        
        // Maximum positive value
        test_number++;
        data_in = 2**(DATA_WIDTH-1)-1;
        expected_out = relu_function(data_in);
        #1;
        check_result(test_number, "MAX_POSITIVE");
        
        // Minimum negative value
        test_number++;
        data_in = -(2**(DATA_WIDTH-1));
        expected_out = relu_function(data_in);
        #1;
        check_result(test_number, "MIN_NEGATIVE");
        
        // 5. Random tests for remaining test count
        for (int i = 0; i < TEST_COUNT/2; i++) begin
            test_number++;
            data_in = $signed($random); // Random values across the full range
            expected_out = relu_function(data_in);
            #1;
            
            check_result(test_number, "RANDOM");
        end
        
        // Test completion reporting
        if (error_count == 0) begin
            $display("TEST PASSED");
        end else begin
            $display("TEST FAILED with %0d errors", error_count);
            $error("ReLU testbench failed");
        end
        
        $finish;
    end
    
    // Check result task
    task automatic check_result(int test_num, string test_type);
        if (data_out !== expected_out) begin
            $display("LOG: %0t : ERROR : tb_relu : dut.data_out : expected_value: %0d actual_value: %0d", 
                    $time, expected_out, data_out);
            error_count++;
        end else begin
            $display("LOG: %0t : INFO : tb_relu : dut.data_out : expected_value: %0d actual_value: %0d", 
                    $time, expected_out, data_out);
        end
    endtask
    
    // Dump waveforms
    initial begin
        $dumpfile("dumpfile.fst");
        $dumpvars(0);
    end

endmodule
