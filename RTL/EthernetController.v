/* This module runs a state machine which communicates with the DM9000a's Registers */
module EthernetController (
	/* System inputs */
	input Clock,
	input Reset,
	  
	/* I/O to DM9000a */
	input  [15:0]		ENET_DATAr,
	input					ENET_INT,
	output [15:0] 		ENET_DATAw,
	output 	 			ENET_CMD,
	output 				ENET_CS_N,
	output 				ENET_WR_N,
	output 				ENET_RD_N,
	output 				ENET_RST_N,
	output				ENET_CLK,
	output 				Drive_ENET_DATA,
	  
	/* Outputs to other modules */
	output interrupt_out,
	output enet_rdy_out,
	  
	/* I/O from arbitrator */
	input enet_start_command_in,
	input [1:0] enet_command_type_in,
	input [7:0] enet_addr_in,
	input [15:0] enet_dataw_in,
	input [2:0] enet_post_command_delay_in,
	output reg [15:0] enet_datar_out,

	/* Debug I/O */
	output  [17:0] Debug_LEDR,
	output  [7:0]  Debug_LEDG
);
	 
// Macros
parameter ADDRESS = 1'd0, 	DATA = 1'd1;
parameter WRITE = 1'd0, 	NOT_WRITE = 1'd1;
parameter READ = 1'd0, 		NOT_READ = 1'd1;
parameter COMMAND_READ = 2'd0, COMMAND_WRITE = 2'd1, COMMAND_TX = 2'd2, COMMAND_RX = 2'd3;
parameter CS_ACTIVE = 1'b0, CS_INACTIVE = 1'b1;
parameter NO_DELAY = 3'd0, STD_DELAY = 3'd1, LONG_DELAY = 3'd2;

// States -- Order matters for combinational logic!!
parameter waiting=4'd0, issue_index=4'd1, 
addr_setup = 4'd2,addr_wr_en=4'd3, write_config_reg=4'd4, data_setup = 4'd5,
data_wr_en = 4'd6,read_pause = 4'd7,data_rd_en = 4'd8,read_config_reg = 4'd9,
post_command_pause1 = 4'd10,post_command_pause2 = 4'd11,delay_1=4'd12, delay_2=4'd13;

/******** Combinational Logic ********/
assign ENET_DATAw = enet_data_tmp;
assign ENET_CMD   = (enet_state > write_config_reg); /* If past write_config_reg, cmd should be 1 (DATA) */
assign ENET_WR_N  = ~((enet_state == addr_wr_en) || (enet_state == data_wr_en));	
assign ENET_RD_N  = ~(enet_state == data_rd_en);	
assign ENET_CS_N  = 1'b0; /* Always keep it active */
assign ENET_RST_N = 1'b1; /* RST is active-low on the dm9000a */
assign ENET_CLK   = Clock;
assign Drive_ENET_DATA = 	((enet_state > issue_index) && (enet_state < read_pause));
assign enet_rdy_out    = 	(enet_state == waiting) || 
									(enet_state == post_command_pause2 && 
										(enet_command_type_in == COMMAND_RX || enet_command_type_in == COMMAND_TX));

wire [15:0] w_delay_counter_1 = r_enet_post_command_delay == STD_DELAY || r_enet_post_command_delay == LONG_DELAY ? 16'd300 : 16'd0;
wire [15:0] w_delay_counter_2 = r_enet_post_command_delay == LONG_DELAY ? 16'd840 : 16'd0;

/* Latched command inputs */
reg [1:0] r_enet_command_type;
reg [7:0] r_enet_addr;
reg [15:0] r_enet_dataw;
reg [2:0] r_enet_post_command_delay;

reg [3:0] enet_state;
reg [15:0] delay_counter_1;
reg [15:0] delay_counter_2;

/* enet_data_tmp temporary register to put on ENET_DATA */
reg [15:0] enet_data_tmp;

always@(posedge Clock) begin
	if (Reset) begin
		enet_state <= waiting;
		delay_counter_1 <= 16'd0;
		delay_counter_2 <= 16'd0;
	end
	else begin
		case (enet_state)
			waiting:
			begin
				/* Latch all inputs if command initiated */
				if (enet_start_command_in) begin
					r_enet_command_type <= enet_command_type_in;
					r_enet_addr <= enet_addr_in;
					r_enet_dataw <= enet_dataw_in;
					r_enet_post_command_delay <= enet_post_command_delay_in;
					enet_state <= issue_index;
				end
				else 
					enet_state <= waiting;
			end
			
			// Prepare address to index port of dm9000a
			issue_index:
			begin
				enet_data_tmp 	<= {8'b0, r_enet_addr};
				delay_counter_1 <= w_delay_counter_1;
				delay_counter_2 <= w_delay_counter_2;
				
				enet_state 		<= addr_setup;
			end
			
			// Let address setup for a cycle
			addr_setup:
				enet_state  <= addr_wr_en;
			
			// Activate write enable for address to enter dm9000a index port
			addr_wr_en:
				enet_state	<= write_config_reg;
			
			// Prepare data for write
			// Still need this for a read so there's 2 cycle gap after index write
			write_config_reg:
			begin
				if (r_enet_command_type == COMMAND_READ || r_enet_command_type == COMMAND_RX) begin
					enet_state <= read_pause;
				end
				/* Write or TX */
				else begin
					enet_data_tmp <= r_enet_dataw;
					enet_state <= data_setup;
				end
			end
			
			// Let data setup for a cycle
			data_setup:
				enet_state <= data_wr_en;
			
			// Active write enable for data to enter dm9000a
			data_wr_en:
				enet_state <= post_command_pause1;
			
			// Wait one more cycle after the index write
			read_pause:
				enet_state <= data_rd_en;
			
			// Activate read enable for data from dm9000a
			data_rd_en: begin
				enet_state <= read_config_reg;
			end
			
			// Save data into local regs
			read_config_reg: begin
				enet_datar_out <= ENET_DATAr;
				
				enet_state <= post_command_pause1;
			end

			// need to wait 2 cycles after a read/write
			post_command_pause1:
				enet_state <= post_command_pause2;
			
			post_command_pause2:
			begin
				/* Loop back to reading register again if command RX */
				if (r_enet_command_type == COMMAND_RX && enet_command_type_in == COMMAND_RX) begin
					enet_state <= data_rd_en;
				end 
				else if (r_enet_command_type == COMMAND_TX && enet_command_type_in == COMMAND_TX) begin
					enet_state <= write_config_reg;
					r_enet_dataw <= enet_dataw_in;
				end
				else begin
					enet_state <= delay_1;
				end
			end
			
			delay_1:
			begin
				if (delay_counter_1 > 16'd0) begin
					delay_counter_1 <= delay_counter_1 - 16'd1;
					enet_state <= delay_1;
				end
				else begin
					enet_state <= delay_2;
				end
			end
			
			delay_2: begin
				if (delay_counter_2 > 16'd0) begin
					delay_counter_1 <= w_delay_counter_1;
					delay_counter_2 <= delay_counter_2 - 16'd1;
					enet_state <= delay_1;
				end
				else begin
					enet_state <= waiting;
				end
			end
			
			default: 
				enet_state <= waiting;
		endcase
	end
end


endmodule
