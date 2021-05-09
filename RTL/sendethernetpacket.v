module SendEthernetPacket (
	input Clock,
	input Reset,
	
	/* Interface ports for user */
	input [15:0] packet_data_in,
	input        packet_send_req_in,
	output 		 packet_data_rdy_out,
	output		 packet_tx_complete_out,
	
	/* Use reg interface to read MAC addr */
	input enet_rdy_in,
	input reg_grant_in,
	input [15:0] reg_datar_in,
	output reg_req_out, 
	output reg_start_comm_out,
	output [7:0] reg_addr_out,
	output [15:0] reg_dataw_out,
	output [1:0] reg_comm_type_out,
	output [2:0] reg_post_command_delay,
		
	/* Use TX interface to actually transmit ethernet packet */
	input tx_packet_data_rdy_in,
	output [15:0] tx_packet_data_out,
	output tx_req_out,
	input tx_complete_in
);

assign reg_req_out = (state == wait_for_reg_grant || state == wait_for_enet_rdy || 
								state == issue_mac_addr_read || state == read_mac_addr);
assign reg_start_comm_out 		= state == issue_mac_addr_read;
assign reg_addr_out 				= mac_reg;
assign reg_dataw_out 			= 16'b0;
assign reg_comm_type_out 		= COMMAND_READ;
assign reg_post_command_delay = NO_DELAY;

assign tx_packet_data_out 	= (state == write_dest_mac) ? 16'hFFFF :
									  (state == write_src_mac)  ? (mac_reg == 8'd0) ? src_mac[15:0] : (mac_reg == 8'd1 ? src_mac[31:16] : src_mac[47:32]) :
									  (state == write_protocol_type) ? ETH_TYPE :
									  packet_data_in;
assign tx_req_out 			= packet_send_req_in && (state > read_mac_addr);

assign packet_data_rdy_out = (tx_packet_data_rdy_in && (state == tx_packet));
assign packet_tx_complete_out = (state == tx_complete);

parameter DEST_MAC = 48'hFFFFFFFFFFFF, ETH_TYPE = 16'h0800;
parameter COMMAND_READ = 2'd0, COMMAND_WRITE = 2'd1, COMMAND_TX = 2'd2, COMMAND_RX = 2'd3;
parameter NO_DELAY = 3'd0, STD_DELAY = 3'd1, LONG_DELAY = 3'd2;

parameter waiting=4'd0, wait_for_reg_grant=4'd1, wait_for_enet_rdy=4'd2,
				issue_mac_addr_read=4'd3, read_mac_addr=4'd4, write_dest_mac=4'd5, 
				write_src_mac=4'd6, write_protocol_type=4'd7, tx_packet=4'd8, 
				wait_for_tx_complete=4'd9, tx_complete=4'd10;
reg [3:0]  state;
reg [3:0]  state_after_wait;

/* src mac read from dm9000a registers */
reg [47:0] src_mac;

/* which reg to read byte from, also used to copy mac addr to tx buffer */
reg [7:0]  mac_reg; 

always@(posedge Clock) begin
	if (Reset) begin
		state <= waiting;
	end
	else begin
		case (state)
		waiting: begin
			mac_reg <= 8'h10;
			if (packet_send_req_in) begin
				state <= wait_for_reg_grant;
			end
			else begin
				state <= waiting;
			end
		end
		
		wait_for_reg_grant: begin
			if (reg_grant_in) begin
				state <= wait_for_enet_rdy;
				state_after_wait <= read_mac_addr;
			end
			else begin
				state <= wait_for_reg_grant;
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
		
		/* Read in mac addr from reg's x10 to x15 */
		issue_mac_addr_read: begin
			state <= wait_for_enet_rdy;
			state_after_wait <= read_mac_addr;
		end
		
		/* copy in mac addr to local reg */
		read_mac_addr: begin
			if (mac_reg == 8'h10)
				src_mac[7:0] <= reg_datar_in[7:0];
			else if (mac_reg == 8'h11)
				src_mac[15:8] <= reg_datar_in[7:0];
			else if (mac_reg == 8'h12)
				src_mac[23:16] <= reg_datar_in[7:0];
			else if (mac_reg == 8'h13)
				src_mac[31:24] <= reg_datar_in[7:0];
			else if (mac_reg == 8'h14)
				src_mac[39:32] <= reg_datar_in[7:0];
			else
				src_mac[47:40] <= reg_datar_in[7:0];
			
			if (mac_reg == 8'h15) begin
				state <= write_dest_mac;
				mac_reg <= 8'd0;
			end
			else begin
				state <= issue_mac_addr_read;
				mac_reg <= mac_reg + 8'd1;
			end
		end
		
		/* Write destination mac to tx buffer */
		write_dest_mac: begin
			if (tx_packet_data_rdy_in) begin
				if (mac_reg == 8'd2) begin
					state <= write_src_mac;
					mac_reg <= 8'd2;
				end
				else begin
					mac_reg <= mac_reg + 8'd1;
					state <= write_dest_mac;
				end
			end
			else
				state <= write_dest_mac;
		end
		
		/* Stay here until src mac has been written */
		write_src_mac: begin
			if (tx_packet_data_rdy_in) begin
				if (mac_reg == 8'd0) begin
					state <= write_protocol_type;
				end
				else begin
					mac_reg <= mac_reg - 8'd1;
					state <= write_src_mac;
				end
			end
			else
				state <= write_src_mac;
		end
		
		/* write 2 byte ethernet protocol type */
		write_protocol_type: begin
			if (tx_packet_data_rdy_in) begin
				state <= tx_packet;
			end
			else begin
				state <= write_protocol_type;
			end
		end
		
		/* Stay here until user ends request */
		tx_packet: begin
			if (!packet_send_req_in) begin
				state <= wait_for_tx_complete;
			end
			else begin
				state <= tx_packet;
			end
		end
		
		wait_for_tx_complete: begin
			if (tx_complete_in) begin
				state <= tx_complete;
			end
			else begin
				state <= wait_for_tx_complete;
			end
		end
		
		tx_complete: begin
			state <= waiting;
		end
		endcase
	end
end
endmodule
