<<<<<<< HEAD

=======
// vector_processor.sv
// Generic Hardware Accelerator - Vector Processor Module
// Optimized for arithmetic-heavy workloads with wide vector operations

module vector_processor #(
    parameter VECTOR_WIDTH = 256,      // Width of vector operations
    parameter DATA_WIDTH = 32,         // Width of data path
    parameter ADDR_WIDTH = 12          // Address width
)(
    // Clock and reset
    input  logic clock,
    input  logic reset,
    
    // Control interface
    input  logic enable,               // Processor enable
    input  logic [DATA_WIDTH-1:0] instruction, // Current instruction
    
    // Data interface
    input  logic [DATA_WIDTH-1:0] data_in,     // Input data
    output logic [DATA_WIDTH-1:0] data_out,    // Output data
    output logic data_valid,                   // Output data valid
    
    // Memory interface
    output logic [ADDR_WIDTH-1:0] data_mem_addr,  // Memory address
    output logic data_mem_we,                     // Memory write enable
    output logic data_mem_re,                     // Memory read enable
    output logic [$clog2(VECTOR_WIDTH/DATA_WIDTH)-1:0] data_mem_bank_sel // Bank select
);

    // Instruction decode fields
    typedef enum logic [3:0] {
        OP_NOP      = 4'b0000,
        OP_LOAD     = 4'b0001,
        OP_STORE    = 4'b0010,
        OP_ADD      = 4'b0011,
        OP_SUB      = 4'b0100,
        OP_MUL      = 4'b0101,
        OP_MAC      = 4'b0110, // Multiply-accumulate
        OP_SHIFT    = 4'b0111,
        OP_COMPARE  = 4'b1000,
        OP_MOVE     = 4'b1001
    } op_type_t;
    
    // Instruction fields
    op_type_t op_type;
    logic [ADDR_WIDTH-1:0] op_addr;
    logic [4:0] op_size;    // Size of vector operation
    logic [7:0] op_flags;  // Operation flags/modifiers
    
    // Vector register file
    localparam NUM_VECTOR_REGS = 16;
    localparam VECTOR_ELEMENTS = VECTOR_WIDTH / DATA_WIDTH;
    
    // Vector register file (16 vector registers, each with multiple elements)
    logic [DATA_WIDTH-1:0] vector_reg [NUM_VECTOR_REGS-1:0][VECTOR_ELEMENTS-1:0];
    
    // Accumulator register for MAC operations
    logic [DATA_WIDTH*2-1:0] acc_reg [VECTOR_ELEMENTS-1:0];
    
    // Register indexes
    logic [3:0] src_reg1, src_reg2, dest_reg;
    
    // Pipeline stages
    typedef enum logic [1:0] {
        FETCH    = 2'b00,
        DECODE   = 2'b01,
        EXECUTE  = 2'b10,
        WRITEBACK = 2'b11
    } pipeline_stage_t;
    
    pipeline_stage_t current_stage;
    
    // Vector processing state
    logic [$clog2(VECTOR_ELEMENTS):0] vec_idx;
    logic vec_processing;
    logic [DATA_WIDTH-1:0] result;
    
    // Instruction decode
    always_comb begin
        op_type = op_type_t'(instruction[31:28]);
        src_reg1 = instruction[27:24];
        src_reg2 = instruction[23:20];
        dest_reg = instruction[19:16];
        op_addr = instruction[ADDR_WIDTH-1:0];
        op_size = instruction[12:8];
        op_flags = instruction[7:0];
    end

    // Main control logic
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            data_valid <= 1'b0;
            data_out <= '0;
            data_mem_we <= 1'b0;
            data_mem_re <= 1'b0;
            data_mem_addr <= '0;
            data_mem_bank_sel <= '0;
            vec_processing <= 1'b0;
            vec_idx <= '0;
            current_stage <= FETCH;
            
            // Reset vector registers
            for (int i = 0; i < NUM_VECTOR_REGS; i++) begin
                for (int j = 0; j < VECTOR_ELEMENTS; j++) begin
                    vector_reg[i][j] <= '0;
                end
            end
            
            // Reset accumulator
            for (int i = 0; i < VECTOR_ELEMENTS; i++) begin
                acc_reg[i] <= '0;
            end
        end
        else if (enable) begin
            // Default values
            data_valid <= 1'b0;
            data_mem_we <= 1'b0;
            data_mem_re <= 1'b0;
            
            case (current_stage)
                FETCH: begin
                    // Instruction already fetched externally
                    current_stage <= DECODE;
                end
                
                DECODE: begin
                    // Initialize vector processing
                    vec_idx <= '0;
                    vec_processing <= 1'b1;
                    current_stage <= EXECUTE;
                    
                    // Prepare memory access for load/store
                    if (op_type == OP_LOAD) begin
                        data_mem_addr <= op_addr;
                        data_mem_bank_sel <= '0;
                        data_mem_re <= 1'b1;
                    end
                    else if (op_type == OP_STORE) begin
                        data_mem_addr <= op_addr;
                        data_mem_bank_sel <= '0;
                        data_mem_we <= 1'b1;
                        data_out <= vector_reg[src_reg1][0];
                    end
                end
                
                EXECUTE: begin
                    // Vector processing
                    if (vec_processing) begin
                        case (op_type)
                            OP_LOAD: begin
                                // Load data from memory into vector register
                                if (vec_idx < op_size) begin
                                    vector_reg[dest_reg][vec_idx] <= data_in;
                                    data_mem_bank_sel <= vec_idx[$clog2(VECTOR_WIDTH/DATA_WIDTH)-1:0] + 1;
                                    data_mem_addr <= op_addr + vec_idx;
                                    vec_idx <= vec_idx + 1;
                                end
                                else begin
                                    vec_processing <= 1'b0;
                                    data_mem_re <= 1'b0;
                                    current_stage <= WRITEBACK;
                                end
                            end
                            
                            OP_STORE: begin
                                // Store data from vector register to memory
                                if (vec_idx < op_size) begin
                                    if (vec_idx > 0) begin  // First element already prepared in DECODE
                                        data_out <= vector_reg[src_reg1][vec_idx];
                                    end
                                    data_mem_bank_sel <= vec_idx[$clog2(VECTOR_WIDTH/DATA_WIDTH)-1:0] + 1;
                                    data_mem_addr <= op_addr + vec_idx;
                                    vec_idx <= vec_idx + 1;
                                end
                                else begin
                                    vec_processing <= 1'b0;
                                    data_mem_we <= 1'b0;
                                    current_stage <= WRITEBACK;
                                end
                            end
                            
                            OP_ADD: begin
                                // Vector addition
                                if (vec_idx < op_size) begin
                                    vector_reg[dest_reg][vec_idx] <= vector_reg[src_reg1][vec_idx] + vector_reg[src_reg2][vec_idx];
                                    vec_idx <= vec_idx + 1;
                                end
                                else begin
                                    vec_processing <= 1'b0;
                                    current_stage <= WRITEBACK;
                                end
                            end
                            
                            OP_SUB: begin
                                // Vector subtraction
                                if (vec_idx < op_size) begin
                                    vector_reg[dest_reg][vec_idx] <= vector_reg[src_reg1][vec_idx] - vector_reg[src_reg2][vec_idx];
                                    vec_idx <= vec_idx + 1;
                                end
                                else begin
                                    vec_processing <= 1'b0;
                                    current_stage <= WRITEBACK;
                                end
                            end
                            
                            OP_MUL: begin
                                // Vector multiplication
                                if (vec_idx < op_size) begin
                                    vector_reg[dest_reg][vec_idx] <= vector_reg[src_reg1][vec_idx] * vector_reg[src_reg2][vec_idx];
                                    vec_idx <= vec_idx + 1;
                                end
                                else begin
                                    vec_processing <= 1'b0;
                                    current_stage <= WRITEBACK;
                                end
                            end
                            
                            OP_MAC: begin
                                // Vector multiply-accumulate
                                if (vec_idx < op_size) begin
                                    acc_reg[vec_idx] <= acc_reg[vec_idx] + (vector_reg[src_reg1][vec_idx] * vector_reg[src_reg2][vec_idx]);
                                    vec_idx <= vec_idx + 1;
                                end
                                else begin
                                    // Transfer accumulator to vector register
                                    for (int i = 0; i < VECTOR_ELEMENTS; i++) begin
                                        if (i < op_size) begin
                                            vector_reg[dest_reg][i] <= acc_reg[i][DATA_WIDTH-1:0];
                                        end
                                    end
                                    vec_processing <= 1'b0;
                                    current_stage <= WRITEBACK;
                                end
                            end
                            
                            OP_SHIFT: begin
                                // Vector shift
                                if (vec_idx < op_size) begin
                                    if (op_flags[0]) // Right shift
                                        vector_reg[dest_reg][vec_idx] <= vector_reg[src_reg1][vec_idx] >> vector_reg[src_reg2][0][4:0];
                                    else // Left shift
                                        vector_reg[dest_reg][vec_idx] <= vector_reg[src_reg1][vec_idx] << vector_reg[src_reg2][0][4:0];
                                    vec_idx <= vec_idx + 1;
                                end
                                else begin
                                    vec_processing <= 1'b0;
                                    current_stage <= WRITEBACK;
                                end
                            end
                            
                            OP_COMPARE: begin
                                // Vector compare
                                if (vec_idx < op_size) begin
                                    case (op_flags[2:0])
                                        3'b000: vector_reg[dest_reg][vec_idx] <= vector_reg[src_reg1][vec_idx] == vector_reg[src_reg2][vec_idx] ? '1 : '0; // Equal
                                        3'b001: vector_reg[dest_reg][vec_idx] <= vector_reg[src_reg1][vec_idx] != vector_reg[src_reg2][vec_idx] ? '1 : '0; // Not equal
                                        3'b010: vector_reg[dest_reg][vec_idx] <= $signed(vector_reg[src_reg1][vec_idx]) < $signed(vector_reg[src_reg2][vec_idx]) ? '1 : '0; // Less than
                                        3'b011: vector_reg[dest_reg][vec_idx] <= $signed(vector_reg[src_reg1][vec_idx]) <= $signed(vector_reg[src_reg2][vec_idx]) ? '1 : '0; // Less than or equal
                                        3'b100: vector_reg[dest_reg][vec_idx] <= $signed(vector_reg[src_reg1][vec_idx]) > $signed(vector_reg[src_reg2][vec_idx]) ? '1 : '0; // Greater than
                                        3'b101: vector_reg[dest_reg][vec_idx] <= $signed(vector_reg[src_reg1][vec_idx]) >= $signed(vector_reg[src_reg2][vec_idx]) ? '1 : '0; // Greater than or equal
                                        default: vector_reg[dest_reg][vec_idx] <= '0;
                                    endcase
                                    vec_idx <= vec_idx + 1;
                                end
                                else begin
                                    vec_processing <= 1'b0;
                                    current_stage <= WRITEBACK;
                                end
                            end
                            
                            OP_MOVE: begin
                                // Vector move
                                if (vec_idx < op_size) begin
                                    vector_reg[dest_reg][vec_idx] <= vector_reg[src_reg1][vec_idx];
                                    vec_idx <= vec_idx + 1;
                                end
                                else begin
                                    vec_processing <= 1'b0;
                                    current_stage <= WRITEBACK;
                                end
                            end
                            
                            default: begin
                                // NOP or unsupported operation
                                vec_processing <= 1'b0;
                                current_stage <= WRITEBACK;
                            end
                        endcase
                    end
                    else begin
                        current_stage <= WRITEBACK;
                    end
                end
                
                WRITEBACK: begin
                    // Signal operation completion
                    data_valid <= 1'b1;
                    data_out <= vector_reg[dest_reg][0];
                    current_stage <= FETCH;
                end
                
                default: current_stage <= FETCH;
            endcase
        end
    end

endmodule
>>>>>>> new-content