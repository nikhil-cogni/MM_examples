<<<<<<< HEAD

=======
// tile_interconnect.sv
// Generic Hardware Accelerator - Tile Interconnect Module
// Provides programmable routing for streams and memory-mapped traffic

module tile_interconnect #(
    parameter DATA_WIDTH = 32,     // Width of data path
    parameter TILE_ID_X = 0,       // X coordinate in the tile array
    parameter TILE_ID_Y = 0        // Y coordinate in the tile array
)(
    // Clock and reset
    input  logic clock,
    input  logic reset,
    
    // Interface with Vector Processor
    input  logic [DATA_WIDTH-1:0] vector_data, // Data from vector processor
    input  logic vector_valid,                // Valid signal from vector processor
    
    // Interface with Scalar Processor
    input  logic [DATA_WIDTH-1:0] scalar_data, // Data from scalar processor
    input  logic scalar_valid,                // Valid signal from scalar processor
    
    // Control interface
    input  logic [31:0] control_reg,         // Control register
    output logic [31:0] status_reg,          // Status register
    
    // North neighbor interface
    output logic                  north_valid_out, 
    output logic [DATA_WIDTH-1:0] north_data_out,
    input  logic                  north_ready_in,
    input  logic                  north_valid_in,
    input  logic [DATA_WIDTH-1:0] north_data_in,
    output logic                  north_ready_out,
    
    // East neighbor interface
    output logic                  east_valid_out,
    output logic [DATA_WIDTH-1:0] east_data_out,
    input  logic                  east_ready_in,
    input  logic                  east_valid_in,
    input  logic [DATA_WIDTH-1:0] east_data_in,
    output logic                  east_ready_out,
    
    // South neighbor interface
    output logic                  south_valid_out,
    output logic [DATA_WIDTH-1:0] south_data_out,
    input  logic                  south_ready_in,
    input  logic                  south_valid_in,
    input  logic [DATA_WIDTH-1:0] south_data_in,
    output logic                  south_ready_out,
    
    // West neighbor interface
    output logic                  west_valid_out,
    output logic [DATA_WIDTH-1:0] west_data_out,
    input  logic                  west_ready_in,
    input  logic                  west_valid_in,
    input  logic [DATA_WIDTH-1:0] west_data_in,
    output logic                  west_ready_out
);

    // Routing modes
    typedef enum logic [2:0] {
        ROUTE_NONE    = 3'b000,
        ROUTE_NORTH   = 3'b001,
        ROUTE_EAST    = 3'b010,
        ROUTE_SOUTH   = 3'b011,
        ROUTE_WEST    = 3'b100,
        ROUTE_ALL     = 3'b111  // Broadcast
    } route_mode_t;
    
    // Source selection
    typedef enum logic [1:0] {
        SRC_NONE        = 2'b00,
        SRC_VECTOR      = 2'b01,
        SRC_SCALAR      = 2'b10,
        SRC_EXTERNAL    = 2'b11  // From other tiles
    } src_select_t;
    
    // Routing configuration (extracted from control register)
    route_mode_t vector_route;
    route_mode_t scalar_route;
    src_select_t north_src_sel;
    src_select_t east_src_sel;
    src_select_t south_src_sel;
    src_select_t west_src_sel;
    
    // Data routing logic
    logic [DATA_WIDTH-1:0] north_data_internal;
    logic [DATA_WIDTH-1:0] east_data_internal;
    logic [DATA_WIDTH-1:0] south_data_internal;
    logic [DATA_WIDTH-1:0] west_data_internal;
    logic north_valid_internal;
    logic east_valid_internal;
    logic south_valid_internal;
    logic west_valid_internal;
    
    // Configuration decoder
    always_comb begin
        // Extract routing configuration from control register
        vector_route = route_mode_t'(control_reg[2:0]);
        scalar_route = route_mode_t'(control_reg[5:3]);
        north_src_sel = src_select_t'(control_reg[7:6]);
        east_src_sel = src_select_t'(control_reg[9:8]);
        south_src_sel = src_select_t'(control_reg[11:10]);
        west_src_sel = src_select_t'(control_reg[13:12]);
        
        // Status register update
        status_reg = {16'h0, 1'b0, west_valid_in, south_valid_in, east_valid_in, north_valid_in,
                      1'b0, scalar_valid, vector_valid, TILE_ID_Y[3:0], TILE_ID_X[3:0]};
    end
    
    // Routing from internal sources to output ports
    always_comb begin
        // Default values
        north_valid_internal = 1'b0;
        east_valid_internal = 1'b0;
        south_valid_internal = 1'b0;
        west_valid_internal = 1'b0;
        
        north_data_internal = '0;
        east_data_internal = '0;
        south_data_internal = '0;
        west_data_internal = '0;
        
        // Vector processor routing
        if (vector_valid) begin
            if (vector_route == ROUTE_NORTH || vector_route == ROUTE_ALL) begin
                north_data_internal = vector_data;
                north_valid_internal = 1'b1;
            end
            
            if (vector_route == ROUTE_EAST || vector_route == ROUTE_ALL) begin
                east_data_internal = vector_data;
                east_valid_internal = 1'b1;
            end
            
            if (vector_route == ROUTE_SOUTH || vector_route == ROUTE_ALL) begin
                south_data_internal = vector_data;
                south_valid_internal = 1'b1;
            end
            
            if (vector_route == ROUTE_WEST || vector_route == ROUTE_ALL) begin
                west_data_internal = vector_data;
                west_valid_internal = 1'b1;
            end
        end
        
        // Scalar processor routing (only if vector is not routing)
        if (scalar_valid && !vector_valid) begin
            if (scalar_route == ROUTE_NORTH || scalar_route == ROUTE_ALL) begin
                north_data_internal = scalar_data;
                north_valid_internal = 1'b1;
            end
            
            if (scalar_route == ROUTE_EAST || scalar_route == ROUTE_ALL) begin
                east_data_internal = scalar_data;
                east_valid_internal = 1'b1;
            end
            
            if (scalar_route == ROUTE_SOUTH || scalar_route == ROUTE_ALL) begin
                south_data_internal = scalar_data;
                south_valid_internal = 1'b1;
            end
            
            if (scalar_route == ROUTE_WEST || scalar_route == ROUTE_ALL) begin
                west_data_internal = scalar_data;
                west_valid_internal = 1'b1;
            end
        end
    end
    
    // Output multiplexers
    always_comb begin
        // North output port
        case (north_src_sel)
            SRC_VECTOR: begin
                north_data_out = vector_data;
                north_valid_out = vector_valid && (vector_route == ROUTE_NORTH || vector_route == ROUTE_ALL);
            end
            
            SRC_SCALAR: begin
                north_data_out = scalar_data;
                north_valid_out = scalar_valid && (scalar_route == ROUTE_NORTH || scalar_route == ROUTE_ALL);
            end
            
            SRC_EXTERNAL: begin
                // Passthrough from another direction (default: south to north)
                north_data_out = south_data_in;
                north_valid_out = south_valid_in;
                south_ready_out = north_ready_in; // Backpressure
            end
            
            default: begin
                north_data_out = '0;
                north_valid_out = 1'b0;
            end
        endcase
        
        // East output port
        case (east_src_sel)
            SRC_VECTOR: begin
                east_data_out = vector_data;
                east_valid_out = vector_valid && (vector_route == ROUTE_EAST || vector_route == ROUTE_ALL);
            end
            
            SRC_SCALAR: begin
                east_data_out = scalar_data;
                east_valid_out = scalar_valid && (scalar_route == ROUTE_EAST || scalar_route == ROUTE_ALL);
            end
            
            SRC_EXTERNAL: begin
                // Passthrough from another direction (default: west to east)
                east_data_out = west_data_in;
                east_valid_out = west_valid_in;
                west_ready_out = east_ready_in; // Backpressure
            end
            
            default: begin
                east_data_out = '0;
                east_valid_out = 1'b0;
            end
        endcase
        
        // South output port
        case (south_src_sel)
            SRC_VECTOR: begin
                south_data_out = vector_data;
                south_valid_out = vector_valid && (vector_route == ROUTE_SOUTH || vector_route == ROUTE_ALL);
            end
            
            SRC_SCALAR: begin
                south_data_out = scalar_data;
                south_valid_out = scalar_valid && (scalar_route == ROUTE_SOUTH || scalar_route == ROUTE_ALL);
            end
            
            SRC_EXTERNAL: begin
                // Passthrough from another direction (default: north to south)
                south_data_out = north_data_in;
                south_valid_out = north_valid_in;
                north_ready_out = south_ready_in; // Backpressure
            end
            
            default: begin
                south_data_out = '0;
                south_valid_out = 1'b0;
            end
        endcase
        
        // West output port
        case (west_src_sel)
            SRC_VECTOR: begin
                west_data_out = vector_data;
                west_valid_out = vector_valid && (vector_route == ROUTE_WEST || vector_route == ROUTE_ALL);
            end
            
            SRC_SCALAR: begin
                west_data_out = scalar_data;
                west_valid_out = scalar_valid && (scalar_route == ROUTE_WEST || scalar_route == ROUTE_ALL);
            end
            
            SRC_EXTERNAL: begin
                // Passthrough from another direction (default: east to west)
                west_data_out = east_data_in;
                west_valid_out = east_valid_in;
                east_ready_out = west_ready_in; // Backpressure
            end
            
            default: begin
                west_data_out = '0;
                west_valid_out = 1'b0;
            end
        endcase
        
        // Set default ready signals for cases not covered by passthrough
        if (north_src_sel != SRC_EXTERNAL) north_ready_out = 1'b1;
        if (east_src_sel != SRC_EXTERNAL) east_ready_out = 1'b1;
        if (south_src_sel != SRC_EXTERNAL) south_ready_out = 1'b1;
        if (west_src_sel != SRC_EXTERNAL) west_ready_out = 1'b1;
    end

endmodule
>>>>>>> new-content