<<<<<<< HEAD

=======
// data_memory.sv
// Generic Hardware Accelerator - Data Memory Module
// Multi-banked memory enabling high-throughput, parallel access

module data_memory #(
    parameter DATA_WIDTH = 32,     // Width of data path
    parameter ADDR_WIDTH = 12,     // Address width
    parameter NUM_BANKS = 8,       // Number of memory banks
    parameter MEM_SIZE = 16384     // Total memory size in words
)(
    // Clock and reset
    input  logic clock,
    input  logic reset,
    
    // Internal memory interface
    input  logic [ADDR_WIDTH-1:0] addr,       // Memory address
    input  logic [$clog2(NUM_BANKS)-1:0] bank_sel, // Bank select
    input  logic write_en,                   // Write enable
    input  logic read_en,                    // Read enable
    input  logic [DATA_WIDTH-1:0] write_data, // Write data
    output logic [DATA_WIDTH-1:0] read_data,  // Read data
    
    // External memory-mapped interface
    input  logic ext_valid,                   // External access valid
    input  logic ext_write,                   // External write enable
    input  logic [ADDR_WIDTH-1:0] ext_addr,   // External address
    input  logic [DATA_WIDTH-1:0] ext_wdata,  // External write data
    output logic [DATA_WIDTH-1:0] ext_rdata   // External read data
);

    // Calculate bank size
    localparam BANK_SIZE = MEM_SIZE / NUM_BANKS;
    localparam BANK_ADDR_WIDTH = $clog2(BANK_SIZE);
    
    // Memory banks
    logic [DATA_WIDTH-1:0] banks [0:NUM_BANKS-1][0:BANK_SIZE-1];
    
    // Bank address calculation
    logic [BANK_ADDR_WIDTH-1:0] bank_addr;
    logic [BANK_ADDR_WIDTH-1:0] ext_bank_addr;
    logic [$clog2(NUM_BANKS)-1:0] ext_bank_sel;
    
    // Bank address calculation
    assign bank_addr = addr[BANK_ADDR_WIDTH-1:0];
    
    // External bank selection and address calculation
    assign ext_bank_sel = ext_addr[ADDR_WIDTH-1:BANK_ADDR_WIDTH];
    assign ext_bank_addr = ext_addr[BANK_ADDR_WIDTH-1:0];
    
    // Internal memory access
    always_ff @(posedge clock) begin
        if (read_en) begin
            if (bank_sel < NUM_BANKS && bank_addr < BANK_SIZE) begin
                read_data <= banks[bank_sel][bank_addr];
            end
            else begin
                read_data <= '0; // Return 0 for out-of-range addresses
            end
        end
        
        if (write_en) begin
            if (bank_sel < NUM_BANKS && bank_addr < BANK_SIZE) begin
                banks[bank_sel][bank_addr] <= write_data;
            end
        end
    end
    
    // External memory-mapped access
    always_ff @(posedge clock) begin
        if (ext_valid) begin
            if (ext_write) begin
                // External write
                if (ext_bank_sel < NUM_BANKS && ext_bank_addr < BANK_SIZE) begin
                    banks[ext_bank_sel][ext_bank_addr] <= ext_wdata;
                end
            end
            else begin
                // External read
                if (ext_bank_sel < NUM_BANKS && ext_bank_addr < BANK_SIZE) begin
                    ext_rdata <= banks[ext_bank_sel][ext_bank_addr];
                end
                else begin
                    ext_rdata <= '0; // Return 0 for out-of-range addresses
                end
            end
        end
    end
    
    // Memory initialization
    initial begin
        for (int b = 0; b < NUM_BANKS; b++) begin
            for (int i = 0; i < BANK_SIZE; i++) begin
                banks[b][i] = '0;
            end
        end
    end

endmodule
>>>>>>> new-content