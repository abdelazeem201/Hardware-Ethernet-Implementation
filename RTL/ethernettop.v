module EthernetTop(
	input Clock,
	input Reset,
	
	input  [15:0]		ENET_DATAr,
	input					ENET_INT,
	output [15:0] 		ENET_DATAw,
	output 	 			ENET_CMD,
	output 				ENET_CS_N,
	output 				ENET_WR_N,
	output 				ENET_RD_N,
	output 				ENET_RST_N,
	output				ENET_CLK = Clock,
	output 				Drive_ENET_DATA,
	
	/* Interrupt signal for packet received */
	output 		 ethernet_int_out,
	
	/* Interface ports for sending ethernet packet */
	input [15:0] ethernet_data_in,
	input        ethernet_send_req_in,
	output 		 ethernet_data_rdy_out,
	output		 ethernet_tx_complete_out,
	
	/* Interface ports for receiving ethernet packets */
	input 			ethernet_rcv_req_in,
	output [15:0]	ethernet_rcv_data_out,
	output			ethernet_rcv_data_rdy_out,
	output 			ethernet_rcv_complete_out,
	
	input Start_Init
);

assign ethernet_int_out = w_rx_int;

wire w_rx_req;
wire [15:0] w_rx_packet_data;
wire w_rx_packet_data_rdy;
wire w_rx_packet_complete;
wire w_rx_int;

wire w_tx_req;
wire [15:0] w_tx_packet_data;
wire w_tx_packet_data_rdy;
wire w_tx_complete;

wire w_reg_req;
wire w_reg_start_comm;
wire [7:0] w_reg_addr;
wire [15:0] w_reg_dataw;
wire [1:0] w_reg_comm_type;
wire [2:0] w_reg_post_command_delay;
wire w_reg_enet_rdy;
wire w_reg_grant;
wire [15:0] w_reg_datar;

/* Instantiate SendEthernetPacket */
SendEthernetPacket sep(
	.Clock(Clock),
	.Reset(Reset),
	
	/* Interface ports for user */
	.packet_data_in(ethernet_data_in),
	.packet_send_req_in(ethernet_send_req_in),
	.packet_data_rdy_out(ethernet_data_rdy_out),
	.packet_tx_complete_out(ethernet_tx_complete_out),
	
	/* Use reg interface to read MAC addr */
	.enet_rdy_in(w_reg_enet_rdy),
	.reg_grant_in(w_reg_grant),
	.reg_datar_in(w_reg_datar),
	.reg_req_out(w_reg_req), 
	.reg_start_comm_out(w_reg_start_comm),
	.reg_addr_out(w_reg_addr),
	.reg_dataw_out(w_reg_dataw),
	.reg_comm_type_out(w_reg_comm_type),
	.reg_post_command_delay(w_reg_post_command_delay),
		
	/* Use TX interface to actually transmit ethernet packet */
	.tx_packet_data_rdy_in(w_tx_packet_data_rdy),
	.tx_packet_data_out(w_tx_packet_data),
	.tx_req_out(w_tx_req),
	.tx_complete_in(w_tx_complete)
);

/* Instantiate ReceiveEthernetPacket */
ReceiveEthernetPacket rep(
	.Clock(Clock),
	.Reset(Reset),
	
	/* Interface ports for user */
	.ethernet_rcv_req_in(ethernet_rcv_req_in),
	.ethernet_rcv_data_out(ethernet_rcv_data_out),
	.ethernet_rcv_data_rdy_out(ethernet_rcv_data_rdy_out),
	.ethernet_rcv_complete_out(ethernet_rcv_complete_out),
	
	/* Use RX interface to actually receive packets */
	.rx_req_out(w_rx_req),
	.rx_packet_data_in(w_rx_packet_data),
	.rx_packet_data_rdy_in(w_rx_packet_data_rdy),
	.rx_packet_complete_in(w_rx_packet_complete)
);

/* Instantiate DM9000aController */
DM9000aController dm9ac(
  /* System inputs */
	.Clock(Clock),
	.Reset(Reset),
  
  /* Outputs to DM9000a */
  .ENET_DATAr(ENET_DATAr),
  .ENET_DATAw(ENET_DATAw),
  .ENET_CMD(ENET_CMD),
  .ENET_CS_N(ENET_CS_N),
  .ENET_WR_N(ENET_WR_N),
  .ENET_RD_N(ENET_RD_N),
  .ENET_RST_N(ENET_RST_N),
  .ENET_INT(ENET_INT),
  .ENET_CLK(ENET_CLK),
  .Drive_ENET_DATA(Drive_ENET_DATA),
  
  /* Rx ports */
  .rx_req_in(w_rx_req),
  .rx_packet_data_out(w_rx_packet_data),
  .rx_packet_data_rdy_out(w_rx_packet_data_rdy),
  .rx_int_out(w_rx_int),
  .rx_packet_complete_out(w_rx_packet_complete),
  
  /* Tx ports */
  .tx_req_in(w_tx_req),
  .tx_packet_data_in(w_tx_packet_data),
  .tx_packet_data_rdy_out(w_tx_packet_data_rdy),
  .tx_complete_out(w_tx_complete),
  
  /* DM9000a reg access ports */
  .reg_req_in(w_reg_req),
  .reg_start_comm_in(w_reg_start_comm),
  .reg_addr_in(w_reg_addr),
  .reg_datar_out(w_reg_datar),
  .reg_dataw_in(w_reg_dataw),
  .reg_comm_type_in(w_reg_comm_type),
  .reg_post_command_delay_in(w_reg_post_command_delay),
  .reg_grant_out(w_reg_grant),
  .reg_enet_rdy_out(w_reg_enet_rdy),

  .Start_Init(Start_Init)
);
endmodule
