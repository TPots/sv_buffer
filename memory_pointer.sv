module memory_pointer
#(parameter DATA_WIDTH, parameter DEPTH, parameter POP_ORDER)
(
    input clk, rst_n,
    input push, pop,
    output [$clog2(DEPTH) : 0] read_pointer, write_pointer
);

logic inc_read, inc_write, dec_read, dec_write;

ring_counter #(.WIDTH(DEPTH)) read_counter (
    .clk(clk),
    .rst_n(rst_n),
    .inc(inc_read),
    .dec(dec_read),
    .count(read_pointer)
);

ring_counter #(.WIDTH(DEPTH)) write_counter (
    .clk(clk),
    .rst_n(rst_n),
    .inc(inc_write),
    .dec(dec_write),
    .count(write_pointer)
);

generate
    if (POP_ORDER == "FIFO") begin
        assign inc_read = pop;
        assign dec_read = '0;

        assign inc_write = push;
        assign dec_write = '0;
    end
    else if (POP_ORDER == "FILO") begin
        assign inc_read = push;
        assign dec_read = pop;

        assign inc_write = push;
        assign dec_write = pop;
    end
    else
        $fatal("Parameter <POP_ORDER>=%s, expecting one of [FIFO, FILO]",POP_ORDER);

endgenerate

endmodule

module memory_pointer_tb();
    localparam DATA_WIDTH = 8;
    localparam WIDTH = 8;
    localparam POP_ORDER = "FIFO";

    int pc;
    bit switch;

    logic clk, rst_n;
    logic push, pop;
    logic [$clog2(WIDTH) : 0] read_pointer, write_pointer;

endmodule