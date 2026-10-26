// ==========================================
// 1. THE ENCODER MODULE
// ==========================================
module morse_encoder(
    input wire clk,
    input wire reset,
    input wire [7:0] ascii_in,
    input wire valid_in,
    output reg morse_out,
    output reg ready
);

    reg [23:0] shift_reg;
    reg [4:0]  bit_count; 
    
    localparam IDLE = 1'b0;
    localparam SHIFT = 1'b1;
    reg state;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            morse_out <= 1'b0;
            ready <= 1'b1;
            shift_reg <= 24'b0;
            bit_count <= 5'd0;
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    morse_out <= 1'b0;
                    if (valid_in && ready) begin
                        ready <= 1'b0;
                        state <= SHIFT;
                        
                        // Complete A-Z Look-Up Table with correct 24-bit padding
                        case (ascii_in)
                            8'h41, 8'h61: begin shift_reg <= 24'b10111_0000000000000000000; bit_count <= 5; end  // A
                            8'h42, 8'h62: begin shift_reg <= 24'b111010101_000000000000000; bit_count <= 9; end  // B
                            8'h43, 8'h63: begin shift_reg <= 24'b11101011101_0000000000000; bit_count <= 11; end // C
                            8'h44, 8'h64: begin shift_reg <= 24'b1110101_00000000000000000; bit_count <= 7; end  // D
                            8'h45, 8'h65: begin shift_reg <= 24'b1_00000000000000000000000; bit_count <= 1; end  // E
                            8'h46, 8'h66: begin shift_reg <= 24'b101011101_000000000000000; bit_count <= 9; end  // F
                            8'h47, 8'h67: begin shift_reg <= 24'b111011101_000000000000000; bit_count <= 9; end  // G
                            8'h48, 8'h68: begin shift_reg <= 24'b1010101_00000000000000000; bit_count <= 7; end  // H
                            8'h49, 8'h69: begin shift_reg <= 24'b101_000000000000000000000; bit_count <= 3; end  // I
                            8'h4A, 8'h6A: begin shift_reg <= 24'b1011101110111_00000000000; bit_count <= 13; end // J
                            8'h4B, 8'h6B: begin shift_reg <= 24'b111010111_000000000000000; bit_count <= 9; end  // K
                            8'h4C, 8'h6C: begin shift_reg <= 24'b101110101_000000000000000; bit_count <= 9; end  // L
                            8'h4D, 8'h6D: begin shift_reg <= 24'b1110111_00000000000000000; bit_count <= 7; end  // M
                            8'h4E, 8'h6E: begin shift_reg <= 24'b11101_0000000000000000000; bit_count <= 5; end  // N
                            8'h4F, 8'h6F: begin shift_reg <= 24'b11101110111_0000000000000; bit_count <= 11; end // O
                            8'h50, 8'h70: begin shift_reg <= 24'b10111011101_0000000000000; bit_count <= 11; end // P
                            8'h51, 8'h71: begin shift_reg <= 24'b1110111010111_00000000000; bit_count <= 13; end // Q
                            8'h52, 8'h72: begin shift_reg <= 24'b1011101_00000000000000000; bit_count <= 7; end  // R
                            8'h53, 8'h73: begin shift_reg <= 24'b10101_0000000000000000000; bit_count <= 5; end  // S
                            8'h54, 8'h74: begin shift_reg <= 24'b111_000000000000000000000; bit_count <= 3; end  // T
                            8'h55, 8'h75: begin shift_reg <= 24'b1010111_00000000000000000; bit_count <= 7; end  // U
                            8'h56, 8'h76: begin shift_reg <= 24'b101010111_000000000000000; bit_count <= 9; end  // V
                            8'h57, 8'h77: begin shift_reg <= 24'b101110111_000000000000000; bit_count <= 9; end  // W
                            8'h58, 8'h78: begin shift_reg <= 24'b11101010111_0000000000000; bit_count <= 11; end // X
                            8'h59, 8'h79: begin shift_reg <= 24'b1110101110111_00000000000; bit_count <= 13; end // Y
                            8'h5A, 8'h7A: begin shift_reg <= 24'b11101110101_0000000000000; bit_count <= 11; end // Z
                            8'h27:        begin shift_reg <= 24'b1011101110111011101_00000; bit_count <= 19; end // '
                            8'h20:        begin shift_reg <= 24'b0; bit_count <= 7; end                          // Space
                            default:      begin shift_reg <= 24'b0; bit_count <= 0; state <= IDLE; ready <= 1'b1; end
                        endcase
                    end
                end
                
                SHIFT: begin
                    if (bit_count > 0) begin
                        morse_out <= shift_reg[23];
                        shift_reg <= {shift_reg[22:0], 1'b0};
                        bit_count <= bit_count - 1;
                    end else begin
                        morse_out <= 1'b0;
                        ready <= 1'b1;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule

// ==========================================
// 2. THE DECODER MODULE
// ==========================================
module morse_decoder(
    input wire clk,
    input wire reset,
    input wire morse_in,
    output reg [7:0] ascii_out,
    output reg valid_out
);

    reg sync1, morse_sync, prev_morse;
    reg [4:0] high_cnt;
    reg [4:0] low_cnt;
    reg [7:0] symbol_reg;
    reg [3:0] symbol_count;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            sync1 <= 0;
            morse_sync <= 0; prev_morse <= 0;
            high_cnt <= 0;
            low_cnt <= 0;
            symbol_reg <= 0;
            symbol_count <= 0;
            ascii_out <= 0;
            valid_out <= 0;
        end else begin
            // 2-Stage Synchronizer
            sync1 <= morse_in;
            morse_sync <= sync1;
            prev_morse <= morse_sync;

            valid_out <= 1'b0;

            // Edge Detection and Saturated Counters (Preventing Overflow)
            if (morse_sync == 1'b1) begin
                if (high_cnt < 5'd15) high_cnt <= high_cnt + 1;
                low_cnt <= 0;
            end else begin
                if (low_cnt < 5'd15) low_cnt <= low_cnt + 1;
                high_cnt <= 0;
            end

            // Falling Edge Detection (Measuring Dots vs Dashes)
            if (prev_morse == 1'b1 && morse_sync == 1'b0) begin
                if (high_cnt > 1) begin
                    symbol_reg <= {symbol_reg[6:0], 1'b1}; // Dash
                end else begin
                    symbol_reg <= {symbol_reg[6:0], 1'b0}; // Dot
                end
                symbol_count <= symbol_count + 1;
            end

            // End of Character Detection (3T Gap)
            if (morse_sync == 1'b0 && low_cnt == 3 && symbol_count > 0) begin
                valid_out <= 1'b1;
                
                // Complete A-Z Reverse Look-Up Table
                case ({symbol_count, symbol_reg[7:0]})
                    {4'd1, 8'b00000000}: ascii_out <= 8'h45; // E (.)
                    {4'd1, 8'b00000001}: ascii_out <= 8'h54; // T (-)
                    {4'd2, 8'b00000000}: ascii_out <= 8'h49; // I (..)
                    {4'd2, 8'b00000001}: ascii_out <= 8'h41; // A (.-)
                    {4'd2, 8'b00000010}: ascii_out <= 8'h4E; // N (-.)
                    {4'd2, 8'b00000011}: ascii_out <= 8'h4D; // M (--)
                    {4'd3, 8'b00000000}: ascii_out <= 8'h53; // S (...)
                    {4'd3, 8'b00000001}: ascii_out <= 8'h55; // U (..-)
                    {4'd3, 8'b00000010}: ascii_out <= 8'h52; // R (.-.)
                    {4'd3, 8'b00000011}: ascii_out <= 8'h57; // W (.--)
                    {4'd3, 8'b00000100}: ascii_out <= 8'h44; // D (-..)
                    {4'd3, 8'b00000101}: ascii_out <= 8'h4B; // K (-.-)
                    {4'd3, 8'b00000110}: ascii_out <= 8'h47; // G (--.)
                    {4'd3, 8'b00000111}: ascii_out <= 8'h4F; // O (---)
                    {4'd4, 8'b00000000}: ascii_out <= 8'h48; // H (....)
                    {4'd4, 8'b00000001}: ascii_out <= 8'h56; // V (...-)
                    {4'd4, 8'b00000010}: ascii_out <= 8'h46; // F (..-.)
                    {4'd4, 8'b00000100}: ascii_out <= 8'h4C; // L (.-..)
                    {4'd4, 8'b00000110}: ascii_out <= 8'h50; // P (.--.)
                    {4'd4, 8'b00000111}: ascii_out <= 8'h4A; // J (.---)
                    {4'd4, 8'b00001000}: ascii_out <= 8'h42; // B (-...)
                    {4'd4, 8'b00001001}: ascii_out <= 8'h58; // X (-..-)
                    {4'd4, 8'b00001010}: ascii_out <= 8'h43; // C (-.-.)
                    {4'd4, 8'b00001011}: ascii_out <= 8'h59; // Y (-.--)
                    {4'd4, 8'b00001100}: ascii_out <= 8'h5A; // Z (--..)
                    {4'd4, 8'b00001101}: ascii_out <= 8'h51; // Q (--.-)
                    {4'd6, 8'b00011110}: ascii_out <= 8'h27; // ' (.----.)
                    default: ascii_out <= 8'h3F; // ? (Unknown)
                endcase
                
                symbol_count <= 0;
                symbol_reg <= 0;
            end
            
            // End of Word Detection (7T Gap)
            if (morse_sync == 1'b0 && low_cnt == 7) begin
                valid_out <= 1'b1;
                ascii_out <= 8'h20; // Space
            end
        end
    end
endmodule
