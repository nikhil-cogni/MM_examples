<<<<<<< HEAD

=======
// fifo.sv
// Generic Hardware Accelerator - FIFO Module
// Synchronous FIFO for data buffering

module fifo #(
    parameter DATA_WIDTH = 32,     // Width of data path
    parameter DEPTH = 16           // FIFO depth
)(
    // Clock and reset
    input  logic clock,
    input  logic reset,
    
    // Write interface
    input  logic [DATA_WIDTH-1:0] write_data,
    input  logic write_valid,
    output logic write_ready,
    
    // Read interface
    output logic [DATA_WIDTH-1:0] read_data,
    output logic read_valid,
    input  logic read_ready
);

    // Local parameters
    localparam ADDR_WIDTH = $clog2(DEPTH);
    
    // FIFO memory
    logic [DATA_WIDTH-1:0] memory [0:DEPTH-1];
    
    // Read and write pointers
    logic [ADDR_WIDTH-1:0] write_ptr;
    logic [ADDR_WIDTH-1:0] read_ptr;
    
    // FIFO status
    logic [ADDR_WIDTH:0] count;
    logic empty;
    logic full;
    
    // FIFO status calculation
    assign empty = (count == 0);
    assign full = (count == DEPTH);
    assign write_ready = !full;
    assign read_valid = !empty;
    
    // Read data output
    assign read_data = empty ? '0 : memory[read_ptr];
    
    // FIFO write operation
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            write_ptr <= '0;
            for (int i = 0; i < DEPTH; i++) begin
                memory[i] <= '0;
            end
        end
        else if (write_valid && !full) begin
            memory[write_ptr] <= write_data;
            write_ptr <= (write_ptr == DEPTH-1) ? '0 : write_ptr + 1;
        end
    end
    
    // FIFO read operation
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            read_ptr <= '0;
        end
        else if (read_ready && !empty) begin
            read_ptr <= (read_ptr == DEPTH-1) ? '0 : read_ptr + 1;
        end
    end
    
    // FIFO count tracking
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            count <= '0;
        end
        else begin
            if (write_valid && !full && (!read_ready || empty)) begin
                // Only write
                count <= count + 1;
            end
            else if (read_ready && !empty && (!write_valid || full)) begin
                // Only read
                count <= count - 1;
            end
            // Both read and write or neither - count stays the same
        end
    end

endmodule
>>>>>>> new-content