`define WEIGHT_ROW_SIZE 50
`define INPUT_ADDR_BITS 8
`define INPUT_ROW_BITS 5
`define INPUT_DATA_BITS 16
`define INPUT_ROW_SIZE 200
`define INPUT_DATA_SIZE 100
`define OUTPUT_ROW_BITS 7 // 2^7=128>100

module Scheduler2 (
    input                           clk,
    input                           rst,
    input                           i_rdy_1,     // from s1
    input                           i_rdy_2,     // from s1
    input [`INPUT_DATA_BITS-1:0]    i_data_1,    // from PE1 (s1)
    input [`INPUT_DATA_BITS-1:0]    i_data_2,    // from PE2 (s1)
    input [`OUTPUT_ROW_BITS-1:0]    i_row_idx_1, // from s1
    input [`OUTPUT_ROW_BITS-1:0]    i_row_idx_2, // from s1
    input [`INPUT_DATA_BITS-1:0]    i_col_data_1,// from PE3
    input [`INPUT_DATA_BITS-1:0]    i_col_data_2,// from PE4
    input [2:0]                     i_col_idx_1, // from s1
    input [2:0]                     i_col_idx_2, // from s1
    // input                           i_s1_finish,
    output [`DATA_BITS-1:0]             o_pe1_psum,
    output [`DATA_BITS-1:0]             o_pe2_psum,
    output [`INPUT_DATA_BITS-1:0]   o_col_1,     // output
    output [`INPUT_DATA_BITS-1:0]   o_col_2,
    output [2:0]                    o_col_idx_1,
    output [2:0]                    o_col_idx_2,
    output [`INPUT_DATA_BITS-1:0]   o_data_1,     // to PE3
    output [`INPUT_DATA_BITS-1:0]   o_data_2,     // to PE4
    output                          o_adj_1,      // to PE3
    output                          o_adj_2,      // to PE4
    output                          o_result      // output
);
    wire [`INPUT_DATA_SIZE-1:0] adj [0:`INPUT_DATA_SIZE-1];  // 100*100 sparse adjacency matrix
    reg o_result_r, o_result_w;
    //reg pe_done_1, pe_done_2;
    reg busy, busy_w;
    reg o_rdy, o_rdy_w;
    
    reg [`INPUT_DATA_BITS-1:0] s1_data_buffer_1_r [`INPUT_DATA_SIZE-1:0];
    reg [`INPUT_DATA_BITS-1:0] s1_data_buffer_1_w [`INPUT_DATA_SIZE-1:0];
    reg [`INPUT_ROW_BITS-1:0]  s1_row_buffer_1_r  [`INPUT_DATA_SIZE-1:0];
    reg [`INPUT_ROW_BITS-1:0]  s1_row_buffer_1_w  [`INPUT_DATA_SIZE-1:0];
    reg [`INPUT_DATA_BITS-1:0] s1_data_buffer_2_r [`INPUT_DATA_SIZE-1:0];
    reg [`INPUT_DATA_BITS-1:0] s1_data_buffer_2_w [`INPUT_DATA_SIZE-1:0];
    reg [`INPUT_ROW_BITS-1:0]  s1_row_buffer_2_r  [`INPUT_DATA_SIZE-1:0];
    reg [`INPUT_ROW_BITS-1:0]  s1_row_buffer_2_w  [`INPUT_DATA_SIZE-1:0];

    reg [`INPUT_DATA_BITS-1:0] out_buffer_1_r [`INPUT_DATA_SIZE-1:0];
    reg [`INPUT_DATA_BITS-1:0] out_buffer_1_w [`INPUT_DATA_SIZE-1:0];
    reg [`INPUT_DATA_BITS-1:0] out_buffer_2_r [`INPUT_DATA_SIZE-1:0];
    reg [`INPUT_DATA_BITS-1:0] out_buffer_2_w [`INPUT_DATA_SIZE-1:0];
    reg [`INPUT_DATA_BITS-1:0] o_col_1_r;
    reg [`INPUT_DATA_BITS-1:0] o_col_1_w;
    reg [`INPUT_DATA_BITS-1:0] o_col_2_r;
    reg [`INPUT_DATA_BITS-1:0] o_col_2_w;
    reg [7:0]                  input_cnt, input_cnt_w;
    reg [7:0]                  buf_cnt_1, buf_cnt_1_w;
    reg [7:0]                  buf_cnt_2, buf_cnt_2_w;
    reg [7:0]                  row_cnt_1, row_cnt_1_w;
    reg [7:0]                  row_cnt_2, row_cnt_2_w;
    reg [7:0]                  row_idx_1, row_idx_2;
    reg [7:0]                  output_cnt, output_cnt_w;
    reg [2:0]                  col_idx_1, col_idx_1_w;
    reg [2:0]                  col_idx_2, col_idx_2_w;
    reg [2:0]                  o_col_idx_1_r, o_col_idx_1_w;
    reg [2:0]                  o_col_idx_2_r, o_col_idx_2_w;
    reg [`INPUT_DATA_BITS-1:0] o_data_1_r, o_data_1_w;
    reg [`INPUT_DATA_BITS-1:0] o_data_2_r, o_data_2_w;
    reg [`INPUT_DATA_BITS-1:0] o_adj_1_r, o_adj_1_w;
    reg [`INPUT_DATA_BITS-1:0] o_adj_2_r, o_adj_2_w;

    reg [`DATA_BITS-1:0]             o_pe1_psum;
    reg [`DATA_BITS-1:0]             o_pe2_psum;

    assign o_col_1 = o_col_1_r;
    assign o_col_2 = o_col_2_r;
    assign o_col_idx_1 = o_col_idx_1_r;
    assign o_col_idx_2 = o_col_idx_2_r;
    assign o_data_1 = o_data_1_r;
    assign o_data_2 = o_data_2_r;
    assign o_adj_1 = o_adj_1_r;
    assign o_adj_2 = o_adj_2_r;
    assign o_result = o_result_r;
    integer i, j;

    // Data from first layer are ready
    always @(*) begin
        busy_w = 0;
        col_idx_1_w = col_idx_1;
        col_idx_2_w = col_idx_2;
        for (i=0;i<`INPUT_DATA_SIZE;i=i+1)begin
            s1_data_buffer_1_w[i] = s1_data_buffer_1_r[i];
            s1_row_buffer_1_w[i]  = s1_row_buffer_1_r[i];
            s1_data_buffer_2_w[i] = s1_data_buffer_2_r[i];
            s1_row_buffer_2_w[i]  = s1_row_buffer_2_r[i];
        end
        input_cnt_w = input_cnt;
        if (i_rdy_1 && i_rdy_2) begin
            busy_w = 1;
            col_idx_1_w = i_col_idx_1;
            col_idx_2_w = i_col_idx_2;
            s1_data_buffer_1_w[input_cnt] = i_data_1;
            s1_row_buffer_1_w[input_cnt]  = i_row_idx_1;
            s1_data_buffer_2_w[input_cnt] = i_data_2;
            s1_row_buffer_2_w[input_cnt]  = i_row_idx_2;
            input_cnt_w = input_cnt + 1;
        end 
    end

    //test
    wire [15:0] ob1, ob2, ob3;
    assign ob1 = out_buffer_1_r[0];
    assign ob2 = out_buffer_1_r[1];
    assign ob3 = out_buffer_1_r[2];

    // Getting result element from first layer PEs
    always @(*) begin
        row_idx_1 = 0;     // actual row index
        row_idx_2 = 0;
        row_cnt_1_w = 0;
        row_cnt_2_w = 0;
        buf_cnt_1_w = 0;
        buf_cnt_2_w = 0;
        busy_w = busy;
        for (i=0;i<`INPUT_DATA_SIZE;i=i+1) begin
            out_buffer_1_w[i] = 0;
            out_buffer_2_w[i] = 0;
        end
        if (busy) begin
            row_idx_1 = s1_row_buffer_1_r[row_cnt_1];     // actual row index
            row_idx_2 = s1_row_buffer_2_r[row_cnt_2];
            o_data_1_w = s1_data_buffer_1_r[row_cnt_1];
            o_data_2_w = s1_data_buffer_2_r[row_cnt_2];
            o_adj_1_w = adj[buf_cnt_1][row_idx_1];
            o_adj_2_w = adj[buf_cnt_2][row_idx_2];
            o_pe1_psum = out_buffer_1_r[buf_cnt_1];
            o_pe2_psum = out_buffer_2_r[buf_cnt_2];
            out_buffer_1_w[buf_cnt_1] =  i_col_data_1;
            out_buffer_2_w[buf_cnt_2] =  i_col_data_2;

            if (buf_cnt_1 == 99 && buf_cnt_2 == 99) begin
                buf_cnt_1_w = 0;
                buf_cnt_2_w = 0;
                // One column of adj matrix is finished
                if (row_cnt_1 == input_cnt && row_cnt_2 == input_cnt) begin     // May have redundant cycles
                    // When row_index and buf_cnt counts to 100
                    // One column of output is finished
                    o_result_w = 1'b1;
                    row_cnt_1_w = 0;
                    row_cnt_2_w = 0;
                    o_rdy_w = 1;
                    busy_w = 0;
                end 
                else begin
                    row_cnt_1_w = row_cnt_1 + 1;
                    row_cnt_2_w = row_cnt_2 + 1;
                    o_result_w = 1'b0;
                    o_rdy_w = 0;
                end 
            end 
            else begin
                buf_cnt_1_w = buf_cnt_1 + 1;
                buf_cnt_2_w = buf_cnt_2 + 1;    
                o_result_w = 1'b0;
                o_rdy_w = 0;
                row_cnt_1_w = row_cnt_1;
                row_cnt_2_w = row_cnt_2;
            end
        end 
    end
    
    always @(*) begin
        if (o_rdy) begin
            input_cnt_w = 0;
            o_result_w = 0; // pull down ?
            o_rdy_w = 1;
            o_col_idx_1_w = col_idx_1;
            o_col_idx_2_w = col_idx_1 + 1;
            output_cnt_w = output_cnt + 1;
            if (output_cnt < 100) begin
                o_col_1_w = out_buffer_1_r[output_cnt];
            end 
            else if (output_cnt < 200) begin
                o_col_1_w = out_buffer_2_r[output_cnt];
            end 
            else begin
                // Output finished
                o_rdy_w = 0;
                output_cnt_w = 0;
                o_col_idx_1_w = 0;
                o_col_1_w = 0;
                o_col_idx_2_w = 0;
                o_col_2_w = 0;
            end
        end 
        else begin
            output_cnt_w = 0;
            o_col_idx_1_w = 0;
            o_col_idx_2_w = 0;
            o_col_1_w = 0;
            o_col_2_w = 0;
        end
    end

    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            o_result_r <= 0;
            input_cnt <= 0;
            buf_cnt_1 <= 0;
            buf_cnt_2 <= 0;
            row_cnt_1 <= 0;
            row_cnt_2 <= 0;
            output_cnt <= 0;
            col_idx_1 <= 0;
            col_idx_2 <= 0;
            o_col_idx_1_r <= 0;
            o_col_idx_2_r <= 0;
            o_data_1_r <= 0;
            o_data_2_r <= 0;
            o_adj_1_r <= 0;
            o_adj_2_r <= 0;
            o_col_1_r <= 0;
            o_col_2_r <= 0;
            busy <= 0;
            o_rdy <= 0;

            for (i = 0; i < `INPUT_DATA_SIZE; i=i+1) begin
                out_buffer_1_r[i] <= 0;
                out_buffer_2_r[i] <= 0;
                s1_data_buffer_1_r[i] <= 0;
                s1_row_buffer_1_r[i] <= 0;
                s1_data_buffer_2_r[i] <= 0;
                s1_row_buffer_2_r[i] <= 0;
            end


        end else begin
            o_result_r <= o_result_w;
            input_cnt <= input_cnt_w;
            buf_cnt_1 <= buf_cnt_1_w;
            buf_cnt_2 <= buf_cnt_2_w;
            row_cnt_1 <= row_cnt_1_w;
            row_cnt_2 <= row_cnt_2_w;
            output_cnt <= output_cnt_w;
            col_idx_1 <= col_idx_1_w;
            col_idx_2 <= col_idx_2_w;
            o_data_1_r <= o_data_1_w;
            o_data_2_r <= o_data_2_w;
            o_adj_1_r <= o_adj_1_w;
            o_adj_2_r <= o_adj_2_w;
            o_col_idx_1_r <= o_col_idx_1_w;
            o_col_idx_2_r <= o_col_idx_2_w;
            o_col_1_r <= o_col_1_w;
            o_col_2_r <= o_col_2_w;
            busy <= busy_w;
            o_rdy <= o_rdy_w;

            for (i = 0; i < `INPUT_DATA_SIZE; i=i+1) begin
                out_buffer_1_r[i] <= out_buffer_1_w[i];
                out_buffer_2_r[i] <= out_buffer_2_w[i];
                s1_data_buffer_1_r[i] <= s1_data_buffer_1_w[i];
                s1_row_buffer_1_r[i]  <= s1_row_buffer_1_w[i];
                s1_data_buffer_2_r[i] <= s1_data_buffer_2_w[i];
                s1_row_buffer_2_r[i]  <= s1_row_buffer_2_w[i];
            end
        end
    end


assign adj[ 0 ] = 100'b0000000000000010000000000000000000000000000000000000000000000000000000010000000100000000000000000000;
assign adj[ 1 ] = 100'b0000000000000000100000000000000000000000000000000000000000000000000000000000010000000000000001000000;
assign adj[ 2 ] = 100'b0000000000000000000000000000001000000000001000000010000000000000000000000000000001100000000000000000;
assign adj[ 3 ] = 100'b0000000000001000000000000000000000000000000000000000000000000000000010010000000000000000100100000000;
assign adj[ 4 ] = 100'b0000000000000100000000000000000000000010000010010000010000000001000000000000000000100000000000000000;
assign adj[ 5 ] = 100'b0000000010001000000000000000000000000000000000000100000000000010000100000000000000000000000000000000;
assign adj[ 6 ] = 100'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000010;
assign adj[ 7 ] = 100'b0000000000000000000000000000000000000000001000000000000000000000000100000000000010000000000000000000;
assign adj[ 8 ] = 100'b1000010000010000000000000000000000000000000000001000000010000000000000000000000000000001000000001000;
assign adj[ 9 ] = 100'b0000000000000000000000000000000100000001001000010000000010000000000000000000000000000000000000000000;
assign adj[ 10 ] = 100'b1100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
assign adj[ 11 ] = 100'b0000000000000000000000000000001000000010001000000000000000000000000000010000010000000000000000001000;
assign adj[ 12 ] = 100'b0000000000000000000000000000000000000000000010000000001000000000000000000000001010000000000100000000;
assign adj[ 13 ] = 100'b0000000011000000000000001000000000101000000000000000000000000010000000000000000000000000000000000000;
assign adj[ 14 ] = 100'b0000000000000000000000001000000000000000100000000000000000010000000000000000000000000000000001000000;
assign adj[ 15 ] = 100'b0000000000000000000000000000000000000000010000000000000000000000000000000000000100000000000000000000;
assign adj[ 16 ] = 100'b0000000000000000100000000000010000000000000000000000000000000100000010000000100000000000000000000000;
assign adj[ 17 ] = 100'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010100;
assign adj[ 18 ] = 100'b0000000001000000010000000000010000000001000000000000000000000000000000100010000000000000000000000100;
assign adj[ 19 ] = 100'b0001000001000000000000000000000001000100000000000001000000000100000000000000000000000001000010000000;
assign adj[ 20 ] = 100'b0001000000000000000000000000000000000000000000000000000000001000000000000000000000001000000000000001;
assign adj[ 21 ] = 100'b0000000000000000000001010000000000000000000000000000000001100000000000000000000000000001000000000000;
assign adj[ 22 ] = 100'b0000000000000000000000000000010000000000000000000010000000001000001000000000000000000000100000000010;
assign adj[ 23 ] = 100'b0000000000000000000000000000000000000000000000000000000110010000000000000000000000010000000000000000;
assign adj[ 24 ] = 100'b0010000000000000000000000100000000000000000000000000000000001000000000000000000000000000000000000000;
assign adj[ 25 ] = 100'b0000000000000000000001000000000000000100100000000000000001000000000000000000000001000000000000000000;
assign adj[ 26 ] = 100'b0000000010010000000000000000001000000000000000000000000000000000000000000000000000000000000000000000;
assign adj[ 27 ] = 100'b0010000010000000000000000000001100000000000000000000000010000000000000000000000000000000000000000000;
assign adj[ 28 ] = 100'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000001001;
assign adj[ 29 ] = 100'b0000000000000000001000000000000000000000000000000000000000100000000000000000000001000000000000000000;
assign adj[ 30 ] = 100'b0000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000;
assign adj[ 31 ] = 100'b0000000000000000001000000000000000000000000000000000000100100000000000000000000000010000000000001000;
assign adj[ 32 ] = 100'b0000000000000001000000000000001000000000000000000000000000000000000000000000000000000000000010100000;
assign adj[ 33 ] = 100'b0000000000001000100000000000000000000000000010000000001000000000000000000000010000000000000000000000;
assign adj[ 34 ] = 100'b0000000000000000000100000000000001000000000000010100000000000000000000000000000000000000000000000000;
assign adj[ 35 ] = 100'b0001001000000000001000000000000001000000000000000000000010000000000000000000000000000000000000000000;
assign adj[ 36 ] = 100'b0000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000010000;
assign adj[ 37 ] = 100'b1000000000000000000000011000000000000100100000000000000000000000000000000000000000000010000000100000;
assign adj[ 38 ] = 100'b0100000010000000000000000000000000000001000000000000000000000000000000000000000010010000000000000000;
assign adj[ 39 ] = 100'b0000000000000000000000000010000000000001000000010000001000000000000000000001010100000000000000000000;
assign adj[ 40 ] = 100'b0000000010100000000000000000000000000000000001000000000000000000000000000000100000000100000000000000;
assign adj[ 41 ] = 100'b0000000000000000000000000000000000001000000000000000000000000000000010100000001000000000000000000000;
assign adj[ 42 ] = 100'b0000000000000000000000000000100000000000000000000000000000000000000000000010001000000000000000000000;
assign adj[ 43 ] = 100'b0000001000001000000000000100001000000000000000000000110000000000100000001000100000000000001100000000;
assign adj[ 44 ] = 100'b1010000000000000000000001000000100000000000000000010000000000000000010000000100000000000000000000000;
assign adj[ 45 ] = 100'b0000000000000000000000001000000000000000000000000000000000001000001000000000000000000001000000000000;
assign adj[ 46 ] = 100'b0000000000000000000000001010000000000000001000000000000010000000000000000000000000000000000000010000;
assign adj[ 47 ] = 100'b0000000000000000000000000000010000000000000000000000000010000000000000000000000000000000000000000000;
assign adj[ 48 ] = 100'b0000000010000000000000000000000000000010000000000000000000000000000000000000000010000000000000000000;
assign adj[ 49 ] = 100'b0000010000001000000010000000000000000000000000011000000100000000000000000000010000000000000000000100;
assign adj[ 50 ] = 100'b0000000000000000000000000000000000001000000000000000000000000000010000000000000000000000000000100000;
assign adj[ 51 ] = 100'b0000000000000000000000000000100000100000100000000010000000000000000000000000000000000000000100000000;
assign adj[ 52 ] = 100'b0000000000000000000000000000001010000000000000000010000000001000010000000000000000000000001000010000;
assign adj[ 53 ] = 100'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
assign adj[ 54 ] = 100'b0000000000000000000000000000000000000000100000000000000000010000000000000000000000000000000000000000;
assign adj[ 55 ] = 100'b0000000000000010000000000010000000000010000000000000000000000000001000000000000000000001000000010000;
assign adj[ 56 ] = 100'b0000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000;
assign adj[ 57 ] = 100'b0000000000000000000100000000010000000000000000000000010000000000000000000000000000000000101010000100;
assign adj[ 58 ] = 100'b0000000000010000010000000000100001010000000000000000000000000000000000000000000000001000000000000000;
assign adj[ 59 ] = 100'b0000000000000000000000000000000000000000000001001000000000000010000000000010000000000100000000000000;
assign adj[ 60 ] = 100'b0000000000000000000000001000000000100000000000000000000000001100000000000000000001000000001000000000;
assign adj[ 61 ] = 100'b0000000000000000001000000011000000000000000010000001000000000000000000000000000000000000100000010000;
assign adj[ 62 ] = 100'b0000000000000000000000000000000000010000000000000000000000000010000000000010000010000000000000000000;
assign adj[ 63 ] = 100'b0000000000000000010000000010000000000000000000000100000000100000000000000000000000000010000000000000;
assign adj[ 64 ] = 100'b0000000000010000000000000000000000000100010000000000000000000000000000000000000000000000000000000000;
assign adj[ 65 ] = 100'b0000000000000000000000000000000000000001000000001000000000000000000000000000000000000010000000000000;
assign adj[ 66 ] = 100'b0000000000000000100000100000000100000000010000000000000000000000110000000000000010000000000000000000;
assign adj[ 67 ] = 100'b0000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000;
assign adj[ 68 ] = 100'b0001000001000000000000000001000001000000000000000000000100000000000000001000000000000000001000000000;
assign adj[ 69 ] = 100'b0000000000001000010000000000000000000000000000010000000010000000000100001100000000000000100000000100;
assign adj[ 70 ] = 100'b1000010000000001000000010000000000000000001000000000100000000001000000000000010001010000000000000000;
assign adj[ 71 ] = 100'b1001000000000000000000000000000000000000010100001000000001000000000000000000000000000000000000000000;
assign adj[ 72 ] = 100'b0000000000000000010000100000000100000010000000000000000000000000000000000000000000000000000000000000;
assign adj[ 73 ] = 100'b0000000000000000000000001000000000001010000010000000010000001000000000000000000000000000000000000000;
assign adj[ 74 ] = 100'b0001000000000000000000000000000000000000000000000000000010000000000000000001000000000000000000000000;
assign adj[ 75 ] = 100'b0000000010000000000000000010000000000001000000000000011100000010000000000000000000000110000000000000;
assign adj[ 76 ] = 100'b0010000000000000000000000000010000000000000000000000000000000010000000000000001000000000000000000000;
assign adj[ 77 ] = 100'b0000000000000000100000000001000001000000000000000000000000000000000000000000000000000000000000000000;
assign adj[ 78 ] = 100'b0001000100101000000000000000000000000000000000000000000000000000000000000010001000000000000000000000;
assign adj[ 79 ] = 100'b0000000000000000000000000000000000000000000000000010000000000000000001000000000000000000000000000000;
assign adj[ 80 ] = 100'b1000101000000000000000000000000000000000001000000000000000000000010000000000000000000000000000000000;
assign adj[ 81 ] = 100'b0010000000010000000000000000000000000010000000000000000000000000100010100000000000000000000000000000;
assign adj[ 82 ] = 100'b0000000000100000000000000001001000001000010000000000000000000000000000000000000001000000000000000000;
assign adj[ 83 ] = 100'b0000000000000000000000100000000001000000000000000000000000000000001000000000000000010000000000000010;
assign adj[ 84 ] = 100'b0000000000000000000000000000010000000000000000000000000000000000000100000000000000000000000000000000;
assign adj[ 85 ] = 100'b0001000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000001;
assign adj[ 86 ] = 100'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000;
assign adj[ 87 ] = 100'b0001000001000000000001000000001000000000000000000010000010000000001000000000000000000000000000101000;
assign adj[ 88 ] = 100'b0010000000000000001000000000000000010000010000000000000000000000000000000100000000000000000100000000;
assign adj[ 89 ] = 100'b0000000000000000010001000000000000000000000000000000000000010000000000000000000000000000000000000000;
assign adj[ 90 ] = 100'b0000000000001000000000000000000100000000000000000000000000000000000000000000000011000010000000000000;
assign adj[ 91 ] = 100'b0000000000000000000000001000000000000000000000000001000000010100000000001100000000000010000000100000;
assign adj[ 92 ] = 100'b0000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000;
assign adj[ 93 ] = 100'b0000000000000000000100000000000000000000000000000000000010000000100000000000000000000000000000000000;
assign adj[ 94 ] = 100'b0000000000000000000000000000010000000000000000000010000000000000000000000000000000000000000100000000;
assign adj[ 95 ] = 100'b0000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000;
assign adj[ 96 ] = 100'b1100000000001010000001000100100100000000000000000000000000000000100000000000000110000000000000000000;
assign adj[ 97 ] = 100'b0000000000010000001000010000000000000000000000000000000100000000000000001001000000000000000000000000;
assign adj[ 98 ] = 100'b0001000000000000000000000000000000000000000000000000000000000100000000000000000000000000010000000000;
assign adj[ 99 ] = 100'b0001000000000000000100000000110000000000000000000000000100000010000000000000000000000000010100000000;


endmodule