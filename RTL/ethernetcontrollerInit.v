module EthernetControllerInit (
	input Clock,
	input Reset,

	input init_grant_in,
	output [7:0] init_addr_out,
	output [15:0] init_dataw_out,
	output init_req_out,
	output [2:0] init_post_command_delay_out,
	output init_start_comm_out,
	output init_complete_out,

	input enet_controller_rdy_in,
	input start_init_in
);

/******** Combinational Logic ********/
assign init_addr_out 		= rom_data[7:0];
assign init_dataw_out 		= {8'b0, rom_data[15:8]};
assign init_post_command_delay_out = rom_data[17] ? STD_DELAY : LONG_DELAY;
assign init_req_out 			= (state > waiting);
assign init_start_comm_out = (state == issue_command);
assign init_complete_out   = (state == init_complete);

/* Machine which handles initialization of the DMA9000 module 
 * Loops through a piece of ROM and writes to registers in the dm90000a
 */
parameter MAX_ROM_INDEX = 5'd12;
parameter NO_DELAY = 3'd0, STD_DELAY = 3'd1, LONG_DELAY = 3'd2;
parameter waiting=3'd0, wait_for_grant=3'd1, wait_for_enet_rdy=3'd2, 
				issue_command=3'd3, s_wait=3'd4, increment_rom_index=3'd5,
				wait_increment=3'd6, init_complete=3'd7;
				
reg [4:0] rom_index;
wire [17:0] rom_data;
reg [2:0] state;

always@(posedge Clock) begin
	if (Reset) begin
		state <= waiting;
		rom_index <= 5'b0;
	end
	else begin
		case (state)
		waiting: begin
			if (start_init_in) begin
				state <= wait_for_grant;
			end
			else begin
				state <= waiting;
			end
			
			rom_index <= 5'b0;
		end
		
		/* Wait for arbitrator to grant access */
		wait_for_grant: begin
			if (init_grant_in) begin
				state <= wait_for_enet_rdy;
			end
			else begin
				state <= wait_for_grant;
			end
		end
		
		wait_for_enet_rdy:
		begin
			if (enet_controller_rdy_in)
				state <= issue_command;
			else
				state <= wait_for_enet_rdy;
		end
		
		issue_command:
		begin
			state <= s_wait;
		end

		s_wait:
		begin
			if (enet_controller_rdy_in) begin
				if (rom_index == MAX_ROM_INDEX) begin
					state <= init_complete;
				end
				else begin
					state <= increment_rom_index;
				end
			end
			else begin
				state <= s_wait;
			end
		end
		
		increment_rom_index:
		begin
			rom_index <= rom_index + 5'd1;
			state <= wait_increment;
		end
		
		/* need this delay so next rom entry will be output */
		wait_increment:
		begin
			state <= issue_command;
		end
		
		init_complete:
		begin
			if (start_init_in) begin
				state <= wait_for_grant;
			end
			else begin
				state <= init_complete;
			end
			
			rom_index <= 5'b0;
		end
		endcase
	end
end

/* rom_data Format:
 * [0:7]		Register Address
 * [8:15]  	Data (if it's a write, otherwise 0's)
 * [16]		Read (0) or Write (1)
 * [17]		Std delay (0) or long delay (1)
 */
enet_init_rom eir(
	.address(rom_index),
	.clock(Clock),
	.q(rom_data)
);

endmodule
