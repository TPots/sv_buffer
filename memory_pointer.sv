module memory_pointer
#(parameter DATA_WIDTH, parameter DEPTH, parameter POP_ORDER)
(
    input logic clk, rst_n,
    input logic push, pop,
    output logic [$clog2(DEPTH) - 1 : 0] read_pointer, write_pointer,
    output logic [DEPTH - 1 : 0] picket
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

always_ff @( posedge clk, posedge rst_n ) begin
    if ( rst_n )
        picket <= '0;
    else begin
        if ( push )
            picket <= { picket[DEPTH - 2 : 0], 1'b1 };
        else if ( pop )
            picket <= { 1'b0, picket[DEPTH - 1 : 1] };
        else
            picket <= picket;
    end
end
endmodule

module memory_pointer_fifo_tb();

    localparam DATA_WIDTH = 8;
    localparam DEPTH = 8;
    localparam POP_ORDER = "FIFO";

    int count;
    bit switch;
    logic clk, rst_n;
    logic push, pop;
    logic [$clog2(DEPTH) - 1 : 0] read_pointer, write_pointer;
    logic [DEPTH - 1 : 0] picket;

    memory_pointer #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH), .POP_ORDER(POP_ORDER)) DUT (
        .clk(clk),
        .rst_n(rst_n),
        .push(push),
        .pop(pop),
        .read_pointer(read_pointer),
        .write_pointer(write_pointer),
        .picket(picket)
    );

    initial begin
        clk <= '0;
        rst_n <= '1;
        push <= '0;
        pop <= '0;
        switch <= '0;
        count <= '0;
        #5;
        rst_n <= '0;
        forever begin
            clk <= ~clk; #1;
        end
        forever begin
            repeat (8) @(posedge clk) begin
                push <= ~push;
            end
            repeat (8) @(posedge clk) begin
                pop <= ~pop;
            end
        end
    end

    always @( posedge clk ) begin
        if ( count == '0)
            switch = 1'b1;
        else if ( count == 2 * DEPTH )
            switch = 1'b0;
        else
            switch = switch;

        if ( switch )
            count = count + 1'b1;
        else
            count = count - 1'b1;

        if ( switch )
            push = ~push;
        else
            push = '0;

        if ( ~switch )
            pop = ~pop;
        else
            pop = '0;
    end
endmodule

module memory_pointer_filo_tb();

    localparam DATA_WIDTH = 8;
    localparam DEPTH = 8;
    localparam POP_ORDER = "FILO";

    int count;
    bit switch;
    logic clk, rst_n;
    logic push, pop;
    logic [$clog2(DEPTH) - 1 : 0] read_pointer, write_pointer;
    logic [DEPTH - 1 : 0] picket;

    memory_pointer #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH), .POP_ORDER(POP_ORDER)) DUT (
        .clk(clk),
        .rst_n(rst_n),
        .push(push),
        .pop(pop),
        .read_pointer(read_pointer),
        .write_pointer(write_pointer),
        .picket(picket)
    );

    initial begin
        clk <= '0;
        rst_n <= '1;
        push <= '0;
        pop <= '0;
        switch <= '0;
        count <= '0;
        #5;
        rst_n <= '0;
        forever begin
            clk <= ~clk; #1;
        end
        forever begin
            repeat (8) @(posedge clk) begin
                push <= ~push;
            end
            repeat (8) @(posedge clk) begin
                pop <= ~pop;
            end
        end
    end

    always @( posedge clk ) begin
        if ( count == '0)
            switch = 1'b1;
        else if ( count == 2 * DEPTH )
            switch = 1'b0;
        else
            switch = switch;

        if ( switch )
            count = count + 1'b1;
        else
            count = count - 1'b1;

        if ( switch )
            push = ~push;
        else
            push = '0;

        if ( ~switch )
            pop = ~pop;
        else
            pop = '0;
    end
endmodule