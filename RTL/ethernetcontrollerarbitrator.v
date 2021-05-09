/* The arbitrator selects which module will get to access the ethernet chip */
module EthernetControllerArbitrator (
	input Clock,
	input Reset,
	  
	/* Grant signals to other modules */
	output rx_grant_out,
	output tx_grant_out,
	output reg_grant_out,
	output int_grant_out,
	  
	/* Output ports to ethernet controller */
	output enet_start_command_out,
	output [1:0] enet_command_type_out,
	output [7:0] enet_addr_out,
	output [15:0] enet_dataw_out,
	output [2:0] enet_post_command_delay_out,
	
	/* Rx ports */
	input rx_req_in,
	input [7:0] rx_addr_in,
	input [15:0] rx_dataw_in,
	input [2:0]  rx_post_command_delay_in,
	input rx_start_comm_in,
	input [1:0] rx_comm_type_in,
  
	/* Tx ports */  
	input tx_req_in,
	input [7:0] tx_addr_in,
	input [15:0] tx_dataw_in,
	input [2:0]  tx_post_command_delay_in,
	input tx_start_comm_in,
	input [1:0] tx_comm_type_in,

	/* DM9000a reg access ports */
	input reg_req_in,
	input reg_start_comm_in,
	input [7:0] reg_addr_in,
	input [15:0] reg_dataw_in,
	input reg_comm_type_in,
	input [2:0]  reg_post_command_delay_in,
	
	/* Interrupt detector */
	input int_req_in,
	input int_start_comm_in,
	input [7:0] int_addr_in,
	input [15:0] int_dataw_in,
	input int_comm_type_in,
	input [2:0] int_post_command_delay_in
);

parameter NO_DELAY = 3'd0, STD_DELAY = 3'd1, LONG_DELAY = 3'd2;

reg rx_granted;
reg tx_granted;
reg reg_granted;
reg int_granted;

wire already_granted = int_granted | rx_granted | tx_granted | reg_granted;

/******** Combinational Logic ********/
assign enet_start_command_out =
	reg_granted  ? reg_start_comm_in :
	rx_granted   ? rx_start_comm_in  :
	tx_granted   ? tx_start_comm_in	: 
	int_granted  ? int_start_comm_in	: 1'b0;
	
assign enet_command_type_out = 
	reg_granted  ? reg_comm_type_in 	:
	rx_granted   ? rx_comm_type_in  	:
	tx_granted   ? tx_comm_type_in	: 
	int_granted  ? int_comm_type_in	: 2'b0;

assign enet_addr_out  = 
	reg_granted  ? reg_addr_in 		:
	rx_granted   ? rx_addr_in  		:
	tx_granted   ? tx_addr_in			: 
	int_granted  ? int_addr_in 		: 1'b0;
	
assign enet_dataw_out    	  =
	reg_granted  ? reg_dataw_in 		:
	rx_granted   ? rx_dataw_in			:
	tx_granted   ? tx_dataw_in			: 
	int_granted  ? int_dataw_in		: 16'b0;

assign enet_post_command_delay_out =
	reg_granted	 ? reg_post_command_delay_in		:
	rx_granted	 ? rx_post_command_delay_in		:
	tx_granted	 ? tx_post_command_delay_in		: 
	int_granted  ? int_post_command_delay_in		: NO_DELAY;
  
assign rx_grant_out   = rx_granted   && rx_req_in;
assign tx_grant_out   = tx_granted   && tx_req_in;
assign reg_grant_out  = reg_granted  && reg_req_in;
assign int_grant_out  = int_granted  && int_req_in;

/* Order of priority (assuming requests come in at same cycle):
 * 1. Interrupt access
 * 2. Register access 
 * 3. Receive
 * 4. Transmit
 * Once a resource has been granted, it has access until its req_in goes low
 */
always@(posedge Clock) begin
	if (Reset) begin
		int_granted  <= 1'b0;
		reg_granted  <= 1'b0;
		rx_granted	 <= 1'b0;
		tx_granted	 <= 1'b0;
	end
	else begin
		int_granted  <= int_granted  ? int_req_in  : (int_req_in  && !already_granted);
		reg_granted  <= reg_granted  ? reg_req_in  : (reg_req_in  && !already_granted && !int_req_in);
		rx_granted	 <= rx_granted   ? rx_req_in   : (rx_req_in   && !already_granted && !int_req_in && !reg_req_in);
		tx_granted	 <= tx_granted   ? tx_req_in   : (tx_req_in   && !already_granted && !int_req_in && !reg_req_in && !rx_req_in);
	end
end
endmodule
