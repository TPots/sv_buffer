module buffer
#(parameter DATA_WIDTH, parameter DEPTH, parameter POP_ORDER = "FIFO")
(
    input logic clk, rst_n, push_en, push, pop_en, pop,
    input logic [ DATA_WIDTH - 1 : 0] data_in,
    output logic [ DATA_WIDTH - 1 : 0] data_out,
    output logic is_empty, is_full, err
);

localparam ADDR_WIDTH = $clog2(DEPTH);

logic [0:DEPTH - 1][DATA_WIDTH - 1 : 0] mem;
logic [ADDR_WIDTH : 0] read_ptr, write_ptr;
logic [DEPTH - 1 : 0] picket;
logic push_c, pop_c, err_c;

/*
generate an error signal under the following conditions:
1. push signal without push enable
2. pop signal without pop enable
3. push signal while the buffer is full
4. pop signal while the buffer is empty
5. simultaneous push and pop signals
*/
assign err_c = 
    ( push & ~push_en ) | 
    ( pop  & ~pop_en )  |
    ( push &  is_full ) |
    ( pop  &  is_empty  )|
    ( pop  &  push );

// register error state.
always_ff @(posedge clk, posedge rst_n) begin
    if (rst_n)
        err <= '0;
    else
        err <= err_c;
end

// allow {push,pop} commands only if both {push,pop} is enabled and there is no error signal.
assign push_c = (push_en & ~err_c & ~is_full) ? push : '0;
assign pop_c = (pop_en & ~err_c & ~is_empty) ? pop : '0;

// instantiate the buffers pointer logic based on the parameter <POP_ORDER>
// generate a fatal error if <POP_ORDER> is not one of {"FIFO","FILO"}
generate
    // FIFO circuit
    if (POP_ORDER == "FIFO") begin : FIFO_POINTER
        // instantiate a registered FIFO pointer
        fifo_ptr #(.DEPTH(DEPTH)) ptr_combinator ( 
            .clk(clk),
            .rst_n(rst_n),
            .push(push_c),
            .pop(pop_c),
            .err(err_c),
            .read_ptr(read_ptr),
            .write_ptr(write_ptr),
            .picket(picket)
        );

    assign is_empty = ~|picket;
    assign is_full = &picket;

    end : FIFO_POINTER
    // FILO circuit
    else if (POP_ORDER == "FILO") begin : FILO_POINTER
        // instantiate a reigstered FILO pointer
        filo_ptr #(.DEPTH(DEPTH)) ptr_combinator ( 
            .clk(clk),
            .rst_n(rst_n),
            .push(push_c),
            .pop(pop_c),
            .err(err_c),
            .read_ptr(read_ptr),
            .write_ptr(write_ptr),
            .picket(picket)
        );

    assign is_empty = ~|picket;
    assign is_full = &picket;

    end : FILO_POINTER
    // default to a fatal error
    else
        $fatal("Parameter <POP_ORDER>=%s, expecting one of [FIFO, FILO]",POP_ORDER);
endgenerate

always_ff @(posedge clk, posedge rst_n) begin
    if (rst_n)
        mem <= '0;
    else if (push_c)
        mem[write_ptr] <= data_in;
    else
        mem <= mem;
end

always_ff @(posedge clk, posedge rst_n) begin
    if (rst_n)
        data_out <= '0;
    else if (pop_c)
        data_out <= mem[read_ptr];
    else
        data_out <= data_out;
end

endmodule

module fifo_ptr
#( parameter DEPTH )
(
    input logic clk, rst_n,
    input logic push, pop, err,
    output logic [$clog2(DEPTH) : 0] read_ptr, write_ptr,
    output logic [DEPTH - 1 : 0] picket
);

logic [$clog2(DEPTH) : 0] read_ptr_next, write_ptr_next;

always_comb begin
    if (rst_n) begin
        write_ptr_next = '0;
        read_ptr_next = '0;
    end
    else begin
        case ({push, pop, err})
            3'b100 : begin
                if (write_ptr == DEPTH - 1'b1)
                    write_ptr_next = '0;
                else
                    write_ptr_next = write_ptr + 1'b1;
                read_ptr_next = read_ptr;
            end
            3'b010 : begin
                write_ptr_next = write_ptr;
                if (read_ptr == DEPTH - 1'b1)
                    read_ptr_next = '0;
                else
                    read_ptr_next = read_ptr + 1'b1;
            end
            default: begin
                write_ptr_next <= write_ptr;
                read_ptr_next <= read_ptr;
            end
        endcase
    end
end

always_ff @(posedge clk, posedge rst_n) begin
    // async reset of the read/write pointers
    if (rst_n) begin
        write_ptr <= '0;
        read_ptr <= '0;
        picket <= 1'b0;
    end
    else begin
        if (push)
            write_ptr <= write_ptr_next;
        else
            write_ptr <= write_ptr;

        if (pop)
            read_ptr <= read_ptr_next;
        else
            read_ptr <= read_ptr;

        if (push)
            picket <= (picket << 1'b1) + 1'b1;
        else if (pop)
            picket <= picket >> 1'b1;
        else
            picket <= picket;
    end
end
endmodule

module filo_ptr
#( parameter DEPTH)
(
    input logic clk, rst_n,
    input logic push, pop, err,
    output logic [$clog2(DEPTH) - 1: 0] read_ptr, write_ptr,
    output logic [DEPTH - 1 : 0] picket
);

logic [$clog2(DEPTH) - 1 : 0] read_ptr_next, write_ptr_next;

always_comb begin

    if (rst_n) begin
        write_ptr_next <= '0;
        read_ptr_next <= '0;
    end
    else begin
        case ({push, pop, err})
            3'b100 : begin
                // next value for the write pointer on push 
                if ( write_ptr == DEPTH - 1'b1 )
                    write_ptr_next <= write_ptr;
                else
                    write_ptr_next <= write_ptr + 1'b1;

                // next value for the read pointer on push
                if ( read_ptr == DEPTH - 1'b1 )
                    read_ptr_next <= read_ptr;
                else
                    read_ptr_next <= read_ptr + 1'b1;
            end
            3'b010 : begin
                // next value for the write pointer on pop 
                if ( write_ptr == '0 )
                    write_ptr_next <= write_ptr;
                else
                    write_ptr_next <= write_ptr - 1'b1;

                // next value for the read pointer on pop
                if ( read_ptr == '0 )
                    read_ptr_next <= read_ptr;
                else
                    read_ptr_next <= read_ptr - 1'b1;
            end                
            default: begin
                // default to holding existing register values
                write_ptr_next <= write_ptr;
                read_ptr_next <= read_ptr;
            end
        endcase
    end
end

always_ff @(posedge clk, posedge rst_n) begin
    // async reset of the write and read pointers
    if (rst_n) begin
        write_ptr <= '0;
        read_ptr <= '0;
        picket <= 1'b0;
    end
    else begin
        if (push || pop) begin
            write_ptr <= write_ptr_next;
            read_ptr <= read_ptr_next;
        end
        else begin
            write_ptr <= write_ptr;
            read_ptr <= read_ptr;
        end

        if (push)
            picket <= (picket << 1'b1) + 1'b1;
        else if (pop)
            picket <= picket >> 1'b1;
        else
            picket <= picket;
    end


    
end
endmodule

module buffer_tb();

localparam DATA_WIDTH = 8;
localparam DEPTH = 8;
localparam POP_ORDER = "FILO"; 

int pc;

logic clk, rst_n, push_en, push, pop_en, pop; // inputs
logic [ DATA_WIDTH - 1 : 0] data_in, data_out; // data
logic is_empty, is_full, err; // outptus

logic [11:0] io_group;

buffer #(.DATA_WIDTH(DATA_WIDTH),.DEPTH(DEPTH),.POP_ORDER(POP_ORDER)) DUT(.*);

initial begin
    clk = '0;
    rst_n = '1;
    #1;
    rst_n = '0;
    forever begin
        clk <= ~clk;
        #1;
    end
end

always_comb begin
        case (pc)
        0: io_group = {1'b1, 1'b1, 1'b0, 1'b0, 8'h1}; // push 1
        1: io_group = {1'b1, 1'b1, 1'b0, 1'b0, 8'h2}; // push 2
        2: io_group = {1'b1, 1'b1, 1'b0, 1'b0, 8'h3}; // push 3
        3: io_group = {1'b1, 1'b1, 1'b0, 1'b0, 8'h4}; // push 4
        4: io_group = {1'b1, 1'b1, 1'b0, 1'b0, 8'h5}; // push 5
        5: io_group = {1'b1, 1'b1, 1'b0, 1'b0, 8'h6}; // push 6
        6: io_group = {1'b1, 1'b1, 1'b0, 1'b0, 8'h7}; // push 7
        7: io_group = {1'b1, 1'b1, 1'b0, 1'b0, 8'h8}; // push 8
        9: io_group = {1'b0, 1'b0, 1'b1, 1'b1, 8'h0}; // pop
        10: io_group = {1'b0, 1'b0, 1'b1, 1'b1, 8'h0}; // pop
        11: io_group = {1'b0, 1'b0, 1'b1, 1'b1, 8'h0}; // pop
        12: io_group = {1'b1, 1'b0, 1'b0, 1'b0, 8'h9}; // pause
        13: io_group = {1'b1, 1'b1, 1'b0, 1'b0, 8'h9}; // push 9
        14: io_group = {1'b1, 1'b1, 1'b0, 1'b0, 8'ha}; // push 10
        15: io_group = {1'b1, 1'b1, 1'b0, 1'b0, 8'hb}; // push 11
        16: io_group = {1'b0, 1'b0, 1'b1, 1'b1, 8'h0}; // pause
        17: io_group = {1'b0, 1'b0, 1'b1, 1'b1, 8'h0}; // pop
        18: io_group = {1'b0, 1'b0, 1'b1, 1'b1, 8'h0}; // pop
        19: io_group = {1'b0, 1'b0, 1'b1, 1'b1, 8'h0}; // pop
        20: io_group = {1'b0, 1'b0, 1'b1, 1'b1, 8'h0};
        21: io_group = {1'b0, 1'b0, 1'b1, 1'b1, 8'h0};
        22: io_group = {1'b0, 1'b0, 1'b1, 1'b1, 8'h0};
        23: io_group = {1'b0, 1'b0, 1'b1, 1'b1, 8'h0};
        default: io_group = '0;
    endcase
    {push_en, push, pop_en, pop, data_in} = io_group;
end

always_ff @(negedge clk) begin
    if (rst_n) begin
        pc <= '0;
    end
    else begin
        pc = pc + 1'b1;
    end
end


endmodule