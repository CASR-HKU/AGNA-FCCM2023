(* keep_hierarchy = "yes" *)
module new_buf_tdp #(
    parameter BUF_EXEC_ADDR_WIDTH  = 9,
    parameter BUF_EXEC_DATA_WIDTH  = 16,
    parameter BUF_FETCH_ADDR_WIDTH = 9,
    parameter BUF_FETCH_DATA_WIDTH = 16
) (
    input  wire                            clk,
    input  wire                            buf_exec_wr_en,
    input  wire                            buf_exec_sel,
    input  wire [ BUF_EXEC_ADDR_WIDTH-1:0] buf_exec_addr,
    input  wire [ BUF_EXEC_DATA_WIDTH-1:0] buf_exec_wr_data,
    output wire [ BUF_EXEC_DATA_WIDTH-1:0] buf_exec_rd_data,
    input  wire                            buf_fetch_sel,
    input  wire [BUF_FETCH_ADDR_WIDTH-1:0] buf_fetch_addr,
    output wire [BUF_FETCH_DATA_WIDTH-1:0] buf_fetch_data
);

    // buf sel
    localparam FETCH_ADDR_WIDTH = BUF_FETCH_ADDR_WIDTH + 1;
    localparam EXEC_ADDR_WIDTH = BUF_EXEC_ADDR_WIDTH + 1;
    wire [EXEC_ADDR_WIDTH-1:0] exec_addr;
    assign exec_addr = {buf_exec_sel, buf_exec_addr};
    wire [FETCH_ADDR_WIDTH-1:0] fetch_addr;
    assign fetch_addr = {buf_fetch_sel, buf_fetch_addr};

    // Port A for Read&Write(execute)
    // Port B for Read(fetch)
    xpm_memory_tdpram #(
        .ADDR_WIDTH_A(EXEC_ADDR_WIDTH),  // DECIMAL
        .ADDR_WIDTH_B(FETCH_ADDR_WIDTH),  // DECIMAL
        .AUTO_SLEEP_TIME(0),  // DECIMAL
        .BYTE_WRITE_WIDTH_A(BUF_EXEC_DATA_WIDTH),  // DECIMAL
        .BYTE_WRITE_WIDTH_B(BUF_FETCH_DATA_WIDTH),  // DECIMAL
        .CASCADE_HEIGHT(0),  // DECIMAL
        .CLOCKING_MODE("common_clock"),  // String
        .ECC_MODE("no_ecc"),  // String
        .MEMORY_INIT_FILE("none"),  // String
        .MEMORY_INIT_PARAM("0"),  // String
        .MEMORY_OPTIMIZATION("true"),  // String
        .MEMORY_PRIMITIVE("auto"),  // String
        .MEMORY_SIZE(16384),  // DECIMAL
        .MESSAGE_CONTROL(0),  // DECIMAL
        .READ_DATA_WIDTH_A(BUF_EXEC_DATA_WIDTH),  // DECIMAL
        .READ_DATA_WIDTH_B(BUF_FETCH_DATA_WIDTH),  // DECIMAL
        .READ_LATENCY_A(1),  // DECIMAL
        .READ_LATENCY_B(1),  // DECIMAL
        .READ_RESET_VALUE_A("0"),  // String
        .READ_RESET_VALUE_B("0"),  // String
        .RST_MODE_A("SYNC"),  // String
        .RST_MODE_B("SYNC"),  // String
        .SIM_ASSERT_CHK(0),  // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_EMBEDDED_CONSTRAINT(0),  // DECIMAL
        .USE_MEM_INIT(1),  // DECIMAL
        .USE_MEM_INIT_MMI(0),  // DECIMAL
        .WAKEUP_TIME("disable_sleep"),  // String
        .WRITE_DATA_WIDTH_A(BUF_EXEC_DATA_WIDTH),  // DECIMAL
        .WRITE_DATA_WIDTH_B(BUF_FETCH_DATA_WIDTH),  // DECIMAL
        .WRITE_MODE_A("no_change"),  // String
        .WRITE_MODE_B("no_change"),  // String
        .WRITE_PROTECT(1)  // DECIMAL
    ) xpm_memory_tdpram_inst (
        .douta(buf_exec_rd_data),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
        .doutb(buf_fetch_data),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
        .addra(exec_addr),  // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
        .addrb(fetch_addr),                   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
        .clka(clk),  // 1-bit input: Clock signal for port A. Also clocks port B when
                     // parameter CLOCKING_MODE is "common_clock".
        .dina(buf_exec_wr_data),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
        .dinb(0),  // WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
        .ena(1'b1),  // 1-bit input: Memory enable signal for port A. Must be high on clock
        // cycles when read or write operations are initiated. Pipelined
        // internally.

        .enb   (1'b1),  // 1-bit input: Memory enable signal for port B. Must be high on clock
        // cycles when read or write operations are initiated. Pipelined
        // internally.
        .regcea(1'b1),  // 1-bit input: Clock Enable for the last register stage on the output
                        // data path.
        .regceb(1'b1),  // 1-bit input: Clock Enable for the last register stage on the output
                        // data path.

        .rsta(1'b0),  // 1-bit input: Reset signal for the final port A output register stage.
                      // Synchronously resets output port douta to the value specified by
                      // parameter READ_RESET_VALUE_A.

        .rstb(1'b0),  // 1-bit input: Reset signal for the final port B output register stage.
                      // Synchronously resets output port doutb to the value specified by
                      // parameter READ_RESET_VALUE_B.

        .wea(buf_exec_wr_en),                       // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
        // for port A input data port dina. 1 bit wide when word-wide writes are
        // used. In byte-wide write configurations, each bit controls the
        // writing one byte of dina to address addra. For example, to
        // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
        // is 32, wea would be 4'b0010.

        .web(1'b0)  // WRITE_DATA_WIDTH_B/BYTE_WRITE_WIDTH_B-bit input: Write enable vector
        // for port B input data port dinb. 1 bit wide when word-wide writes are
        // used. In byte-wide write configurations, each bit controls the
        // writing one byte of dinb to address addrb. For example, to
        // synchronously write only bits [15-8] of dinb when WRITE_DATA_WIDTH_B
        // is 32, web would be 4'b0010.

    );
endmodule
