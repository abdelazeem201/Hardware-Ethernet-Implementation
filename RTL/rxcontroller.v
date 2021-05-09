module RXController (
	input Clock,
	input Reset,
		
	input enet_rdy_in,					/* signal from ethernet controller */
		
	input rx_grant_in,					/* signal from arbitrator */
		
	input  rx_req_in,						/* req from user */
	output rx_req_out,					/* signal to arbitrator */
	output [7:0] rx_addr_out,			/* addr to ethernet controller */
	output [15:0] rx_dataw_out,		/* dataw to ethernet controller, not used yet */
	input  [15:0] rx_datar_in,			/* datar from ethernet controller */
	output [2:0] rx_post_command_delay_out,
	output rx_start_comm_out,			/* start_comm to ethernet controller */
	output [1:0] rx_comm_type_out,
		
	output [15:0] rx_packet_data_out,
	output rx_packet_data_rdy_out,	/* Toggles for one cycle indicating data is available to read */
	output rx_packet_complete_out
);

/******** Combinational Logic ********/
assign rx_req_out  				= (state > waiting);
assign rx_addr_out 				= (state == read_rx_ready) 		? 8'hF0 :
											(state == read_iomode_length) ? 8'hFE :
											(state >= read_rx_status)     ? 8'hF2 : 8'h00;
assign rx_dataw_out				= 16'b0;
assign rx_post_command_delay_out	= NO_DELAY;
assign rx_start_comm_out		= (state == read_rx_ready) || 
											(state >= read_iomode_length && state <= read_rx_length_2) ||
											(state == read_rx_data && (rx_index <= rx_length) && rx_req_in);
assign rx_comm_type_out			= (state < read_rx_data) ? COMMAND_READ : COMMAND_RX;

assign rx_packet_data_out 		= rx_datar_in;
assign rx_packet_data_rdy_out = (state == wait_rx_data) && enet_rdy_in;
assign rx_packet_complete_out	= (state == rx_complete);

parameter 	waiting=4'd0, wait_for_grant=4'd1, wait_for_enet_rdy = 4'd2,
				read_rx_ready = 4'd3, check_rx_ready=4'd4, read_iomode_length=4'd5, 
				read_rx_status=4'd6, read_rx_status_2=4'd7, read_rx_length=4'd8, 
				read_rx_length_2=4'd9, read_rx_length_finish=4'd10, read_rx_data=4'd11, 
				wait_rx_data=4'd12, rx_complete = 4'd13, error=4'd14;
				
parameter IO_MODE_8=1'b1, IO_MODE_16=1'b0;
parameter COMMAND_READ = 2'd0, COMMAND_WRITE = 2'd1, COMMAND_TX = 2'd2, COMMAND_RX = 2'd3;
parameter NO_DELAY = 3'd0, STD_DELAY = 3'd1, LONG_DELAY = 3'd2;

reg [3:0] state;
reg [3:0] state_after_wait;
reg io_mode;
reg [15:0] rx_status;
reg [15:0] rx_length;
reg [15:0] rx_index;

always@(posedge Clock) begin
	if (Reset) begin
		rx_status <= 16'd0;
		rx_length <= 16'd0;
		rx_index  <= 16'd0;
		state 	 <= waiting;
	end
	else begin
		case (state)
		waiting: begin
			rx_index  <= 16'd0;
			rx_status <= 16'd0;
			rx_length <= 16'd0;
			if (rx_req_in) begin
				state <= wait_for_grant;
			end
			else begin
				state <= waiting;
			end
		end
		
		/* Wait for arbitrator to grant access */
		wait_for_grant: begin
			if (rx_grant_in) begin
				state <= wait_for_enet_rdy;
				state_after_wait	<= read_rx_ready;
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
		
		/* Read RX ready bit from register F0 */
		read_rx_ready: begin
			state_after_wait <= check_rx_ready;
			state <= wait_for_enet_rdy;
		end
		
		/* Make sure RX Ready check LSB == 1, otherwise raise error flag */
		check_rx_ready: begin
			if (rx_datar_in[0]) begin
				state <= read_iomode_length;
			end
			else begin 
				state <= error;
			end
		end
		
		/* Read bit 7 from register FE to know if in 8bit or 16bit */
		read_iomode_length: begin
			state_after_wait <= read_rx_status;
			state <= wait_for_enet_rdy;
		end
		
		/* Read in rx status from reg F2 */
		read_rx_status: begin
			io_mode <= rx_datar_in[7];	
			
			state <= wait_for_enet_rdy;
			if (io_mode == IO_MODE_16) begin
				state_after_wait <= read_rx_length;
			end
			else begin
				state_after_wait <= read_rx_status_2;
			end
		end
		
		/* Read rx status 2nd byte (if in 8-bit mode) */
		read_rx_status_2: begin
			rx_status[7:0] <= rx_datar_in[7:0];
			
			state <= wait_for_enet_rdy;
			state_after_wait <= read_rx_length;
		end
		
		/* Read in rx length */
		read_rx_length: begin
			state <= wait_for_enet_rdy;
			if (io_mode == IO_MODE_16) begin
				rx_status <= rx_datar_in;
				state_after_wait <= read_rx_length_finish;
			end
			else begin
				rx_status[15:8] <= rx_datar_in[7:0];
				state_after_wait <= read_rx_length_2;
			end
		end
		
		/* Read rx length 2nd byte (if in 8-bit mode) */
		read_rx_length_2: begin
			rx_length[7:0] <= rx_datar_in[7:0];
			
			state <= wait_for_enet_rdy;
			state_after_wait <= read_rx_length_finish;
		end
		
		read_rx_length_finish: begin
			if (io_mode == IO_MODE_16) begin
				rx_length <= rx_datar_in;
			end
			else begin
				rx_length[15:8] <= rx_datar_in[7:0];
			end
			
			state <= read_rx_data;
		end
		
		/* Read rx data, keep reading as long as index < length and
		 * rx_req_in is 1
		 */
		read_rx_data: begin
			rx_index <= rx_index + 16'd1;
			
			/* Reached the end of the packet, end rx request */
			if (rx_index > rx_length || !rx_req_in) begin
				state <= rx_complete;
			end
			else begin
				state <= wait_rx_data;
			end
		end
		
		wait_rx_data: begin
			if (enet_rdy_in) begin
				state <= read_rx_data;
			end
			else begin
				state <= wait_rx_data;
			end
		end
		
		rx_complete: begin
			state <= waiting;
		end
		
		error: begin
			state <= waiting;
		end
		endcase
	end
end
endmodule
