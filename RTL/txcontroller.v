module TXController (
	input Clock,
	input Reset,
		
	input enet_rdy_in,								/* signal from ethernet controller */
	input tx_int_in,									/* interrupt signal */
		
	input 			tx_grant_in,					/* signal from arbitrator */
		
	input		 		tx_req_in,						/* req from user */
	output 			tx_req_out,						/* signal to arbitrator */
	output [7:0] 	tx_addr_out,					/* addt to ethernet controller */
	output [15:0]	tx_dataw_out,					/* dataw to ethernet controller, not used yet */
	input  [15:0]	tx_datar_in,					/* datar from ethernet controller */
	output [2:0]	tx_post_command_delay_out,	
	output 			tx_start_comm_out,			/* start_comm to ethernet controller */
	output [1:0]	tx_comm_type_out,
	input  [15:0]  tx_packet_data_in,
	output 			tx_packet_data_rdy_out,		/* Signals to load next packet data */
		
	output 			tx_complete_out
);

/******** Combinational Logic ********/
assign tx_req_out			= (state > waiting && state < wait_tx_success);
assign tx_addr_out		= (state == read_io_mode) 						? 8'hFE :
									(state >= write_tx_data && state <= write_tx_data_low_byte) ? 8'hF8 :
									(state == write_tx_length_high_byte) 	? 8'hFD :
									(state == write_tx_length_low_byte)  	? 8'hFC :
									(state == start_tx)						 	? 8'h02 : 8'h00;
assign tx_dataw_out		= (state == write_tx_length_high_byte) ? {8'b0, tx_length[15:8]} 				:
									(state == write_tx_length_low_byte) ? {8'b0, tx_length[7:0]}  				:
									(state == write_tx_data | ((state == wait_tx_data) & enet_rdy_in)) ? {tx_packet_data_in[7:0], tx_packet_data_in[15:8]} :
									(state == write_tx_data_high_byte)  ? {8'b0, tx_packet_data_in[15:8]} 	:
									(state == write_tx_data_low_byte)   ? {8'b0, tx_packet_data_in[7:0]}  	:
									(state == start_tx)						? {8'b0, 8'h01} 							: 16'b0;
assign tx_post_command_delay_out	= NO_DELAY;
assign tx_start_comm_out= (state == read_io_mode) || (state >= write_tx_data && state <= start_tx && state);
assign tx_comm_type_out = (state == read_io_mode) 			? COMMAND_READ	:
									((state >= write_tx_data && state <= write_tx_data_low_byte) || ((state == wait_tx_data) & tx_req_in)) ? COMMAND_TX	:
									(state >= write_tx_length_high_byte && state <= start_tx)   ? COMMAND_WRITE : 2'b0;
									
assign tx_packet_data_rdy_out = ((state == wait_tx_data) && enet_rdy_in) || state == read_io_mode_finish;

assign tx_complete_out 	= (state == tx_success);


/* state machine states */
parameter 	waiting=4'd0, wait_for_grant=4'd1, wait_for_enet_rdy=4'd2,
				wait_tx_data=4'd3, read_io_mode=4'd4, read_io_mode_finish=4'd5,
				write_tx_data=4'd6, write_tx_data_high_byte=4'd7, write_tx_data_low_byte=4'd8,
				write_tx_length_high_byte=4'd9, write_tx_length_low_byte=4'd10, start_tx=4'd11,
				wait_tx_success=4'd12, tx_success=4'd13;
				
/* Macros */
parameter IO_MODE_8=1'b1, IO_MODE_16=1'b0;
parameter COMMAND_READ = 2'd0, COMMAND_WRITE = 2'd1, COMMAND_TX = 2'd2, COMMAND_RX = 2'd3;
parameter NO_DELAY = 3'd0, STD_DELAY = 3'd1, LONG_DELAY = 3'd2;

reg [3:0] state;
reg [3:0] state_after_wait;
reg [15:0] tx_length;
reg io_mode;

always@(posedge Clock) begin
	if (Reset) begin
		state <= 4'd0;
		state_after_wait <= 4'd0;
		tx_length <= 16'd0;
	end
	else begin		
		case (state)
		waiting: begin
			tx_length <= 16'd0;
			if (tx_req_in) begin
				state <= wait_for_grant;
			end
			else begin
				state <= waiting;
			end
		end
		
		wait_for_grant: begin
			if (tx_grant_in) begin
				state <= wait_for_enet_rdy;
				state_after_wait <= read_io_mode;
			end 
			else begin
				state <= wait_for_grant;
			end
		end
		
		/* Use this generic state to wait for EthernetController to finish command */
		wait_for_enet_rdy: begin
			if (enet_rdy_in) begin
				state <= state_after_wait;
			end
			else begin
				state <= wait_for_enet_rdy;
			end
		end
		
		wait_tx_data: begin			
			if (enet_rdy_in) begin
				/* increment length by 2 bytes */
				tx_length <= tx_length + 16'd2;
				
				/* is user still requesting to tx more data? */
				if (tx_req_in) begin
					state <= io_mode == IO_MODE_16 ? write_tx_data : write_tx_data_high_byte;
				end
				else begin
					state <= write_tx_length_high_byte;
				end
			end
			else begin
				state <= wait_tx_data;
			end
		end
		
		read_io_mode: begin
			state <= wait_for_enet_rdy;
			state_after_wait <= read_io_mode_finish;
		end
		
		read_io_mode_finish: begin
			io_mode <= tx_datar_in[7];
			
			if (tx_datar_in[7] == IO_MODE_16) begin
				state <= write_tx_data;
			end
			else begin
				state <= write_tx_data_high_byte;
			end
		end
		
		/* Write data to reg F8 */
		write_tx_data: begin
			state <= wait_tx_data;
		end
		
		write_tx_data_high_byte: begin
			state <= wait_for_enet_rdy;
			state_after_wait <= write_tx_data_low_byte;
		end
		
		write_tx_data_low_byte: begin
			state <= wait_tx_data;
		end
		
		write_tx_length_high_byte: begin
			state <= wait_for_enet_rdy;
			state_after_wait <= write_tx_length_low_byte;
		end
		
		write_tx_length_low_byte: begin
			state <= wait_for_enet_rdy;
			state_after_wait <= start_tx;
		end
		
		/* write 0x01 to reg 0x02 to signal start of transmission */
		start_tx: begin
			state <= wait_for_enet_rdy;
			state_after_wait <= wait_tx_success;
		end
		
		/* Wait for TX Interrupt */
		wait_tx_success: begin
			if (tx_int_in) 
				state <= tx_success;
			else
				state <= wait_tx_success;
		end
		
		tx_success: begin
			state <= waiting;
		end
		endcase
	end
end
endmodule
