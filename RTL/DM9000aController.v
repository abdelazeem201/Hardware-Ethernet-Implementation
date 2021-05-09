/* This module contains and arbitrator and initializer module to get the DM9000a running.
 * The arbitrator passes the chosen resource to the EthernetController.
 */
module DM9000aController (
	input 				Clock,
	input 				Reset,
	
	output [17:0] 		Debug_LEDR,
	output [8:0]  		Debug_LEDG,

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

	/* Rx ports */
	input 				rx_req_in,
	output [15:0] 		rx_packet_data_out,
	output 				rx_packet_data_rdy_out,
	output 				rx_int_out,
	output 				rx_packet_complete_out,
	  
	/* Tx ports */
	input 				tx_req_in,
	input  [15:0] 		tx_packet_data_in,
	output 				tx_packet_data_rdy_out,
	output 				tx_complete_out,
	  
	/* DM9000a reg access ports */
	input 		 		reg_req_in,
	input 		 		reg_start_comm_in,
	input  [7:0]  		reg_addr_in,
	input  [15:0] 		reg_dataw_in,
	input  [1:0]  		reg_comm_type_in,
	input  [2:0]		reg_post_command_delay_in,
	output [15:0] 		reg_datar_out,
	output 				reg_grant_out,
	output 				reg_enet_rdy_out,
	  
	input Start_Init
);

parameter TRUE = 1'b1, FALSE = 1'b0;
parameter COMMAND_READ = 2'd0, COMMAND_WRITE = 2'd1, COMMAND_TX = 2'd2, COMMAND_RX = 2'd3;
parameter NO_DELAY = 3'd0, STD_DELAY = 3'd1, LONG_DELAY = 3'd2;

/* Don't allow rx or tx requests without init being complete */
wire w_int_req_validated 	= ENET_INT  && w_init_complete;
wire w_tx_req_validated 	= tx_req_in && w_init_complete;
wire w_rx_req_validated 	= rx_req_in && w_init_complete;

/* Wires to connect RXController to EthernetControllerArbitrator */
wire w_rx_grant;
wire w_rx_req;
wire w_rx_addr;
wire [15:0] w_rx_dataw;
wire [2:0]  w_rx_post_command_delay;
wire w_rx_start_comm;
wire [1:0] w_rx_comm_type;

/* Wires to connect TXController to EthernetControllerArbitrator */
wire w_tx_grant;
wire w_tx_req;
wire [7:0] w_tx_addr;
wire [15:0] w_tx_dataw;
wire [2:0]  w_tx_post_command_delay;
wire w_tx_start_comm;
wire [1:0] w_tx_comm_type;	
	
/* Wires to connect EthernetControllerArbitrator to EthernetController */
wire w_enet_rdy;
wire w_enet_start_command;
wire [1:0] w_enet_command_type;
wire [7:0] w_enet_addr;
wire [15:0] w_enet_dataw;
wire [2:0]  w_enet_post_command_delay;
wire [15:0] w_enet_datar;

/* Wires to multiplex reg port on arbitrator between init and outside user */
wire w_reg_req 							= w_init_complete ? reg_req_in 						: w_init_req;
wire w_reg_start_comm 					= w_init_complete ? reg_start_comm_in 				: w_init_start_comm;
wire [7:0]  w_reg_addr 					= w_init_complete ? reg_addr_in 						: w_init_addr;
wire [15:0] w_reg_dataw					= w_init_complete ? reg_dataw_in 					: w_init_dataw;
wire [1:0]  w_reg_comm_type   		= w_init_complete ? reg_comm_type_in 				: COMMAND_WRITE;
wire [2:0]  w_reg_post_command_delay= w_init_complete ? reg_post_command_delay_in 	: w_init_post_command_delay;

/* Wires to connect EthernetControllerInit to multiplexor */
wire [7:0] w_init_addr;
wire [15:0] w_init_dataw;
wire w_init_req;
wire [2:0] w_init_post_command_delay;
wire w_init_start_comm;
wire w_init_complete;

/* Wires to connect InterruptDetector to EthernetControllerArbitrator */
wire w_int_grant;
wire w_int_req;
wire [7:0] w_int_addr;
wire [15:0] w_int_dataw;
wire [2:0]  w_int_post_command_delay;
wire w_int_start_comm;
wire [1:0] w_int_comm_type;	

wire w_reg_grant;

assign reg_enet_rdy_out	= w_enet_rdy;
assign reg_grant_out   	= w_reg_grant;
assign reg_datar_out 	= w_enet_datar;

wire w_tx_int;

/******** Instantiate sub-modules ********/

/* Ethernet Controller */
EthernetController ec(
  .Clock(Clock),
  .Reset(Reset),  
  
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
  
  .interrupt_out(),
  .enet_rdy_out(w_enet_rdy),
  
  .enet_start_command_in(w_enet_start_command),
  .enet_command_type_in(w_enet_command_type),
  .enet_addr_in(w_enet_addr),
  .enet_dataw_in(w_enet_dataw),
  .enet_post_command_delay_in(w_enet_post_command_delay),
  .enet_datar_out(w_enet_datar)
);

/* Ethernet Controller Intializer */
EthernetControllerInit eci(
	.Clock(Clock),
	.Reset(Reset),
	
	.init_grant_in(w_reg_grant),
	
	.init_addr_out(w_init_addr),
	.init_dataw_out(w_init_dataw),
	.init_req_out(w_init_req),
	.init_post_command_delay_out(w_init_post_command_delay),
	.init_start_comm_out(w_init_start_comm),
	.init_complete_out(w_init_complete),
	
	.enet_controller_rdy_in(w_enet_rdy),
	.start_init_in(Start_Init)
);

/* Interrupt detector */
InterruptDectector id(
	.Clock(Clock),
	.Reset(Reset),
	
	/* Interrupt signals */
	.rx_int_out(rx_int_out),
	.tx_int_out(w_tx_int),
	
	.int_grant_in(w_int_grant),
	.enet_rdy_in(w_enet_rdy),
	
	.int_req_in(w_int_req_validated),
	.int_req_out(w_int_req),
	.int_addr_out(w_int_addr),
	.int_dataw_out(w_int_dataw),
	.int_datar_in(w_enet_datar),
	.int_post_command_delay_out(w_int_post_command_delay),
	.int_start_comm_out(w_int_start_comm),
	.int_comm_type_out(w_int_comm_type)
);

/* Receive packet controller */
RXController rxc(
	.Clock(Clock),
	.Reset(Reset),
	
	.enet_rdy_in(w_enet_rdy),
	
	.rx_grant_in(w_rx_grant),					
	
	.rx_req_in(w_rx_req_validated),						
	.rx_req_out(w_rx_req),						
	.rx_addr_out(w_rx_addr),				
	.rx_dataw_out(w_rx_dataw),			
	.rx_datar_in(w_enet_datar),				
	.rx_post_command_delay_out(w_rx_post_command_delay),				
	.rx_start_comm_out(w_rx_start_comm),
	.rx_comm_type_out(w_rx_comm_type),
	
	.rx_packet_data_out(rx_packet_data_out),
	.rx_packet_data_rdy_out(rx_packet_data_rdy_out),		/* Toggles for one cycle indicating data is available to read */
	.rx_packet_complete_out(rx_packet_complete_out)
);

/* Transmit packet controller */
TXController txc(
	.Clock(Clock),
	.Reset(Reset),

	.enet_rdy_in(w_enet_rdy),	
	.tx_int_in(w_tx_int),

	.tx_grant_in(w_tx_grant),			

	.tx_req_in(w_tx_req_validated),				
	.tx_req_out(w_tx_req),		
	.tx_addr_out( w_tx_addr),			
	.tx_dataw_out(w_tx_dataw),		
	.tx_datar_in(w_enet_datar),			
	.tx_post_command_delay_out(w_tx_post_command_delay),		
	.tx_start_comm_out(w_tx_start_comm),	
	.tx_comm_type_out(w_tx_comm_type),
	.tx_packet_data_in(tx_packet_data_in),
	.tx_packet_data_rdy_out(tx_packet_data_rdy_out),

	.tx_complete_out(tx_complete_out)
);

/* Ethernet controller arbitrator */
EthernetControllerArbitrator eca(
  .Clock(Clock),
  .Reset(Reset),
   
  .rx_grant_out(w_rx_grant),
  .tx_grant_out(w_tx_grant),
  .reg_grant_out(w_reg_grant),
  .int_grant_out(w_int_grant),
  
  /* Outputs to ethernet controller */
  .enet_start_command_out(w_enet_start_command),
  .enet_command_type_out(w_enet_command_type),
  .enet_addr_out(w_enet_addr),
  .enet_dataw_out(w_enet_dataw),
  .enet_post_command_delay_out(w_enet_post_command_delay),

  /* Receive controller */
  .rx_req_in(w_rx_req),
  .rx_addr_in(w_rx_addr),
  .rx_dataw_in(w_rx_dataw),
  .rx_post_command_delay_in(w_rx_post_command_delay),
  .rx_start_comm_in(w_rx_start_comm),
  .rx_comm_type_in(w_rx_comm_type),
  
  /* Transmit controller */
  .tx_req_in(w_tx_req),
  .tx_addr_in(w_tx_addr),
  .tx_dataw_in(w_tx_dataw),
  .tx_post_command_delay_in(w_tx_post_command_delay),
  .tx_start_comm_in(w_tx_start_comm),
  .tx_comm_type_in(w_tx_comm_type),

  /* Outside register accesses */
  .reg_req_in(w_reg_req),
  .reg_start_comm_in(w_reg_start_comm),
  .reg_addr_in(w_reg_addr),
  .reg_dataw_in(w_reg_dataw),
  .reg_comm_type_in(w_reg_comm_type),
  .reg_post_command_delay_in(w_reg_post_command_delay),
  
  	/* Interrupt detector */
	.int_req_in(w_int_req),
	.int_start_comm_in(w_int_start_comm),
	.int_addr_in(w_int_addr),
	.int_dataw_in(w_int_dataw),
	.int_comm_type_in(w_int_comm_type),
	.int_post_command_delay_in(w_int_post_command_delay)
);

endmodule
