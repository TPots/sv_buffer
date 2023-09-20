module ring_counter
#(parameter WIDTH)
(
    input logic clk, rst_n,
    input logic inc, dec,
    output logic [$clog2(WIDTH) - 1 : 0] count
);

logic [$clog2(WIDTH) - 1 : 0] count_next;

always_comb begin
    case({inc, dec})
    2'b10: begin
        if (count == WIDTH - 1'b1)
            count_next = '0;
        else
            count_next = count + 1'b1;
    end
    2'b01: begin
        if (count == '0)
            count_next = WIDTH - 1'b1;
        else
            count_next = count - 1'b1;
    end
    default: count_next = count;
    endcase
end

always_ff @(posedge clk, posedge rst_n) begin
    if (rst_n)
        count <= '0;
    else
        count <= count_next;
end

endmodule

module ring_counter_tb();

localparam WIDTH = 8;
int pc;
bit switch;

logic clk, rst_n;
logic inc, dec;
logic [$clog2(WIDTH) : 0] count;

ring_counter #(.WIDTH(WIDTH)) DUT (
    .clk(clk),
    .rst_n(rst_n),
    .inc(inc),
    .dec(dec),
    .count(count)
);

initial begin
    clk <= '0;
    rst_n <= '1;
    switch <= '0;
    #1;
    rst_n <= '0;
    forever begin
        clk <= ~clk;
        #1;
    end
end

always @(posedge clk) begin
    if (rst_n)
        pc <= '0;
    else
        pc <= pc + 1'b1;
end

always @(posedge clk) begin
    if (pc % 16 == 0)
        switch <= ~switch;
    else
        switch <= switch;
end

assign inc = switch;
assign dec = ~switch;

endmodule