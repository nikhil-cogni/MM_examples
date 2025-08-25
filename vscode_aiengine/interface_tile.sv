<<<<<<< HEAD

=======
// interface_tile.sv
// Generic Hardware Accelerator - Interface Tile Module
// Special tile for communication with external system buses and programmable logic

module interface_tile #(
    parameter DATA_WIDTH = 32,      // Width of data path
    parameter ADDR_WIDTH = 32,      // Address width for external interface
    parameter TILE_ID_X = 0,        // X coordinate in the tile array
    parameter TILE_ID_Y = 0         // Y coordinate in the tile array
)(
    // Clock and reset
    input  logic         clock,          // Main clock
    input  logic         reset,          // Active high reset
    
    // External system interface (memory-mapped)
    input  logic         soc_valid,      // Transaction valid
    input  logic         soc_write,      // 1: Write, 0: Read
    input  logic [ADDR_WIDTH-1:0] soc_addr,  // Address
    input  logic [DATA_WIDTH-1:0] soc_wdata, // Write data
    output logic [DATA_WIDTH-1:0] soc_rdata, // Read data
    output logic         soc_ready,      // Transaction ready
    
    // Programmable Logic (PL) interface (streaming)
    input  logic         pl_valid,       // Stream valid
    input  logic [DATA_WIDTH-1:0] pl_data,   // Stream data
    output logic         pl_ready,       // Stream ready
    output logic         pl_valid_out,   // Output stream valid
    output logic [DATA_WIDTH-1:0] pl_data_out, // Output stream data
    input  logic         pl_ready_out,   // Output stream ready
    
    // On-Chip Network (NoC) interface
    input  logic         noc_valid,      // Stream valid
    input  logic [DATA_WIDTH-1:0] noc_data,  // Stream data
    output logic         noc_ready,      // Stream ready
    output logic         noc_valid_out,  // Output stream valid
    output logic [DATA_WIDTH-1:0] noc_data_out, // Output stream data
    input  logic         noc_ready_out,  // Output stream ready
    
    // Neighbor tile interfaces (standard tile interface)
    output logic         north_valid,    // North valid
    output logic [DATA_WIDTH-1:0] north_data, // North data
    input  logic         north_ready,    // North ready
    input  logic         north_valid_in, // North input valid
    input  logic [DATA_WIDTH-1:0] north_data_in, // North input data
    output logic         north_ready_out, // North input ready
    
    output logic         south_valid,    // South valid
    output logic [DATA_WIDTH-1:0] south_data, // South data
    input  logic         south_ready,    // South ready
    input  logic         south_valid_in, // South input valid
    input  logic [DATA_WIDTH-1:0] south_data_in, // South input data
    output logic         south_ready_out, // South input ready
    
    output logic         east_valid,     // East valid
    output logic [DATA_WIDTH-1:0] east_data,  // East data
    input  logic         east_ready,     // East ready
    input  logic         east_valid_in,  // East input valid
    input  logic [DATA_WIDTH-1:0] east_data_in, // East input data
    output logic         east_ready_out, // East input ready
    
    output logic         west_valid,     // West valid
    output logic [DATA_WIDTH-1:0] west_data,  // West data
    input  logic         west_ready,     // West ready
    input  logic         west_valid_in,  // West input valid
    input  logic [DATA_WIDTH-1:0] west_data_in, // West input data
    output logic         west_ready_out  // West input ready
);

    // Control and status registers
    logic [31:0] control_reg;
    logic [31:0] status_reg;
    logic [31:0] routing_reg;   // Routing configuration
    logic [31:0] addr_map_reg;  // Address mapping configuration
    
    // SoC register address decode
    localparam ADDR_CONTROL  = 32'h0000_0000;
    localparam ADDR_STATUS   = 32'h0000_0004;
    localparam ADDR_ROUTING  = 32'h0000_0008;
    localparam ADDR_ADDR_MAP = 32'h0000_000C;
    localparam ADDR_FIFO     = 32'h0000_0100; // Base address for FIFO data
    
    // FIFO interfaces
    logic [DATA_WIDTH-1:0] fifo_in_data;
    logic fifo_in_valid;
    logic fifo_in_ready;
    logic [DATA_WIDTH-1:0] fifo_out_data;
    logic fifo_out_valid;
    logic fifo_out_ready;
    
    // Source selection (from routing_reg)
    logic [1:0] soc_route_sel;
    logic [1:0] pl_route_sel;
    logic [1:0] noc_route_sel;
    logic [1:0] north_route_sel;
    logic [1:0] south_route_sel;
    logic [1:0] east_route_sel;
    logic [1:0] west_route_sel;
    
    // Source selection decoding
    always_comb begin
        // Extract routing configuration
        soc_route_sel = routing_reg[1:0];
        pl_route_sel = routing_reg[3:2];
        noc_route_sel = routing_reg[5:4];
        north_route_sel = routing_reg[7:6];
        south_route_sel = routing_reg[9:8];
        east_route_sel = routing_reg[11:10];
        west_route_sel = routing_reg[13:12];
    end
    
    // SoC interface register handling
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            control_reg <= 32'h0000_0000;
            routing_reg <= 32'h0000_0000;
            addr_map_reg <= 32'h0000_0000;
            soc_rdata <= '0;
            soc_ready <= 1'b0;
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
                        ADDR_ROUTING: routing_reg <= soc_wdata;
                        ADDR_ADDR_MAP: addr_map_reg <= soc_wdata;
                        ADDR_FIFO: begin
                            // Write to FIFO
                            fifo_in_data <= soc_wdata;
                            fifo_in_valid <= 1'b1;
                        end
                    endcase
                end
                else begin
                    // Read from registers
                    case (soc_addr)
                        ADDR_CONTROL: soc_rdata <= control_reg;
                        ADDR_STATUS: soc_rdata <= status_reg;
                        ADDR_ROUTING: soc_rdata <= routing_reg;
                        ADDR_ADDR_MAP: soc_rdata <= addr_map_reg;
                        ADDR_FIFO: begin
                            // Read from FIFO
                            soc_rdata <= fifo_out_data;
                            fifo_out_ready <= 1'b1;
                        end
                        default: soc_rdata <= 32'hDEAD_BEEF; // Invalid address
                    endcase
                end
            end
            else begin
                fifo_in_valid <= 1'b0;
                fifo_out_ready <= 1'b0;
            end
        end
    end
    
    // Status register update
    always_comb begin
        status_reg = {16'h0, 
                      fifo_out_valid, fifo_in_ready, // FIFO status
                      noc_valid, pl_valid, soc_valid, // External interface status
                      west_valid_in, south_valid_in, east_valid_in, north_valid_in, // Neighbor status
                      TILE_ID_Y[3:0], TILE_ID_X[3:0]}; // Tile coordinates
    end
    
    // Data routing logic for external interfaces
    always_comb begin
        // Default values
        pl_ready = 1'b0;
        noc_ready = 1'b0;
        pl_valid_out = 1'b0;
        noc_valid_out = 1'b0;
        pl_data_out = '0;
        noc_data_out = '0;
        
        // Route PL interface
        case (pl_route_sel)
            2'b00: begin // To north tile
                north_data = pl_data;
                north_valid = pl_valid;
                pl_ready = north_ready;
            end
            2'b01: begin // To NoC
                noc_data_out = pl_data;
                noc_valid_out = pl_valid;
                pl_ready = noc_ready_out;
            end
            2'b10: begin // To FIFO
                fifo_in_data = pl_data;
                fifo_in_valid = pl_valid;
                pl_ready = fifo_in_ready;
            end
            default: pl_ready = 1'b0; // Disabled
        endcase
        
        // Route NoC interface
        case (noc_route_sel)
            2'b00: begin // To south tile
                south_data = noc_data;
                south_valid = noc_valid;
                noc_ready = south_ready;
            end
            2'b01: begin // To PL
                pl_data_out = noc_data;
                pl_valid_out = noc_valid;
                noc_ready = pl_ready_out;
            end
            2'b10: begin // To FIFO
                fifo_in_data = noc_data;
                fifo_in_valid = noc_valid;
                noc_ready = fifo_in_ready;
            end
            default: noc_ready = 1'b0; // Disabled
        endcase
        
        // FIFO output routing is handled in the SoC interface for register reads
    end
    
    // Tile interconnect for neighboring tiles
    tile_interconnect #(
        .DATA_WIDTH(DATA_WIDTH),
        .TILE_ID_X(TILE_ID_X),
        .TILE_ID_Y(TILE_ID_Y)
    ) tile_interconnect_inst (
        .clock(clock),
        .reset(reset),
        .vector_data(fifo_out_data),  // Use FIFO output as "vector" data
        .vector_valid(fifo_out_valid),
        .scalar_data(soc_wdata),      // Use SoC write data as "scalar" data
        .scalar_valid(soc_valid && soc_write && (soc_addr == ADDR_FIFO)),
        .control_reg(control_reg),
        .status_reg(),                // Status output not used here
        
        // North neighbor interface
        .north_valid_out(north_valid),
        .north_data_out(north_data),
        .north_ready_in(north_ready),
        .north_valid_in(north_valid_in),
        .north_data_in(north_data_in),
        .north_ready_out(north_ready_out),
        
        // East neighbor interface
        .east_valid_out(east_valid),
        .east_data_out(east_data),
        .east_ready_in(east_ready),
        .east_valid_in(east_valid_in),
        .east_data_in(east_data_in),
        .east_ready_out(east_ready_out),
        
        // South neighbor interface
        .south_valid_out(south_valid),
        .south_data_out(south_data),
        .south_ready_in(south_ready),
        .south_valid_in(south_valid_in),
        .south_data_in(south_data_in),
        .south_ready_out(south_ready_out),
        
        // West neighbor interface
        .west_valid_out(west_valid),
        .west_data_out(west_data),
        .west_ready_in(west_ready),
        .west_valid_in(west_valid_in),
        .west_data_in(west_data_in),
        .west_ready_out(west_ready_out)
    );
    
    // FIFO instance for buffering data
    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(16)  // 16 entries
    ) data_fifo (
        .clock(clock),
        .reset(reset),
        .write_data(fifo_in_data),
        .write_valid(fifo_in_valid),
        .write_ready(fifo_in_ready),
        .read_data(fifo_out_data),
        .read_valid(fifo_out_valid),
        .read_ready(fifo_out_ready)
    );

endmodule
>>>>>>> new-content