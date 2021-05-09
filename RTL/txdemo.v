module TXDemo (
	input Clock,
	input Reset,
	
	input start_tx,
	
	input tx_packet_data_rdy_in,
	output [15:0] tx_packet_data_out,
	output tx_req_out,
	input tx_complete_in,
	
	output reg [8:0] Debug_LEDG
);

assign tx_packet_data_out 	= rom_data[15:0];
assign tx_req_out				= state == wait_for_tx_rdy;

parameter waiting=4'd0, wait_for_tx_rdy=4'd1, wait_for_complete=4'd2;

reg [3:0] state;
reg [4:0] rom_index;
wire [17:0] rom_data;
reg [7:0] ncr_reg;
wire [4:0] w_rom_index = (state == wait_for_tx_rdy) & tx_packet_data_rdy_in ? rom_index + 5'd1 : rom_index;

always@(posedge Clock) begin
	if (Reset) begin
		rom_index <= 5'd0;
		state <= waiting;
		Debug_LEDG <= 9'b0;
	end
	else begin
		case (state)
		waiting: begin
			// let it overflow to zero for the first tx
			rom_index <= 5'h1F;
			if (start_tx) begin
				state <= wait_for_tx_rdy;
			end
			else begin
				state <= waiting;
			end
		end
		
		wait_for_tx_rdy: begin
			if (tx_packet_data_rdy_in) begin
				rom_index <= w_rom_index;
			end
			if (rom_index == 5'd12) begin
				state <= wait_for_complete;
			end
			else begin
				state <= wait_for_tx_rdy;
			end
		end
		
		wait_for_complete: begin
			if (tx_complete_in) begin
				Debug_LEDG <= 9'h1FF;
				state <= waiting;
			end
			else begin
				state <= wait_for_complete;
			end
		end
		endcase
	end
end
 
enet_init_rom eir(
	.address(w_rom_index),
	.clock(Clock),
	.q(rom_data)
);
endmodule
