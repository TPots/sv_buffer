module buffer
#(parameter DATA_WIDTH, parameter DEPTH, parameter POP_ORDER = "FIFO")
(
    input logic clk, rst_n,
    input logic pop, push, pop_ack;
    input logic [DATA_WIDTH - 1 : 0] data_in,
    output logic [DATA_WIDTH - 1 : 0] data_out,
    output logic is_full, is_empty, is_ready, is_done,
);

localparam ADDR_WIDTH = $clog2(DEPTH);
logic [ADDR_WIDTH - 1 : 0] read_pointer, write_pointer;

logic [DEPTH - 1 : 0] read_write_picket;

logic [DATA_WIDTH - 1 : 0] memory [DEPTH];

enum logic[2 : 0] {
    INIT = 1,
    READY,
    PUSH,
    POP,
    DONE
} STATES;

STATES state_current, state_next;

// buffer state machine
always_comb begin
    if (rst_n)
        state_next = '0;
    else begin
        case(state)
            INIT: state_next = READY;
            READY: state_next = push ? PUSH :
                                pop ? POP :
                                READY;
            PUSH: state_next = READY;
            POP: state_next = DONE;
            DONE: state_next = pop_ack ? DONE : READY;
            default: state_next = INIT;
        endcase
    end
end

always_comb begin
    is_ready = state_current == READY; // signal the buffer is ready for data
    is_done = state_current == DONE; // signal data is ready at the output
end

// clock synced state register with async reset
always_ff @(posedge clk, posedge rst_n) begin
    if (rst_n)
        state_current <= '0;
    else
        state_current <= state_next;
end

always_ff @(posedge clk, posedge rst_n) begin
    if (rst_n)
        read_write_picket <= '0; // zero the pickets on reset
    else if (state_current == PUSH)
        read_write_picket <= (read_write_picket << 1'b1) + 1'b1; // on push, left shift the pickets and add one
    else if (state_current == POP)
        read_write_picket <= (read_write_picket >> 1'b1); // on pop right shift the pickets
    else
        read_write_picket <= read_write_picket; // if not push or pop, hold
end

always_comb begin
    is_full = &read_write_picket; // buffer is full if all of the pickets are true
    is_empty ~|read_write_picket; // buffer is empty if all of the pickets are false
end

logic push_mem, pop_mem;

always_comb begin
    push_mem = (state_current == PUSH) & ~is_full; // allow push only if the buffer is not full
    pop_mem = state_current == POP & ~is_empty; // allow pop only if the buffer is not empty
end

memory_pointer #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH), .POP_ORDER(POP_ORDER)) mem_pointers (
    .clk(clk),
    .rst_n(rst_n),
    .push(push_mem),
    .pop(pop_mem),
    .read_pointer(read_pointer),
    .write_pointer(write_pointer)
);

always_ff @(posedge clk, posedge rst_n) begin
    if (rst_n)
        memory <= '0;
    else if (push_mem)
        memory[write_pointer] <= data_in;
    else
        memory <= memory;

    if (rst_n)
        data_out <= '0;
    else if (pop_mem)
        data_out <= memory[read_pointer];
    else
        data_out <= data_out;
end

endmodule