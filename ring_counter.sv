module ring_counter
#(parameter WIDTH)
(
    input clk, rst_n,
    input inc, dec,
    output [$clog2(WIDTH) : 0] count
);

logic [$clog2(WIDTH) : 0] count_next;

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
inc pc;
bit switch;

logic clk, rst_n;
logic inc, dec;
logic [$clog2(WIDTH) : 0] count;



initial begin
    clk <= '0;
    rst_n <= '1;
    swtich <= '0;
    #1;
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