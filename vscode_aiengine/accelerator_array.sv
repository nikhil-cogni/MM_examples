<<<<<<< HEAD

=======
// accelerator_array.sv
// Generic Hardware Accelerator - Top-Level Accelerator Array Module
// Two-dimensional array of processing tiles with special interface tiles

module accelerator_array #(
    parameter DATA_WIDTH = 32,      // Width of data path
    parameter ADDR_WIDTH = 32,      // Address width for external interface
    parameter ARRAY_WIDTH = 4,      // Width of the array (number of tiles in x direction)
    parameter ARRAY_HEIGHT = 4,     // Height of the array (number of tiles in y direction)
    parameter VECTOR_WIDTH = 256,   // Width of vector operations in processing tiles
    parameter PROG_MEM_SIZE = 4096, // Size of program memory in words
    parameter DATA_MEM_BANKS = 8,   // Number of data memory banks
    parameter DATA_MEM_SIZE = 16384 // Size of data memory in words
)(
    // Clock and reset
    input  logic clock,           // Main system clock
    input  logic reset,           // Main system reset
    
    // External system interface (memory-mapped)
    input  logic soc_valid,       // Transaction valid
    input  logic soc_write,       // 1: Write, 0: Read
    input  logic [ADDR_WIDTH-1:0] soc_addr,  // Address
    input  logic [DATA_WIDTH-1:0] soc_wdata, // Write data
    output logic [DATA_WIDTH-1:0] soc_rdata, // Read data
    output logic soc_ready,       // Transaction ready
    
    // Programmable Logic (PL) interface (streaming)
    input  logic pl_north_valid,  // North stream valid
    input  logic [DATA_WIDTH-1:0] pl_north_data, // North stream data
    output logic pl_north_ready,  // North stream ready
    output logic pl_north_valid_out, // North output stream valid
    output logic [DATA_WIDTH-1:0] pl_north_data_out, // North output stream data
    input  logic pl_north_ready_out, // North output stream ready
    
    input  logic pl_south_valid,  // South stream valid
    input  logic [DATA_WIDTH-1:0] pl_south_data, // South stream data
    output logic pl_south_ready,  // South stream ready
    output logic pl_south_valid_out, // South output stream valid
    output logic [DATA_WIDTH-1:0] pl_south_data_out, // South output stream data
    input  logic pl_south_ready_out, // South output stream ready
    
    // On-Chip Network (NoC) interface
    input  logic noc_valid,       // Stream valid
    input  logic [DATA_WIDTH-1:0] noc_data, // Stream data
    output logic noc_ready,       // Stream ready
    output logic noc_valid_out,   // Output stream valid
    output logic [DATA_WIDTH-1:0] noc_data_out, // Output stream data
    input  logic noc_ready_out    // Output stream ready
);

    // Internal signals
    logic array_clock;            // Array clock from control tile
    logic array_reset;            // Array reset from control tile
    logic global_start;           // Global start signal
    logic [ARRAY_WIDTH-1:0][ARRAY_HEIGHT-1:0] tile_enable; // Tile enable signals
    logic [ARRAY_WIDTH-1:0][ARRAY_HEIGHT-1:0] tile_done;   // Tile done signals
    
    // Interconnect signals between tiles
    // [x][y][0] = north, [1] = east, [2] = south, [3] = west
    logic [ARRAY_WIDTH-1:0][ARRAY_HEIGHT-1:0][3:0] valid;
    logic [ARRAY_WIDTH-1:0][ARRAY_HEIGHT-1:0][3:0][DATA_WIDTH-1:0] data;
    logic [ARRAY_WIDTH-1:0][ARRAY_HEIGHT-1:0][3:0] ready;
    
    // SoC interface signals for control and interface tiles
    logic [DATA_WIDTH-1:0] soc_rdata_control;
    logic [DATA_WIDTH-1:0] soc_rdata_north;
    logic [DATA_WIDTH-1:0] soc_rdata_south;
    logic [DATA_WIDTH-1:0] soc_rdata_east;
    logic soc_ready_control;
    logic soc_ready_north;
    logic soc_ready_south;
    logic soc_ready_east;
    
    // Address decoding for SoC interface
    logic select_control_tile;
    logic select_north_interface;
    logic select_south_interface;
    logic select_east_interface;
    
    // Simple address decoding - top bits select which tile to access
    assign select_control_tile = (soc_addr[ADDR_WIDTH-1:ADDR_WIDTH-2] == 2'b00);
    assign select_north_interface = (soc_addr[ADDR_WIDTH-1:ADDR_WIDTH-2] == 2'b01);
    assign select_south_interface = (soc_addr[ADDR_WIDTH-1:ADDR_WIDTH-2] == 2'b10);
    assign select_east_interface = (soc_addr[ADDR_WIDTH-1:ADDR_WIDTH-2] == 2'b11);
    
    // Output mux for SoC interface
    always_comb begin
        if (select_control_tile) begin
            soc_rdata = soc_rdata_control;
            soc_ready = soc_ready_control;
        end
        else if (select_north_interface) begin
            soc_rdata = soc_rdata_north;
            soc_ready = soc_ready_north;
        end
        else if (select_south_interface) begin
            soc_rdata = soc_rdata_south;
            soc_ready = soc_ready_south;
        end
        else if (select_east_interface) begin
            soc_rdata = soc_rdata_east;
            soc_ready = soc_ready_east;
        end
        else begin
            soc_rdata = 32'hDEAD_BEEF; // Invalid address
            soc_ready = 1'b1;          // Always ready for invalid addresses
        end
    end
    
    // Control Tile (at position [0][0])
    control_tile #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .TILE_ID_X(0),
        .TILE_ID_Y(0),
        .ARRAY_WIDTH(ARRAY_WIDTH),
        .ARRAY_HEIGHT(ARRAY_HEIGHT)
    ) control_tile_inst (
        .clock(clock),
        .reset(reset),
        .array_clock(array_clock),
        .array_reset(array_reset),
        
        // SoC interface
        .soc_valid(soc_valid && select_control_tile),
        .soc_write(soc_write),
        .soc_addr(soc_addr),
        .soc_wdata(soc_wdata),
        .soc_rdata(soc_rdata_control),
        .soc_ready(soc_ready_control),
        
        // Neighbor connections
        .north_valid(valid[0][0][0]),
        .north_data(data[0][0][0]),
        .north_ready(ready[0][0][0]),
        .north_valid_in(valid[0][1][2]),  // From tile [0][1] south port
        .north_data_in(data[0][1][2]),
        .north_ready_out(ready[0][1][2]),
        
        .east_valid(valid[0][0][1]),
        .east_data(data[0][0][1]),
        .east_ready(ready[0][0][1]),
        .east_valid_in(valid[1][0][3]),   // From tile [1][0] west port
        .east_data_in(data[1][0][3]),
        .east_ready_out(ready[1][0][3]),
        
        .south_valid(valid[0][0][2]),
        .south_data(data[0][0][2]),
        .south_ready(ready[0][0][2]),
        // No south connection for the control tile
        .south_valid_in(1'b0),
        .south_data_in('0),
        .south_ready_out(),
        
        .west_valid(valid[0][0][3]),
        .west_data(data[0][0][3]),
        .west_ready(ready[0][0][3]),
        // No west connection for the control tile
        .west_valid_in(1'b0),
        .west_data_in('0),
        .west_ready_out(),
        
        // Global control signals
        .tile_enable(tile_enable),
        .global_start(global_start),
        .tile_done(tile_done)
    );
    
    // North Interface Tile (at position [1][0])
    interface_tile #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .TILE_ID_X(1),
        .TILE_ID_Y(0)
    ) north_interface_tile (
        .clock(array_clock),
        .reset(array_reset),
        
        // SoC interface
        .soc_valid(soc_valid && select_north_interface),
        .soc_write(soc_write),
        .soc_addr(soc_addr),
        .soc_wdata(soc_wdata),
        .soc_rdata(soc_rdata_north),
        .soc_ready(soc_ready_north),
        
        // Programmable Logic interface
        .pl_valid(pl_north_valid),
        .pl_data(pl_north_data),
        .pl_ready(pl_north_ready),
        .pl_valid_out(pl_north_valid_out),
        .pl_data_out(pl_north_data_out),
        .pl_ready_out(pl_north_ready_out),
        
        // NoC interface (not connected for north tile)
        .noc_valid(1'b0),
        .noc_data('0),
        .noc_ready(),
        .noc_valid_out(),
        .noc_data_out(),
        .noc_ready_out(1'b1),
        
        // Neighbor connections
        .north_valid(valid[1][0][0]),
        .north_data(data[1][0][0]),
        .north_ready(ready[1][0][0]),
        .north_valid_in(valid[1][1][2]),   // From tile [1][1] south port
        .north_data_in(data[1][1][2]),
        .north_ready_out(ready[1][1][2]),
        
        .east_valid(valid[1][0][1]),
        .east_data(data[1][0][1]),
        .east_ready(ready[1][0][1]),
        .east_valid_in(valid[2][0][3]),    // From tile [2][0] west port
        .east_data_in(data[2][0][3]),
        .east_ready_out(ready[2][0][3]),
        
        .south_valid(valid[1][0][2]),
        .south_data(data[1][0][2]),
        .south_ready(ready[1][0][2]),
        // No south connection for interface tiles at y=0
        .south_valid_in(1'b0),
        .south_data_in('0),
        .south_ready_out(),
        
        .west_valid(valid[1][0][3]),
        .west_data(data[1][0][3]),
        .west_ready(ready[1][0][3]),
        .west_valid_in(valid[0][0][1]),    // From control tile east port
        .west_data_in(data[0][0][1]),
        .west_ready_out(ready[0][0][1])
    );
    
    // South Interface Tile (at position [1][ARRAY_HEIGHT-1])
    interface_tile #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .TILE_ID_X(1),
        .TILE_ID_Y(ARRAY_HEIGHT-1)
    ) south_interface_tile (
        .clock(array_clock),
        .reset(array_reset),
        
        // SoC interface
        .soc_valid(soc_valid && select_south_interface),
        .soc_write(soc_write),
        .soc_addr(soc_addr),
        .soc_wdata(soc_wdata),
        .soc_rdata(soc_rdata_south),
        .soc_ready(soc_ready_south),
        
        // Programmable Logic interface
        .pl_valid(pl_south_valid),
        .pl_data(pl_south_data),
        .pl_ready(pl_south_ready),
        .pl_valid_out(pl_south_valid_out),
        .pl_data_out(pl_south_data_out),
        .pl_ready_out(pl_south_ready_out),
        
        // NoC interface (not connected for south tile)
        .noc_valid(1'b0),
        .noc_data('0),
        .noc_ready(),
        .noc_valid_out(),
        .noc_data_out(),
        .noc_ready_out(1'b1),
        
        // Neighbor connections
        .north_valid(valid[1][ARRAY_HEIGHT-1][0]),
        .north_data(data[1][ARRAY_HEIGHT-1][0]),
        .north_ready(ready[1][ARRAY_HEIGHT-1][0]),
        .north_valid_in(valid[1][ARRAY_HEIGHT-2][2]), // From tile [1][ARRAY_HEIGHT-2] south port
        .north_data_in(data[1][ARRAY_HEIGHT-2][2]),
        .north_ready_out(ready[1][ARRAY_HEIGHT-2][2]),
        
        .east_valid(valid[1][ARRAY_HEIGHT-1][1]),
        .east_data(data[1][ARRAY_HEIGHT-1][1]),
        .east_ready(ready[1][ARRAY_HEIGHT-1][1]),
        .east_valid_in(valid[2][ARRAY_HEIGHT-1][3]), // From tile [2][ARRAY_HEIGHT-1] west port
        .east_data_in(data[2][ARRAY_HEIGHT-1][3]),
        .east_ready_out(ready[2][ARRAY_HEIGHT-1][3]),
        
        .south_valid(valid[1][ARRAY_HEIGHT-1][2]),
        .south_data(data[1][ARRAY_HEIGHT-1][2]),
        .south_ready(ready[1][ARRAY_HEIGHT-1][2]),
        // No south connection for interface tiles at y=ARRAY_HEIGHT-1
        .south_valid_in(1'b0),
        .south_data_in('0),
        .south_ready_out(),
        
        .west_valid(valid[1][ARRAY_HEIGHT-1][3]),
        .west_data(data[1][ARRAY_HEIGHT-1][3]),
        .west_ready(ready[1][ARRAY_HEIGHT-1][3]),
        .west_valid_in(valid[0][ARRAY_HEIGHT-1][1]), // From tile [0][ARRAY_HEIGHT-1] east port
        .west_data_in(data[0][ARRAY_HEIGHT-1][1]),
        .west_ready_out(ready[0][ARRAY_HEIGHT-1][1])
    );
    
    // East Interface Tile (at position [ARRAY_WIDTH-1][1])
    interface_tile #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .TILE_ID_X(ARRAY_WIDTH-1),
        .TILE_ID_Y(1)
    ) east_interface_tile (
        .clock(array_clock),
        .reset(array_reset),
        
        // SoC interface
        .soc_valid(soc_valid && select_east_interface),
        .soc_write(soc_write),
        .soc_addr(soc_addr),
        .soc_wdata(soc_wdata),
        .soc_rdata(soc_rdata_east),
        .soc_ready(soc_ready_east),
        
        // Programmable Logic interface (not connected for east tile)
        .pl_valid(1'b0),
        .pl_data('0),
        .pl_ready(),
        .pl_valid_out(),
        .pl_data_out(),
        .pl_ready_out(1'b1),
        
        // NoC interface
        .noc_valid(noc_valid),
        .noc_data(noc_data),
        .noc_ready(noc_ready),
        .noc_valid_out(noc_valid_out),
        .noc_data_out(noc_data_out),
        .noc_ready_out(noc_ready_out),
        
        // Neighbor connections
        .north_valid(valid[ARRAY_WIDTH-1][1][0]),
        .north_data(data[ARRAY_WIDTH-1][1][0]),
        .north_ready(ready[ARRAY_WIDTH-1][1][0]),
        .north_valid_in(valid[ARRAY_WIDTH-1][0][2]), // From tile [ARRAY_WIDTH-1][0] south port
        .north_data_in(data[ARRAY_WIDTH-1][0][2]),
        .north_ready_out(ready[ARRAY_WIDTH-1][0][2]),
        
        .east_valid(valid[ARRAY_WIDTH-1][1][1]),
        .east_data(data[ARRAY_WIDTH-1][1][1]),
        .east_ready(ready[ARRAY_WIDTH-1][1][1]),
        // No east connection for interface tiles at x=ARRAY_WIDTH-1
        .east_valid_in(1'b0),
        .east_data_in('0),
        .east_ready_out(),
        
        .south_valid(valid[ARRAY_WIDTH-1][1][2]),
        .south_data(data[ARRAY_WIDTH-1][1][2]),
        .south_ready(ready[ARRAY_WIDTH-1][1][2]),
        .south_valid_in(valid[ARRAY_WIDTH-1][2][0]), // From tile [ARRAY_WIDTH-1][2] north port
        .south_data_in(data[ARRAY_WIDTH-1][2][0]),
        .south_ready_out(ready[ARRAY_WIDTH-1][2][0]),
        
        .west_valid(valid[ARRAY_WIDTH-1][1][3]),
        .west_data(data[ARRAY_WIDTH-1][1][3]),
        .west_ready(ready[ARRAY_WIDTH-1][1][3]),
        .west_valid_in(valid[ARRAY_WIDTH-2][1][1]), // From tile [ARRAY_WIDTH-2][1] east port
        .west_data_in(data[ARRAY_WIDTH-2][1][1]),
        .west_ready_out(ready[ARRAY_WIDTH-2][1][1])
    );
    
    // Generate the processing tile array
    genvar x, y;
    generate
        for (y = 0; y < ARRAY_HEIGHT; y++) begin : gen_y_loop
            for (x = 0; x < ARRAY_WIDTH; x++) begin : gen_x_loop
                // Skip positions where special tiles are placed
                if ((x == 0 && y == 0) || // Control tile
                    (x == 1 && y == 0) || // North interface tile
                    (x == 1 && y == ARRAY_HEIGHT-1) || // South interface tile
                    (x == ARRAY_WIDTH-1 && y == 1)) begin // East interface tile
                    // These positions have special tiles already instantiated above
                    // Set done signal to 1 for these positions
                    assign tile_done[x][y] = 1'b1;
                end
                else begin
                    // Regular processing tile
                    processing_tile #(
                        .TILE_ID_X(x),
                        .TILE_ID_Y(y),
                        .VECTOR_WIDTH(VECTOR_WIDTH),
                        .DATA_WIDTH(DATA_WIDTH),
                        .ADDR_WIDTH(ADDR_WIDTH/2),  // Internal address width is smaller
                        .PROG_MEM_SIZE(PROG_MEM_SIZE),
                        .DATA_MEM_BANKS(DATA_MEM_BANKS),
                        .DATA_MEM_SIZE(DATA_MEM_SIZE)
                    ) proc_tile_inst (
                        .clock(array_clock),
                        .reset(array_reset),
                        .enable(tile_enable[x][y]),
                        .start(global_start),
                        .idle(),  // Not connected at the top level
                        .done(tile_done[x][y]),
                        .control_reg(32'h0),  // Default control register
                        .status_reg(),        // Status not used at top level
                        
                        // Memory-mapped interface (not used from top level)
                        .mm_valid(1'b0),
                        .mm_write(1'b0),
                        .mm_addr('0),
                        .mm_wdata('0),
                        .mm_rdata(),
                        .mm_ready(),
                        
                        // Neighbor connections - North
                        .north_valid(valid[x][y][0]),
                        .north_data(data[x][y][0]),
                        .north_ready(ready[x][y][0]),
                        .north_valid_in(y > 0 ? valid[x][y-1][2] : 1'b0), // From tile above (south port)
                        .north_data_in(y > 0 ? data[x][y-1][2] : '0),
                        .north_ready_out(y > 0 ? ready[x][y-1][2] : 1'b0),
                        
                        // East
                        .east_valid(valid[x][y][1]),
                        .east_data(data[x][y][1]),
                        .east_ready(ready[x][y][1]),
                        .east_valid_in(x < ARRAY_WIDTH-1 ? valid[x+1][y][3] : 1'b0), // From tile to right (west port)
                        .east_data_in(x < ARRAY_WIDTH-1 ? data[x+1][y][3] : '0),
                        .east_ready_out(x < ARRAY_WIDTH-1 ? ready[x+1][y][3] : 1'b0),
                        
                        // South
                        .south_valid(valid[x][y][2]),
                        .south_data(data[x][y][2]),
                        .south_ready(ready[x][y][2]),
                        .south_valid_in(y < ARRAY_HEIGHT-1 ? valid[x][y+1][0] : 1'b0), // From tile below (north port)
                        .south_data_in(y < ARRAY_HEIGHT-1 ? data[x][y+1][0] : '0),
                        .south_ready_out(y < ARRAY_HEIGHT-1 ? ready[x][y+1][0] : 1'b0),
                        
                        // West
                        .west_valid(valid[x][y][3]),
                        .west_data(data[x][y][3]),
                        .west_ready(ready[x][y][3]),
                        .west_valid_in(x > 0 ? valid[x-1][y][1] : 1'b0), // From tile to left (east port)
                        .west_data_in(x > 0 ? data[x-1][y][1] : '0),
                        .west_ready_out(x > 0 ? ready[x-1][y][1] : 1'b0)
                    );
                end
            end
        end
    endgenerate

endmodule
>>>>>>> new-content