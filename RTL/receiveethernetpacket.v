module ReceiveEthernetPacket(
	input Clock,
	input Reset,
	
	/* Interface ports for user */
	input 			ethernet_rcv_req_in,
	output [15:0]	ethernet_rcv_data_out,
	output			ethernet_rcv_data_rdy_out,
	output			ethernet_rcv_complete_out,
	
	/* Use RX interface to actually receive packets */
	output rx_req_out,
	input [15:0] rx_packet_data_in,
	input rx_packet_data_rdy_in,
	input rx_packet_complete_in
);

assign ethernet_rcv_data_out = (state == wait_for_data) ? rx_packet_data_in : 16'd0;
assign ethernet_rcv_data_rdy_out = (state == wait_for_data && rx_packet_data_rdy_in);
assign ethernet_rcv_complete_out = (state == rx_complete);

assign rx_req_out = (state > waiting);

parameter waiting=4'd0, wait_for_header_data=4'd1, wait_for_data=4'd2, rx_complete=4'd3;
parameter HEADER_BYTES_TO_DUMP = 5'd17;

reg [3:0] state;
reg [3:0] state_after_wait;
reg [4:0] header_counter;

always@(posedge Clock) begin
	if (Reset) begin
		state <= 4'd0;
	end
	else begin
		case (state)
		waiting: begin
			header_counter <= 5'd0;
			if (ethernet_rcv_req_in) begin
				state <= wait_for_header_data;
			end
			else begin
				state <= waiting;
			end
		end
		
		wait_for_header_data: begin
			if (rx_packet_data_rdy_in) begin
				header_counter <= header_counter + 4'd1;
				
				if (header_counter == HEADER_BYTES_TO_DUMP)
					state <= wait_for_data;
				else
					state <= wait_for_header_data;
			end
			else begin
				state <= wait_for_header_data;
			end
		end
		
		wait_for_data: begin
			if (rx_packet_complete_in)
				state <= rx_complete;
			else
				state <= wait_for_data;
		end
		
		rx_complete: begin
			state <= waiting;
		end
		endcase
	end
end

endmodule
