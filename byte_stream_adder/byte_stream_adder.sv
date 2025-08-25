module byte_stream_adder #(
    parameter DATA_WIDTH = 8,
    parameter STREAM_LENGTH = 16
)(
    input  logic clock,
    input  logic reset,
    
    // Input stream a
    input  logic [DATA_WIDTH-1:0] a_data,
    input  logic a_valid,
    output logic a_ready,
    
    // Input stream b
    input  logic [DATA_WIDTH-1:0] b_data,
    input  logic b_valid,
    output logic b_ready,
    
    // Output stream (sum)
    output logic [DATA_WIDTH:0] sum_data,  // One extra bit to handle carry
    output logic sum_valid,
    input  logic sum_ready
);

    // Counter to track the number of bytes processed
    logic [$clog2(STREAM_LENGTH):0] byte_count;
    
    // Handshake logic
    wire input_handshake = a_valid && b_valid && a_ready && b_ready;
    wire output_handshake = sum_valid && sum_ready;
    
    // Ready signals - ready to accept input when downstream is ready or output isn't valid
    assign a_ready = !sum_valid || sum_ready;
    assign b_ready = a_ready;  // Same ready signal for both inputs
    
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            sum_data <= '0;
            sum_valid <= 1'b0;
            byte_count <= '0;
        end else begin
            // Handle output handshake
            if (output_handshake) begin
                sum_valid <= 1'b0;
            end
            
            // Handle input handshake
            if (input_handshake) begin
                // Add the inputs
                sum_data <= a_data + b_data;
                sum_valid <= 1'b1;
                
                // Update byte counter
                if (byte_count < STREAM_LENGTH) begin
                    byte_count <= byte_count + 1'b1;
                end
            end
        end
    end

endmodule
