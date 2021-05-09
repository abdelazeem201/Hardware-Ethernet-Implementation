# Introduction
We developed an implementation of Ethernet packet tx/rx fully on hardware. Currently, there are several projects that make use of the DE2 Ethernet port. However, none of these projects focused on creating a modular platform to allow for easy integrate with higher layer protocols. Other projects make use of the NIOS II for Ethernet initialization and lower level control. A major deficiency is the lack of a full hardware implementation that can allow for the easy implementation of higher layer protocols.

We hope that our project will be beneficial for future groups looking to make use of Ethernet without the requirement of adding a NIOS to their hardware.

# High Level Design

*1. Rationale and Inspiration:*

If the trend continues, connectivity will have an increasingly important role in product design. After looking at prior years projects it became apparent that there was not a good hardware implementation of Ethernet that also allowed for the addition of higher level protocols. Other projects that did use Ethernet were implemented with the NIOS II which takes up size and adds to system complexity. We desired to pursue this project as it explored new hardware not addressed during any other labs and we believe that a good implementation could provide to be very useful for student projects in the future.

*2. Logical Structure:*

At a high level our design consists of a single FPGA in conjunction with the Davidcom Ethernet chip. Our project will initialize the Ethernet chip and then provides routines for sending and receiving packets from the link. The code was designed to be modular to simplify the addition of higher layer protocols. See the diagram in the hardware section for a visual depiction of the project module interconnections.

We created a general module that contained all the hardware needed to send and receive basic packets. Adding the Ethernet Top module expands our implementation to send Ethernet frames. These modules will essentially perform all tasks as defined by the layer and then append the appropriate data to the packet/frame.

*3. Hardware Software Trade-offs:

For our project we decided to use a fully hardware approach. Our goal of the project was to construct a hardware module capable of Ethernet frame transmission. Overall a hardware only approach will increase the processing speed of the Ethernet unit. However, the most significant improvement is the ability to have a link layer protocol enabled in hardware without necessarily introducing a NIOS to the system. This will save in both gates and system complexity. Additionally the modular approach allows for the addition of higher layer protocols if need be.


*4. Standards:*

As we aimed to make our project as universal as possible we adhere to the RFC standards. As we implemented Ethernet frames we adhered to the standard as depicted below.

![Fig. Ethernet Frame format, type II](https://upload.wikimedia.org/wikipedia/commons/thumb/1/13/Ethernet_Type_II_Frame_format.svg/1024px-Ethernet_Type_II_Frame_format.svg.png?1620531863936)

# Hardware Design

*1. Overview*

The system is designed comprising of several smaller modules. A block diagram of the physical connections between the modules is shown below. All communication between external hardware and the Davidcom Ethernet chip is initiated by the Ethernet Top interface. We provide an example program for interfacing with the chip as well as outline the communication process below. Our internal modules will control data flow and port access of the Davidcom chip via grants from an arbiter. Once access is granted to an originating module the data passes to the Ethernet controller module which contains the state machine for communicating with the Ethernet chip.

![Fig. Block diagram of the hardware modules](![blockdiag](https://user-images.githubusercontent.com/58098260/117560235-2950c000-b08c-11eb-9fd0-1284f52a51b9.png)


*Ethernet Top and Interface Description*

EthernetTop.v

Ethernet Top is a module that instantiates and connects the blocks necessary to implement the link layer protocol. This includes instantiating the Receive Ethernet and Send Ethernet modules. This includes the interface that is to be accessed by the users wishing to use our module. As this module also encompass the DM9000a controller there are also all the ports that interface with the Ethernet chip. These will be discussed later.

The interface ports provide the user with an easy way to 'black box' interface with the on board Ethernet controller. Our interface uses a handshaking technique for packet reception and transmission. For both the receive and send interfaces there are 4 ports used. An input for a send/transmit request, a 16 bit input/output for send/transmit data, an output to signal when data is ready to be sent/ received and an output to signal the completion of a tx or rx. Additionally, an interrupt signal is output for received packets.

On a high level, to interface with the controller an external module will begin a Ethernet tx/rx by driving the appropriate request line high. The interfacing module will wait until the data ready line is driven high. The user shall not clear the request line until all data is sent/read. Our module will then transmit notify the interfacing module when the transmit or read is complete. An example interface is provided in TXDemo.v

*Send Ethernet Packet*

SendEthernetPacket.v

This module provides the functionality to send Ethernet frames using MAC addressing. The input and output ports for interfacing are as described in the top level Ethernet Top Module. The purpose of this module is to construct the Ethernet frame as depicted in the Standards section. In the general state the state machine begins in a waiting state. Once an external module requests to sent a packet the module will begin to wait for a grant from the internal arbiter. Once the grant is given the machine will begin to read the source MAC address from the chip's registers. This data is then stored into internal registers to be used when constructing the frame. The MAC addresses are the first bytes sent to the tx buffer. Currently, we set the destination MAC address to 0xFFFF as this is a broadcast message which will be seen by all devices. This can easily be changed in code. The source MAC is then read from the registers and is sent to the TX buffer. Once the MAC is sent the module sets the protocol type. Next the data is read from the inputs and is forwarded to the tx buffer. The module knows that the sender is done transmitting data when the request line is cleared. Once the transmission completes successfully, the module will indicate the successful transmission to the interfacing module.

*Receive Ethernet Packet*

ReceiveEthernetPacket.v

The second link layer module is Receive Ethernet Packet module which serves to construct a Ethernet frame and provide an interface with external hardware. Much simpler than the send module, the receive module contains 4 states. It begins by entering the waiting state. When an Ethernet receive request arrives the module begins to wait until it has access to the data, once the data is ready it will begin the read the header data. This data is then dumped and un-used as we do no implement a CRC check. After the header is read the data portion of the packet is clocked out on its data out port. When all data is read it will set the transmission complete line for one cycle before returning to the waiting state.

*Top Level Controller*

DM9000aController.v

The top level control module encapsulates all of the hardware required to initialize, send and receive data to and from the Ethernet chip. The module instantiates several modules including a TX and RX controller, a register access, initialization and interrupt detection module these modules will all communicate with the the Ethernet controller as dictated by the arbitrator. The Ethernet Controller module controls the bit timing and communication to the Ethernet chip.

*DM9000a Ethernet Controller*

The Ethernet chip provides several interface ports for communication these include a a chip select port, a command port to indicate address or data, a write enable port, a read enable port, 16 bits of data. As one data port is used for both the reads and the writes we determine in the Ethernet controller whether the data is being read or written.

To write to one of the controller's registers we must stick to a strict timing and data sequence. To begin writing to the Ethernet controller one must pull low the chip select pin and write the appropriate command. To begin a write to the chip we would issue an address type write. Therefore, our data line would indicate the address of the register where we want to write. The write data is held for at least one cycle before being driven low. A minimum of 2 cycle wait is required before we can begin to write data to certain registers. After the the data may begin to be written. This follows the same sequence as the address write however the command will be set to data. For specific timing values we consulted section 10.3.4 of the datasheet.

To read from the controller a similar process is followed. To read from a register in the controller we must first write the address of the register we want to read from to the controller. For this process we follow the write command sequence as outlined above. However, instead of writing again after the address write, we will draw the read line low and begin reading the data form the controller. The controller has a built in auto incrementing address for the read register, therefore it allows for sequential reads from registers without the need of writing an address every time. The specific timing for the reads was pulled from the datasheet section 10.3.3

*Controller Arbitrator*

EthernetControllerArbitrator.v

The controller arbiter directs communication between the modules. In order to communicate with the Davidcom chip all data must pass though the arbiter. A module wishing to communicate with the Ethernet chip will first need to issue a communication request to the arbiter. The arbiter will then grant the request to the modules in the following priority order: interrupt, register access, packet receive, packet send modules assuming all packets arrive at the same time. The arbiter will determine which module to grant access to based on priority and will notify the module that it now has access to the Ethernet controller. Combinationally, the proper outputs are assigned in the arbiter.

*Ethernet Controller*

EthernetController.v

The Ethernet controller is the module that controls communication and data timing with the Davidcom Ethernet chip. Its purpose is to provide a simple modular interface to talk with the Ethernet chip hardware. All of the inputs to the Ethernet controller come from either the arbiter or DM9000a Ethernet chip.

After reset, the Ethernet controller enters the wait state. In this state the controller is waiting for a start command from the arbiter. Once that command is received the controller will latch the data on its inputs. It then begins the sequence to communicate with the Ethernet chip.

As outlined in the EM9000a section, every read/write sequence will begin with a write of the target register. We designed the controller to be somewhat conservative with the timing as we found this gave us reliable performance. Once the write of the address takes place the controller will then either enter the write or read sequence depending on the command input form the arbiter. The read and write sequence will all be handled as described in the DM9000a section.

Depending on whether a read or a write is being performed we will drive the output data line with data from the read or write registers respectively.

*Initialization Module*

EthernetControllerInit.v

The Initialization module is one of the 5 modules that provides data to the Ethernet controller. Its sole purpose is to properly initialize the DM9000a Ethernet chip. We perform this function by storing all the initialization sequence in ROM and read it back during init.

The init sequence is started by pressing button 2 on the DE2 board. The initialization module will then issue a request to the arbiter. Once its write request is granted it will begin iterating though the ROM. The ROM entries are stored in the rom_init_data.mif file and are loaded on start-up. The ROM entries are described below.

*1. Register 0x1F write 0x00 - turn on the chip*
*2. Register 0x00 write 0x01 - reset chip*
*3. Register 0x00 write 0x00 - reset chip reset flag (delayed by 10us after chip reset)*
*4. Register 0xFF write 0x81 - reset interrupt flags*
*5. Register 0xFE write 0x3F - reset status flags*
*6. Register 0x01 write 0x2C - clear status bits*
*7. Register 0x05 write 0x03 - enable receiving & promiscuous mode*

The initialization procedure will sequentially read from the ROM and copy the data to the output of the module. Writing and timing is then handled by the Ethernet controller module. An additional function of the initialization module is to prohibit access to the data registers until the module is initiated. Therefore a request for a tx ethernet packet will not be able to commence until the initialization button is presses. A project implementing this code should make note of this requirement.

*Read Register Module*

ReadReg.v

The read register module functions to read from the registers of the device. The module waits for its grant before it can begin reading. It will issue the read as will return after the read is issued. The proper module will receive the data once the read is complete.

*Interrupt Detection Module*

InterruptDetector.v

The interrupt detector servers to service the interrupt and notify the proper modules when an interrupt occurs. The module is in the waiting state until an interrupt service request arrives. The interrupt module will then request a grant from the arbiter to determine the nature of the interrupt. A read is issued to the interrupt register on the chip. With the data read from the register the interrupt module determines if the interrupt was caused by a TX or RX complete. For one cycle the appropriate interrupt flag is asserted then cleared.

*Receive Packet Module*

RXController.v

The receive controller functions to read the data transmitted over the Ethernet link. For this module operates below the MAC sublayer and therefore only reads back the bits that are transmitted over the Ethernet link. Similar to the other modules, it begins in a wating state until a request for a receive packet is initiated. The module will then issue a request to the arbiter for access to the Ethernet controller. Once the grant is received the the controller will check to make sure that the chip is ready for a read. If so, it will then check for the data width in bits. Once this is determined we then determine the length of the received bits. We store an index that will continue reading every cycle until the total number of bits is read. Each segment is passed to the requesting module. At this point we have reached the end of the packet.

*Transmit Packet Module*

TXController.v

The transmit packet module functions to initiate data transfer across the Ethernet line. For this module operates below the MAC sublayer and functions to only send the bits it receives. When data is received by the transmit packet module it will attempt to get access to the Ethernet controller through an arbiter grant. When it receives the grant, the module will begin by waiting for the proper tX data to enter the module. The data will be continuously written so long as the user still asserts the tx_request line. Once all the data is received the module will issue the message transmission and wait on an interrupt indicating that the message transmission has completed successfully. The module will then enter the waiting state once more.

# Results and Analysis

*1. Speed*
When initialized, the control operates at the 100Mbps speed. We were able to continuously see valid packets on the network on a timely manner on our relatively low traffic point to point network. The only other traffic other than our device was the computer's continuous attempt to discover what other devices existed on the network.

*2. Accuracy*

After many tests and iterations were were able to develop a controller that accurately is able to transmit Ethernet frames. As we are sending and receiving packets just raw accuracy is somewhat binary. Using Wireshark we were able to verify the data transmitted and the timeliness of the transmission. With the device set to promiscuous mode we receive all packets that are transmitted on the link. We have not tested this on a very busy link such as the computer lab network so more tests are necessary to verify the accuracy in a high traffic environment. Alternatively, one could fully implement arp and other link layer technologies and then disable the promiscuous mode.

*3. Usability*

We designed our implementation to be fully modular and easy to integrate into future projects. As such our design provides the user with significantly greater usability and supported features than Ethernet drivers from previous projects. Specifically we provide an example and establish MAC layer support. Additional layers can be implemented by following our example for the MAC sublayer

*4. Safety*

Since our entire project is encapsulated on the Altera DE2 most of the physical safety precautions are handled by the boards construction. We also took measures to ensure taht the board stayed on the anti static mat and did not have any objects above or below it.

# Conclusions

*Summary*

Overall we believe this project was successful. Initially we planned to implement all layers up to the UDP transport layer entirely in hardware. However, we underestimated the difficulty in getting the DM9000a chip to cooperate with our hardware. With numerous registers, intricacies and timing requirements most of our time was spent debugging issues in communicating and setting up the chip. However, we believe that we finish this project as a good stopping point as were were able to implement the MAC layer. With all the hardware established, it should be much easier to implement higher layers. Especially due to the modular construction of the project.
