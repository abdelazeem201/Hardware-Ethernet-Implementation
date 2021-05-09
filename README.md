# Introduction
We developed an implementation of Ethernet packet tx/rx fully on hardware. Currently, there are several projects that make use of the DE2 Ethernet port. However, none of these projects focused on creating a modular platform to allow for easy integrate with higher layer protocols. Other projects make use of the NIOS II for Ethernet initialization and lower level control. A major deficiency is the lack of a full hardware implementation that can allow for the easy implementation of higher layer protocols.

We hope that our project will be beneficial for future groups looking to make use of Ethernet without the requirement of adding a NIOS to their hardware.

# High Level Design

*1. Rationale and Inspiration:

If the trend continues, connectivity will have an increasingly important role in product design. After looking at prior years projects it became apparent that there was not a good hardware implementation of Ethernet that also allowed for the addition of higher level protocols. Other projects that did use Ethernet were implemented with the NIOS II which takes up size and adds to system complexity. We desired to pursue this project as it explored new hardware not addressed during any other labs and we believe that a good implementation could provide to be very useful for student projects in the future.

*2. Logical Structure:

At a high level our design consists of a single FPGA in conjunction with the Davidcom Ethernet chip. Our project will initialize the Ethernet chip and then provides routines for sending and receiving packets from the link. The code was designed to be modular to simplify the addition of higher layer protocols. See the diagram in the hardware section for a visual depiction of the project module interconnections.

We created a general module that contained all the hardware needed to send and receive basic packets. Adding the Ethernet Top module expands our implementation to send Ethernet frames. These modules will essentially perform all tasks as defined by the layer and then append the appropriate data to the packet/frame.

*3. Hardware Software Trade-offs:

For our project we decided to use a fully hardware approach. Our goal of the project was to construct a hardware module capable of Ethernet frame transmission. Overall a hardware only approach will increase the processing speed of the Ethernet unit. However, the most significant improvement is the ability to have a link layer protocol enabled in hardware without necessarily introducing a NIOS to the system. This will save in both gates and system complexity. Additionally the modular approach allows for the addition of higher layer protocols if need be.


*4. Standards:

As we aimed to make our project as universal as possible we adhere to the RFC standards. As we implemented Ethernet frames we adhered to the standard as depicted below.

![Fig. Ethernet Frame format, type II](https://en.wikipedia.org/wiki/Ethernet_frame#/media/File:Ethernet_Type_II_Frame_format.svg)

