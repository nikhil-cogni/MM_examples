<<<<<<< HEAD

=======
// scalar_processor.sv
// Generic Hardware Accelerator - Scalar Processor Module
// Supporting unit for control and non-vector operations

module scalar_processor #(
    parameter DATA_WIDTH = 32,         // Width of data path
    parameter ADDR_WIDTH = 12          // Address width
)(
    // Clock and reset
    input  logic clock,
    input  logic reset,
    
    // Control interface
    input  logic enable,                  // Processor enable
    input  logic [DATA_WIDTH-1:0] instruction, // Current instruction
    
    // Data interface
    output logic [DATA_WIDTH-1:0] data_out,    // Output data
    output logic data_valid,                   // Output data valid
    
    // Program memory interface
    output logic [ADDR_WIDTH-1:0] prog_mem_addr, // Program memory address
    output logic prog_mem_read                   // Program memory read enable
);

    // Instruction decode fields
    typedef enum logic [3:0] {
        OP_NOP      = 4'b0000,
        OP_LOAD_IMM = 4'b0001,  // Load immediate
        OP_JUMP     = 4'b0010,  // Jump
        OP_BRANCH   = 4'b0011,  // Conditional branch
        OP_ALU      = 4'b0100,  // ALU operation
        OP_LOAD_PC  = 4'b0101,  // Load program counter
        OP_HALT     = 4'b0110,  // Halt execution
        OP_SYNC     = 4'b0111   // Synchronization
    } op_type_t;
    
    // ALU operations
    typedef enum logic [2:0] {
        ALU_ADD     = 3'b000,
        ALU_SUB     = 3'b001,
        ALU_AND     = 3'b010,
        ALU_OR      = 3'b011,
        ALU_XOR     = 3'b100,
        ALU_SHL     = 3'b101,
        ALU_SHR     = 3'b110,
        ALU_CMP     = 3'b111
    } alu_op_t;
    
    // Instruction fields
    op_type_t op_type;
    logic [ADDR_WIDTH-1:0] op_addr;
    logic [DATA_WIDTH-1:0] op_imm;
    logic [3:0] src_reg, dest_reg;
    logic [2:0] alu_op;
    logic [3:0] condition;
    
    // Register file (16 general-purpose registers)
    logic [DATA_WIDTH-1:0] reg_file [0:15];
    
    // Program counter and next program counter
    logic [ADDR_WIDTH-1:0] pc, next_pc;
    
    // Status register (flags)
    logic zero_flag, negative_flag, overflow_flag, carry_flag;
    
    // Temporary variables for calculations
    logic [DATA_WIDTH-1:0] alu_result;
    logic alu_negative;
    logic alu_zero;
    logic alu_carry;
    logic alu_overflow;
    
    // Pipeline control
    typedef enum logic [1:0] {
        FETCH   = 2'b00,
        DECODE  = 2'b01,
        EXECUTE = 2'b10,
        WRITEBACK = 2'b11
    } pipeline_stage_t;
    
    pipeline_stage_t current_stage;
    logic executing;
    
    // Instruction decode
    always_comb begin
        op_type = op_type_t'(instruction[31:28]);
        src_reg = instruction[27:24];
        dest_reg = instruction[23:20];
        alu_op = instruction[18:16];
        condition = instruction[15:12];
        op_addr = instruction[ADDR_WIDTH-1:0];
        op_imm = {{(DATA_WIDTH-16){instruction[15]}}, instruction[15:0]}; // Sign-extended immediate
    end

    // Main control logic
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            data_valid <= 1'b0;
            data_out <= '0;
            prog_mem_addr <= '0;
            prog_mem_read <= 1'b1; // Start reading instructions
            pc <= '0;
            next_pc <= '0;
            current_stage <= FETCH;
            executing <= 1'b1;
            
            // Reset flags
            zero_flag <= 1'b0;
            negative_flag <= 1'b0;
            overflow_flag <= 1'b0;
            carry_flag <= 1'b0;
            
            // Reset register file
            for (int i = 0; i < 16; i++) begin
                reg_file[i] <= '0;
            end
            
            // Reset temporary variables
            alu_result <= '0;
            alu_negative <= 1'b0;
            alu_zero <= 1'b0;
            alu_carry <= 1'b0;
            alu_overflow <= 1'b0;
        end
        else if (enable && executing) begin
            // Default values
            data_valid <= 1'b0;
            prog_mem_read <= 1'b1;
            
            case (current_stage)
                FETCH: begin
                    // Read instruction from program memory
                    prog_mem_addr <= pc;
                    current_stage <= DECODE;
                end
                
                DECODE: begin
                    // Default next PC (sequential)
                    next_pc <= pc + 1;
                    current_stage <= EXECUTE;
                end
                
                EXECUTE: begin
                    case (op_type)
                        OP_NOP: begin
                            // No operation, just advance PC
                        end
                        
                        OP_LOAD_IMM: begin
                            // Load immediate value into register
                            reg_file[dest_reg] <= op_imm;
                        end
                        
                        OP_JUMP: begin
                            // Unconditional jump
                            next_pc <= op_addr;
                        end
                        
                        OP_BRANCH: begin
                            // Conditional branch
                            case (condition)
                                4'b0000: next_pc <= pc + 1; // No branch
                                4'b0001: next_pc <= zero_flag ? op_addr : pc + 1; // BEQ
                                4'b0010: next_pc <= !zero_flag ? op_addr : pc + 1; // BNE
                                4'b0011: next_pc <= negative_flag ? op_addr : pc + 1; // BLT
                                4'b0100: next_pc <= !negative_flag ? op_addr : pc + 1; // BGE
                                4'b0101: next_pc <= carry_flag ? op_addr : pc + 1; // BC
                                4'b0110: next_pc <= !carry_flag ? op_addr : pc + 1; // BNC
                                4'b0111: next_pc <= overflow_flag ? op_addr : pc + 1; // BV
                                4'b1000: next_pc <= !overflow_flag ? op_addr : pc + 1; // BNV
                                4'b1111: next_pc <= op_addr; // Unconditional (same as JUMP)
                                default: next_pc <= pc + 1;
                            endcase
                        end
                        
                        OP_ALU: begin
                            // ALU operations
                            case (alu_op_t'(alu_op))
                                ALU_ADD: begin
                                    // Calculate result
                                    alu_result <= reg_file[dest_reg] + reg_file[src_reg];
                                    
                                    // Calculate flags
                                    alu_zero <= (reg_file[dest_reg] + reg_file[src_reg]) == 0;
                                    alu_negative <= reg_file[dest_reg][DATA_WIDTH-1] + reg_file[src_reg][DATA_WIDTH-1];
                                    alu_carry <= (reg_file[dest_reg] + reg_file[src_reg]) < reg_file[dest_reg];
                                    alu_overflow <= (reg_file[src_reg][DATA_WIDTH-1] == reg_file[dest_reg][DATA_WIDTH-1]) && 
                                                   (reg_file[dest_reg][DATA_WIDTH-1] != reg_file[src_reg][DATA_WIDTH-1] + reg_file[dest_reg][DATA_WIDTH-1]);
                                    
                                    // Update register
                                    reg_file[dest_reg] <= reg_file[dest_reg] + reg_file[src_reg];
                                    
                                    // Update flags
                                    zero_flag <= (reg_file[dest_reg] + reg_file[src_reg]) == 0;
                                    negative_flag <= reg_file[dest_reg][DATA_WIDTH-1] + reg_file[src_reg][DATA_WIDTH-1];
                                    carry_flag <= (reg_file[dest_reg] + reg_file[src_reg]) < reg_file[dest_reg];
                                    overflow_flag <= (reg_file[src_reg][DATA_WIDTH-1] == reg_file[dest_reg][DATA_WIDTH-1]) && 
                                                     (reg_file[dest_reg][DATA_WIDTH-1] != reg_file[src_reg][DATA_WIDTH-1] + reg_file[dest_reg][DATA_WIDTH-1]);
                                end
                                
                                ALU_SUB: begin
                                    // Calculate result
                                    alu_result <= reg_file[dest_reg] - reg_file[src_reg];
                                    
                                    // Calculate flags
                                    alu_zero <= (reg_file[dest_reg] - reg_file[src_reg]) == 0;
                                    alu_negative <= reg_file[dest_reg][DATA_WIDTH-1] & ~reg_file[src_reg][DATA_WIDTH-1];
                                    alu_carry <= !(reg_file[dest_reg] < reg_file[src_reg]); // Borrow flag (inverted)
                                    alu_overflow <= (reg_file[dest_reg][DATA_WIDTH-1] != reg_file[src_reg][DATA_WIDTH-1]) && 
                                                   (reg_file[src_reg][DATA_WIDTH-1] == reg_file[dest_reg][DATA_WIDTH-1] & ~reg_file[src_reg][DATA_WIDTH-1]);
                                    
                                    // Update register
                                    reg_file[dest_reg] <= reg_file[dest_reg] - reg_file[src_reg];
                                    
                                    // Update flags
                                    zero_flag <= (reg_file[dest_reg] - reg_file[src_reg]) == 0;
                                    negative_flag <= reg_file[dest_reg][DATA_WIDTH-1] & ~reg_file[src_reg][DATA_WIDTH-1];
                                    carry_flag <= !(reg_file[dest_reg] < reg_file[src_reg]); // Borrow flag (inverted)
                                    overflow_flag <= (reg_file[dest_reg][DATA_WIDTH-1] != reg_file[src_reg][DATA_WIDTH-1]) && 
                                                     (reg_file[src_reg][DATA_WIDTH-1] == reg_file[dest_reg][DATA_WIDTH-1] & ~reg_file[src_reg][DATA_WIDTH-1]);
                                end
                                
                                ALU_AND: begin
                                    // Calculate result
                                    alu_result <= reg_file[dest_reg] & reg_file[src_reg];
                                    
                                    // Update register
                                    reg_file[dest_reg] <= reg_file[dest_reg] & reg_file[src_reg];
                                    
                                    // Update flags
                                    zero_flag <= (reg_file[dest_reg] & reg_file[src_reg]) == 0;
                                    negative_flag <= reg_file[dest_reg][DATA_WIDTH-1] & reg_file[src_reg][DATA_WIDTH-1];
                                    overflow_flag <= 1'b0; // Cleared for logical operations
                                    carry_flag <= 1'b0;    // Cleared for logical operations
                                end
                                
                                ALU_OR: begin
                                    // Calculate result
                                    alu_result <= reg_file[dest_reg] | reg_file[src_reg];
                                    
                                    // Update register
                                    reg_file[dest_reg] <= reg_file[dest_reg] | reg_file[src_reg];
                                    
                                    // Update flags
                                    zero_flag <= (reg_file[dest_reg] | reg_file[src_reg]) == 0;
                                    negative_flag <= reg_file[dest_reg][DATA_WIDTH-1] | reg_file[src_reg][DATA_WIDTH-1];
                                    overflow_flag <= 1'b0; // Cleared for logical operations
                                    carry_flag <= 1'b0;    // Cleared for logical operations
                                end
                                
                                ALU_XOR: begin
                                    // Calculate result
                                    alu_result <= reg_file[dest_reg] ^ reg_file[src_reg];
                                    
                                    // Update register
                                    reg_file[dest_reg] <= reg_file[dest_reg] ^ reg_file[src_reg];
                                    
                                    // Update flags
                                    zero_flag <= (reg_file[dest_reg] ^ reg_file[src_reg]) == 0;
                                    negative_flag <= reg_file[dest_reg][DATA_WIDTH-1] ^ reg_file[src_reg][DATA_WIDTH-1];
                                    overflow_flag <= 1'b0; // Cleared for logical operations
                                    carry_flag <= 1'b0;    // Cleared for logical operations
                                end
                                
                                ALU_SHL: begin
                                    // Calculate result for shift left
                                    alu_result <= reg_file[dest_reg] << reg_file[src_reg][4:0];
                                    
                                    // Update register
                                    reg_file[dest_reg] <= reg_file[dest_reg] << reg_file[src_reg][4:0];
                                    
                                    // Update flags
                                    zero_flag <= (reg_file[dest_reg] << reg_file[src_reg][4:0]) == 0;
                                    
                                    // Use separate logic for negative flag calculation
                                    if (reg_file[src_reg][4:0] > 0 && reg_file[src_reg][4:0] < DATA_WIDTH) begin
                                        // Set negative flag based on the MSB of the shifted value
                                        if (reg_file[src_reg][4:0] == 1) begin
                                            negative_flag <= reg_file[dest_reg][DATA_WIDTH-2];
                                        end else if (reg_file[src_reg][4:0] == 2) begin
                                            negative_flag <= reg_file[dest_reg][DATA_WIDTH-3];
                                        end else begin
                                            // For larger shifts, we need to check if any set bits get shifted into MSB position
                                            negative_flag <= |reg_file[dest_reg][DATA_WIDTH-1-reg_file[src_reg][4:0]:0];
                                        end
                                    end else begin
                                        // If shift is 0 or too large
                                        negative_flag <= (reg_file[src_reg][4:0] == 0) ? reg_file[dest_reg][DATA_WIDTH-1] : 1'b0;
                                    end
                                    
                                    // Carry is the last bit shifted out (if shift amount > 0)
                                    if (reg_file[src_reg][4:0] > 0 && reg_file[src_reg][4:0] <= DATA_WIDTH) begin
                                        carry_flag <= reg_file[dest_reg][DATA_WIDTH-reg_file[src_reg][4:0]];
                                    end else begin
                                        carry_flag <= 1'b0;
                                    end
                                    
                                    overflow_flag <= 1'b0; // Not defined for shifts
                                end
                                
                                ALU_SHR: begin
                                    // Calculate result for shift right
                                    alu_result <= reg_file[dest_reg] >> reg_file[src_reg][4:0];
                                    
                                    // Update register
                                    reg_file[dest_reg] <= reg_file[dest_reg] >> reg_file[src_reg][4:0];
                                    
                                    // Update flags
                                    zero_flag <= (reg_file[dest_reg] >> reg_file[src_reg][4:0]) == 0;
                                    negative_flag <= 1'b0; // Always 0 for logical right shift
                                    
                                    // Carry is the last bit shifted out (if shift amount > 0)
                                    if (reg_file[src_reg][4:0] > 0 && reg_file[src_reg][4:0] <= DATA_WIDTH) begin
                                        carry_flag <= reg_file[dest_reg][reg_file[src_reg][4:0]-1];
                                    end else begin
                                        carry_flag <= 1'b0;
                                    end
                                    
                                    overflow_flag <= 1'b0; // Not defined for shifts
                                end
                                
                                ALU_CMP: begin
                                    // Compare operation (like SUB but doesn't store result)
                                    alu_result <= reg_file[dest_reg] - reg_file[src_reg];
                                    
                                    // Update flags
                                    zero_flag <= reg_file[dest_reg] == reg_file[src_reg];
                                    negative_flag <= $signed(reg_file[dest_reg]) < $signed(reg_file[src_reg]);
                                    carry_flag <= !(reg_file[dest_reg] < reg_file[src_reg]); // Borrow flag (inverted)
                                    
                                    // Calculate overflow for signed comparison
                                    overflow_flag <= (reg_file[dest_reg][DATA_WIDTH-1] != reg_file[src_reg][DATA_WIDTH-1]) && 
                                                     (reg_file[src_reg][DATA_WIDTH-1] == reg_file[dest_reg][DATA_WIDTH-1] & ~reg_file[src_reg][DATA_WIDTH-1]);
                                end
                            endcase
                        end
                        
                        OP_LOAD_PC: begin
                            // Load PC from register
                            next_pc <= reg_file[src_reg][ADDR_WIDTH-1:0];
                        end
                        
                        OP_HALT: begin
                            // Halt execution
                            executing <= 1'b0;
                            data_out <= 32'hFFFFFFFF; // Signal completion
                            data_valid <= 1'b1;
                        end
                        
                        OP_SYNC: begin
                            // Synchronization operation
                            // This could be expanded for different sync types
                            case (instruction[19:16])
                                4'h0: begin // Simple barrier
                                    // Just output a flag that can be used for sync
                                    data_out <= 32'hAAAAAAAA;
                                    data_valid <= 1'b1;
                                end
                                4'h1: begin // Output register value
                                    data_out <= reg_file[src_reg];
                                    data_valid <= 1'b1;
                                end
                                default: begin
                                    // Other sync operations could be defined
                                end
                            endcase
                        end
                        
                        default: begin
                            // Unimplemented operation
                        end
                    endcase
                    
                    current_stage <= WRITEBACK;
                end
                
                WRITEBACK: begin
                    // Update PC
                    pc <= next_pc;
                    
                    // Prepare to fetch next instruction
                    prog_mem_addr <= next_pc;
                    current_stage <= FETCH;
                    
                    // For operations that should output data to the system
                    if (!data_valid && (op_type == OP_SYNC || op_type == OP_HALT)) begin
                        data_valid <= 1'b1;
                    end
                end
                
                default: current_stage <= FETCH;
            endcase
        end
        else begin
            // Processor disabled or halted
            prog_mem_read <= 1'b0;
        end
    end

endmodule
>>>>>>> new-content