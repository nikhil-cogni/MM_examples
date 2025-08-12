
module relu #(
    parameter DATA_WIDTH = 8
)(
    input  logic signed [DATA_WIDTH-1:0] data_in,
    output logic [DATA_WIDTH-1:0] data_out
);

    // ReLU function: f(x) = max(0, x)
    // For signed inputs, pass through if positive, output zero if negative
    assign data_out = data_in[DATA_WIDTH-1] ? '0 : data_in;

endmodule
