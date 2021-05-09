module ReadReg (
	input Clock,
	input Reset,
	
	input 			start_read_in,
	input [7:0] 	reg_addr_in,
	output [15:0] 	reg_data_out,
	output			reg_data_rdy_out,
	
	output 			reg_req_out,
	output [7:0] 	reg_addr_out,
	output 			reg_start_comm_out,
	input  [15:0]	reg_datar_in,
	output [1:0]	reg_comm_type_out,
	output [2:0]	reg_post_command_delay_out,
	input				reg_grant_in,
	input				reg_enet_rdy_in
);

parameter COMMAND_READ = 2'd0, COMMAND_WRITE = 2'd1, COMMAND_TX = 2'd2, COMMAND_RX = 2'd3;
parameter NO_DELAY = 3'd0, STD_DELAY = 3'd1, LONG_DELAY = 3'd2;

assign reg_req_out 			=  (state > waiting);
assign reg_addr_out 			= 	(state == issue_read) ? reg_addr_in : 8'b0;
assign reg_start_comm_out 	=  (state == issue_read);
assign reg_comm_type_out 	=  COMMAND_READ;
assign reg_post_command_delay_out = NO_DELAY;

assign reg_data_rdy_out = 	(state == data_rdy);
assign reg_data_out 		= 	reg_datar_in;

parameter waiting=3'd0, wait_for_grant=3'd1, wait_for_enet_rdy=3'd2, issue_read=3'd3, data_rdy=3'd4;
reg [2:0] state;
reg [2:0] state_after_wait;

always@(posedge Clock) begin
	if (Reset) begin
		state <= 3'd0;
	end
	else begin
		case (state)
			waiting: begin
				if (start_read_in) begin
					state <= wait_for_grant;
				end
				else begin
					state <= waiting;
				end
			end
			
			wait_for_grant: begin
				if (reg_grant_in) begin
					state <= wait_for_enet_rdy;
					state_after_wait <= issue_read;
				end
				else begin
					state <= wait_for_grant;
				end
			end
					
			wait_for_enet_rdy: begin
				if (reg_enet_rdy_in) begin
					state <= state_after_wait;
				end
				else begin
					state <= wait_for_enet_rdy;
				end
			end	
		
			issue_read: begin
				state <= wait_for_enet_rdy;
				state_after_wait <= data_rdy;
			end
			
			data_rdy: begin
				state <= waiting;
			end
		endcase
	end
end

endmodule
