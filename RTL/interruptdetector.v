
module InterruptDectector(
	input Clock,
	input Reset,
	
	/* Interrupt signals 
	 * These signals will stay high for 1 cycle 
	 */
	output rx_int_out,			
	output tx_int_out,			
	
	input int_grant_in,
	input enet_rdy_in,
	
	input 			int_req_in,
	output 			int_req_out,
	output [7:0] 	int_addr_out,
	output [15:0] 	int_dataw_out,
	input  [15:0] 	int_datar_in,
	output [2:0]  	int_post_command_delay_out,
	output 			int_start_comm_out,
	output [1:0]  	int_comm_type_out
);

parameter COMMAND_READ = 2'd0, COMMAND_WRITE = 2'd1, COMMAND_TX = 2'd2, COMMAND_RX = 2'd3;
parameter NO_DELAY = 3'd0, STD_DELAY = 3'd1, LONG_DELAY = 3'd2;
parameter CLEAR_ISR = 8'h7F, ISR_REG = 8'hFE;

assign rx_int_out = (state == clear_complete) & r_isr[0];
assign tx_int_out = (state == clear_complete) & r_isr[1];

assign int_req_out = (state > waiting);
assign int_addr_out = ISR_REG;
assign int_dataw_out = CLEAR_ISR;
assign int_post_command_delay_out = NO_DELAY;
assign int_start_comm_out = (state == issue_read) || (state == clear_isr);
assign int_comm_type_out = (state == clear_isr) ? COMMAND_WRITE : COMMAND_READ;

parameter waiting=3'd0, wait_for_grant=3'd1, wait_for_enet_rdy=3'd2, issue_read=3'd3, clear_isr=3'd4,
			 clear_complete=3'd5;
reg [2:0] state;
reg [2:0] state_after_wait;
reg [7:0] r_isr;

always@(posedge Clock) begin
	if (Reset) begin
		state <= 3'd0;
	end
	else begin
		case (state)
		waiting: begin
			if (int_req_in) begin
				state <= wait_for_grant;
			end
			else begin
				state <= waiting;
			end
		end
		
		wait_for_grant: begin
			if (int_grant_in) begin
				state <= wait_for_enet_rdy;
				state_after_wait <= issue_read;
			end
			else begin
				state <= wait_for_grant;
			end
		end
				
		wait_for_enet_rdy: begin
			if (enet_rdy_in) begin
				state <= state_after_wait;
			end
			else begin
				state <= wait_for_enet_rdy;
			end
		end
	
		/* issue read on ISR reg FE */
		issue_read: begin
			state <= wait_for_enet_rdy;
			state_after_wait <= clear_isr;
		end
		
		/* read ISR from datar_in, clear ISR */
		clear_isr: begin
			r_isr <= int_datar_in[7:0];
			state <= wait_for_enet_rdy;
			state_after_wait <= clear_complete;
		end
		
		/* raise interrupt flag for a cycle */
		clear_complete: begin
			state <= waiting;
		end
		endcase
	end
end

endmodule
