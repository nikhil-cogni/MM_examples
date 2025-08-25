<<<<<<< HEAD

=======
// program_memory.sv
// Generic Hardware Accelerator - Program Memory Module
// Local per-tile memory for instructions

module program_memory #(
    parameter DATA_WIDTH = 32,     // Width of data path
    parameter ADDR_WIDTH = 12,     // Address width
    parameter MEM_SIZE = 4096      // Memory size in words
)(
    // Clock and reset
    input  logic clock,
    input  logic reset,
    
    // Read port (for instruction fetch)
    input  logic [ADDR_WIDTH-1:0] addr,     // Read address
    input  logic read_en,                   // Read enable
    output logic [DATA_WIDTH-1:0] read_data, // Read data
    
    // Write port (for memory-mapped configuration)
    input  logic write_en,                   // Write enable
    input  logic [ADDR_WIDTH-1:0] write_addr, // Write address
    input  logic [DATA_WIDTH-1:0] write_data  // Write data
);

    // Program memory array
    logic [DATA_WIDTH-1:0] mem [0:MEM_SIZE-1];
    
    // Read operation
    always_ff @(posedge clock) begin
        if (read_en) begin
            if (addr < MEM_SIZE) begin
                read_data <= mem[addr];
            end
            else begin
                read_data <= '0; // Return 0 for out-of-range addresses
            end
        end
    end
    
    // Write operation
    always_ff @(posedge clock) begin
        if (write_en) begin
            if (write_addr < MEM_SIZE) begin
                mem[write_addr] <= write_data;
            end
        end
    end
    
    // Memory initialization (could be loaded from external source in a real system)
    initial begin
        for (int i = 0; i < MEM_SIZE; i++) begin
            mem[i] = '0;
        end
    end

endmodule
>>>>>>> new-content