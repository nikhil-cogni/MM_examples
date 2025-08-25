<<<<<<< HEAD

=======
// control_tile.sv
// Generic Hardware Accelerator - Control Tile Module
// Central tile for global clock, reset, and coordination

module control_tile #(
    parameter DATA_WIDTH = 32,      // Width of data path
    parameter ADDR_WIDTH = 32,      // Address width for external interface
    parameter TILE_ID_X = 0,        // X coordinate in the tile array
    parameter TILE_ID_Y = 0,        // Y coordinate in the tile array
    parameter ARRAY_WIDTH = 4,      // Width of the array
    parameter ARRAY_HEIGHT = 4      // Height of the array
)(
    // Clock and reset
    input  logic clock,             // Main input clock
    input  logic reset,             // External reset
    output logic array_clock,       // Clock to the array
    output logic array_reset,       // Reset to the array
    
    // External system interface (memory-mapped)
    input  logic soc_valid,         // Transaction valid
    input  logic soc_write,         // 1: Write, 0: Read
    input  logic [ADDR_WIDTH-1:0] soc_addr,  // Address
    input  logic [DATA_WIDTH-1:0] soc_wdata, // Write data
    output logic [DATA_WIDTH-1:0] soc_rdata, // Read data
    output logic soc_ready,         // Transaction ready
    
    // Neighbor tile interfaces (for mesh connectivity)
    output logic north_valid,       // North valid
    output logic [DATA_WIDTH-1:0] north_data, // North data
    input  logic north_ready,       // North ready
    input  logic north_valid_in,    // North input valid
    input  logic [DATA_WIDTH-1:0] north_data_in, // North input data
    output logic north_ready_out,   // North input ready
    
    output logic east_valid,        // East valid
    output logic [DATA_WIDTH-1:0] east_data, // East data
    input  logic east_ready,        // East ready
    input  logic east_valid_in,     // East input valid
    input  logic [DATA_WIDTH-1:0] east_data_in, // East input data
    output logic east_ready_out,    // East input ready
    
    output logic south_valid,       // South valid
    output logic [DATA_WIDTH-1:0] south_data, // South data
    input  logic south_ready,       // South ready
    input  logic south_valid_in,    // South input valid
    input  logic [DATA_WIDTH-1:0] south_data_in, // South input data
    output logic south_ready_out,   // South input ready
    
    output logic west_valid,        // West valid
    output logic [DATA_WIDTH-1:0] west_data, // West data
    input  logic west_ready,        // West ready
    input  logic west_valid_in,     // West input valid
    input  logic [DATA_WIDTH-1:0] west_data_in, // West input data
    output logic west_ready_out,    // West input ready
    
    // Global control signals
    output logic [ARRAY_WIDTH-1:0][ARRAY_HEIGHT-1:0] tile_enable, // Enable signals for all tiles
    output logic global_start,                                    // Global start signal
    input  logic [ARRAY_WIDTH-1:0][ARRAY_HEIGHT-1:0] tile_done    // Done signals from all tiles
);

    // Register addresses
    localparam ADDR_CONTROL      = 32'h0000_0000; // Control register
    localparam ADDR_STATUS       = 32'h0000_0004; // Status register
    localparam ADDR_CLOCK_CTRL   = 32'h0000_0008; // Clock control register
    localparam ADDR_TILE_ENABLE  = 32'h0000_000C; // Base address for tile enable registers
    localparam ADDR_GLOBAL_SYNC  = 32'h0000_0020; // Global synchronization register
    
    // Control registers
    logic [31:0] control_reg;
    logic [31:0] status_reg;
    logic [31:0] clock_ctrl_reg;
    logic [31:0] global_sync_reg;
    logic [31:0] tile_enable_regs[(ARRAY_WIDTH*ARRAY_HEIGHT+31)/32]; // Registers for enable bits
    
    // Clock and reset control
    logic clock_enable;
    logic clock_divider_enable;
    logic [3:0] clock_div_ratio;
    logic soft_reset;
    logic [7:0] clock_divider_counter;
    
    // Variables for address calculation
    logic [31:0] reg_offset_calc;
    
    // Control register bits
    assign clock_enable = control_reg[0];
    assign soft_reset = control_reg[1];
    assign global_start = control_reg[2];
    assign clock_divider_enable = clock_ctrl_reg[0];
    assign clock_div_ratio = clock_ctrl_reg[4:1];
    
    // Generate array clock based on clock control settings
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            array_clock <= 1'b0;
            clock_divider_counter <= 8'd0;
        end
        else if (clock_enable) begin
            if (clock_divider_enable) begin
                // Clock divider mode
                if (clock_divider_counter >= clock_div_ratio) begin
                    array_clock <= ~array_clock;
                    clock_divider_counter <= 8'd0;
                end
                else begin
                    clock_divider_counter <= clock_divider_counter + 8'd1;
                end
            end
            else begin
                // Pass through mode
                array_clock <= clock;
            end
        end
        else begin
            // Clock disabled
            array_clock <= 1'b0;
        end
    end
    
    // Generate array reset
    assign array_reset = reset || soft_reset;
    
    // Compute register offset
    always_comb begin
        reg_offset_calc = (soc_addr - ADDR_TILE_ENABLE) >> 2;
    end
    
    // Control register handling
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            control_reg <= 32'h0000_0000;
            clock_ctrl_reg <= 32'h0000_0000;
            global_sync_reg <= 32'h0000_0000;
            soc_rdata <= 32'h0000_0000;
            soc_ready <= 1'b0;
            
            // Initialize all tile enable registers to 0
            for (int i = 0; i < (ARRAY_WIDTH*ARRAY_HEIGHT+31)/32; i++) begin
                tile_enable_regs[i] <= 32'h0000_0000;
            end
        end
        else begin
            // Default values
            soc_ready <= 1'b0;
            
            if (soc_valid) begin
                soc_ready <= 1'b1;
                
                if (soc_write) begin
                    // Write to registers
                    case (soc_addr)
                        ADDR_CONTROL: control_reg <= soc_wdata;
                        ADDR_CLOCK_CTRL: clock_ctrl_reg <= soc_wdata;
                        ADDR_GLOBAL_SYNC: global_sync_reg <= soc_wdata;
                        default: begin
                            // Check if address is in tile enable range
                            if (soc_addr >= ADDR_TILE_ENABLE && 
                                soc_addr < ADDR_TILE_ENABLE + 4*((ARRAY_WIDTH*ARRAY_HEIGHT+31)/32)) begin
                                
                                if (reg_offset_calc < (ARRAY_WIDTH*ARRAY_HEIGHT+31)/32) begin
                                    tile_enable_regs[reg_offset_calc] <= soc_wdata;
                                end
                            end
                        end
                    endcase
                end
                else begin
                    // Read from registers
                    case (soc_addr)
                        ADDR_CONTROL: soc_rdata <= control_reg;
                        ADDR_STATUS: soc_rdata <= status_reg;
                        ADDR_CLOCK_CTRL: soc_rdata <= clock_ctrl_reg;
                        ADDR_GLOBAL_SYNC: soc_rdata <= global_sync_reg;
                        default: begin
                            // Check if address is in tile enable range
                            if (soc_addr >= ADDR_TILE_ENABLE && 
                                soc_addr < ADDR_TILE_ENABLE + 4*((ARRAY_WIDTH*ARRAY_HEIGHT+31)/32)) begin
                                
                                if (reg_offset_calc < (ARRAY_WIDTH*ARRAY_HEIGHT+31)/32) begin
                                    soc_rdata <= tile_enable_regs[reg_offset_calc];
                                end
                                else begin
                                    soc_rdata <= 32'h0000_0000;
                                end
                            end
                            else begin
                                soc_rdata <= 32'hDEAD_BEEF; // Invalid address
                            end
                        end
                    endcase
                end
            end
        end
    end
    
    // Generate tile enable signals from registers
    genvar x, y;
    generate
        for (y = 0; y < ARRAY_HEIGHT; y++) begin : gen_y_loop
            for (x = 0; x < ARRAY_WIDTH; x++) begin : gen_x_loop
                localparam bit_index = y * ARRAY_WIDTH + x;
                localparam reg_index = bit_index / 32;
                localparam bit_offset = bit_index % 32;
                
                assign tile_enable[x][y] = tile_enable_regs[reg_index][bit_offset];
            end
        end
    endgenerate
    
    // Status register update
    always_comb begin
        // Count how many tiles are done
        logic [7:0] done_count;
        done_count = 8'd0;
        
        for (int y = 0; y < ARRAY_HEIGHT; y++) begin
            for (int x = 0; x < ARRAY_WIDTH; x++) begin
                if (tile_done[x][y]) done_count++;
            end
        end
        
        // Build status register
        status_reg = {8'h00,                  // Reserved
                      done_count,             // Number of tiles done
                      clock_divider_counter,  // Current clock divider count
                      8'h00,                  // Reserved
                      1'b0,                   // Reserved
                      array_reset,            // Current reset state
                      array_clock,            // Current clock state
                      1'b0,                   // Reserved
                      global_start,           // Current start state
                      soft_reset,             // Current soft reset state
                      clock_enable            // Current clock enable state
                     };
    end
    
    // Simple interconnect for routing with neighboring tiles
    // Just forward data from the system interface to the appropriate direction
    always_comb begin
        // Default values
        north_valid = 1'b0;
        east_valid = 1'b0;
        south_valid = 1'b0;
        west_valid = 1'b0;
        north_data = '0;
        east_data = '0;
        south_data = '0;
        west_data = '0;
        north_ready_out = 1'b1;
        east_ready_out = 1'b1;
        south_ready_out = 1'b1;
        west_ready_out = 1'b1;
        
        // Route based on control register configuration (bits [7:6])
        case (control_reg[7:6])
            2'b00: begin // Route to north
                north_valid = soc_valid && soc_write && (soc_addr == ADDR_GLOBAL_SYNC);
                north_data = soc_wdata;
            end
            2'b01: begin // Route to east
                east_valid = soc_valid && soc_write && (soc_addr == ADDR_GLOBAL_SYNC);
                east_data = soc_wdata;
            end
            2'b10: begin // Route to south
                south_valid = soc_valid && soc_write && (soc_addr == ADDR_GLOBAL_SYNC);
                south_data = soc_wdata;
            end
            2'b11: begin // Route to west
                west_valid = soc_valid && soc_write && (soc_addr == ADDR_GLOBAL_SYNC);
                west_data = soc_wdata;
            end
        endcase
    end

endmodule
>>>>>>> new-content