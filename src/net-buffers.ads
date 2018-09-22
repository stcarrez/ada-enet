-----------------------------------------------------------------------
--  net-buffers -- Network buffers
--  Copyright (C) 2016, 2017, 2018 Stephane Carrez
--  Written by Stephane Carrez (Stephane.Carrez@gmail.com)
--
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.
-----------------------------------------------------------------------
with System;
with Net.Headers;

--  === Network Buffers ===
--  The <b>Net.Buffers</b> package provides support for network buffer management.
--  A network buffer can hold a single packet frame so that it is limited to 1500 bytes
--  of payload with 14 or 16 bytes for the Ethernet header.  The network buffers are
--  allocated by the Ethernet driver during the initialization to setup the
--  Ethernet receive queue.  The allocation of network buffers for the transmission
--  is under the responsibility of the application.
--
--  Before receiving a packet, the application also has to allocate a network buffer.
--  Upon successful reception of a packet by the <b>Receive</b> procedure, the allocated
--  network buffer will be given to the Ethernet receive queue and the application
--  will get back the received buffer.  There is no memory copy.
--
--  The package defines two important types: <b>Buffer_Type</b> and <b>Buffer_List</b>.
--  These two types are limited types to forbid copies and force a strict design to
--  applications.  The <b>Buffer_Type</b> describes the packet frame and it provides
--  various operations to access the buffer.  The <b>Buffer_List</b> defines a list of buffers.
--
--  The network buffers are kept within a single linked list managed by a protected object.
--  Because interrupt handlers can release a buffer, that protected object has the priority
--  <b>System.Max_Interrupt_Priority</b>.  The protected operations are very basic and are
--  in O(1) complexity so that their execution is bounded in time whatever the arguments.
--
--  Before anything, the network buffers have to be allocated.  The application can do this
--  by reserving some memory region (using <b>STM32.SDRAM.Reserve</b>) and adding the region with
--  the <b>Add_Region</b> procedure.  The region must be a multiple of <b>NET_ALLOC_SIZE</b>
--  constant.  To allocate 32 buffers, you can do the following:
--
--    NET_BUFFER_SIZE  : constant Interfaces.Unsigned_32 := Net.Buffers.NET_ALLOC_SIZE * 32;
--    ...
--    Net.Buffers.Add_Region (STM32.SDRAM.Reserve (Amount => NET_BUFFER_SIZE), NET_BUFFER_SIZE);
--
--  An application will allocate a buffer by using the <b>Allocate</b> operation and this is as
--  easy as:
--
--    Packet : Net.Buffers.Buffer_Type;
--    ...
--    Net.Buffers.Allocate (Packet);
--
--  What happens if there is no available buffer? No exception is raised because the networks
--  stack is intended to be used in embedded systems where exceptions are not available.
--  You have to check if the allocation succeeded by using the <b>Is_Null</b> function:
--
--    if Packet.Is_Null then
--      null; --  Oops
--    end if;
--
--  === Serialization ===
--  Several serialization operations are provided to build or extract information from a packet.
--  Before proceeding to the serialization, it is necessary to set the packet type.  The packet
--  type is necessary to reserve room for the protocol headers.  To build a UDP packet, the
--  <tt>UDP_PACKET</tt> type will be used:
--
--    Packet.Set_Type (Net.Buffers.UDP_PACKET);
--
--  Then, several <tt>Put</tt> operations are provided to serialize the data.  By default
--  integers are serialized in network byte order.  The <tt>Put_Uint8</tt> serializes one byte,
--  the <tt>Put_Uint16</tt> two bytes, the <tt>Put_Uint32</tt> four bytes.  The <tt>Put_String</tt>
--  operation will serialize a string.  A NUL byte is optional and can be added when the
--  <tt>With_Null</tt> optional parameter is set.  The example below creates a DNS query packet:
--
--    Packet.Put_Uint16 (1234);  -- XID
--    Packet.Put_Uint16 (16#0100#); -- Flags
--    Packet.Put_Uint16 (1); --  # queries
--    Packet.Put_Uint16 (0);
--    Packet.Put_Uint32 (0);
--    Packet.Put_Uint8 (16#3#);  -- Query
--    Packet.Put_String ("www.google.fr", With_Null => True);
--    Packet.Put_Uint16 (16#1#); --  A record
--    Packet.Put_Uint16 (16#1#); --  IN class
--
--  After a packet is serialized, the length get be obtained by using the
--
--    Len : Net.Uint16 := Packet.Get_Data_Length;
package Net.Buffers is

   pragma Preelaborate;

   --  The size of a packet buffer for memory allocation.
   NET_ALLOC_SIZE : constant Uint32;

   --  The maximum available size of the packet buffer for the application.
   --  We always have NET_BUF_SIZE < NET_ALLOC_SIZE.
   NET_BUF_SIZE   : constant Uint32;

   --  The packet type identifies the content of the packet for the serialization/deserialization.
   type Packet_Type is (RAW_PACKET, ETHER_PACKET, ARP_PACKET, IP_PACKET, UDP_PACKET, ICMP_PACKET,
                        DHCP_PACKET);

   type Data_Type is array (Net.Uint16 range 0 .. 1500 + 31) of aliased Uint8 with
     Alignment => 32;

   type Buffer_Type is tagged limited private;

   --  Returns true if the buffer is null (allocation failed).
   function Is_Null (Buf : in Buffer_Type) return Boolean;

   --  Allocate a buffer from the pool.  No exception is raised if there is no available buffer.
   --  The <tt>Is_Null</tt> operation must be used to check the buffer allocation.
   procedure Allocate (Buf : out Buffer_Type);

   --  Release the buffer back to the pool.
   procedure Release (Buf : in out Buffer_Type) with
     Post => Buf.Is_Null;

   --  Transfer the ownership of the buffer from <tt>From</tt> to <tt>To</tt>.
   --  If the destination has a buffer, it is first released.
   procedure Transfer (To   : in out Buffer_Type;
                       From : in out Buffer_Type) with
     Pre => not From.Is_Null,
     Post => From.Is_Null and not To.Is_Null;

   --  Switch the ownership of the two buffers.  The typical usage is on the Ethernet receive
   --  ring to peek a received packet and install a new buffer on the ring so that there is
   --  always a buffer on the ring.
   procedure Switch (To   : in out Buffer_Type;
                     From : in out Buffer_Type) with
     Pre => not From.Is_Null and not To.Is_Null,
     Post => not From.Is_Null and not To.Is_Null;

   --
   function Get_Data_Address (Buf : in Buffer_Type) return System.Address;

   function Get_Data_Size (Buf  : in Buffer_Type;
                           Kind : in Packet_Type) return Uint16;

   procedure Set_Data_Size (Buf : in out Buffer_Type; Size : in Uint16);

   function Get_Length (Buf : in Buffer_Type) return Uint16;

   procedure Set_Length (Buf : in out Buffer_Type; Size : in Uint16);

   --  Set the packet type.
   procedure Set_Type (Buf  : in out Buffer_Type;
                       Kind : in Packet_Type);

   --  Add a byte to the buffer data, moving the buffer write position.
   procedure Put_Uint8 (Buf   : in out Buffer_Type;
                        Value : in Net.Uint8) with
     Pre => not Buf.Is_Null;

   --  Add a 16-bit value in network byte order to the buffer data,
   --  moving the buffer write position.
   procedure Put_Uint16 (Buf   : in out Buffer_Type;
                         Value : in Net.Uint16) with
     Pre => not Buf.Is_Null;

   --  Add a 32-bit value in network byte order to the buffer data,
   --  moving the buffer write position.
   procedure Put_Uint32 (Buf   : in out Buffer_Type;
                         Value : in Net.Uint32) with
     Pre => not Buf.Is_Null;

   --  Add a string to the buffer data, moving the buffer write position.
   --  When <tt>With_Null</tt> is set, a NUL byte is added after the string.
   procedure Put_String (Buf       : in out Buffer_Type;
                         Value     : in String;
                         With_Null : in Boolean := False) with
     Pre => not Buf.Is_Null;

   --  Add an IP address to the buffer data, moving the buffer write position.
   procedure Put_Ip (Buf   : in out Buffer_Type;
                     Value : in Ip_Addr) with
     Pre => not Buf.Is_Null;

   --  Get a byte from the buffer, moving the buffer read position.
   function Get_Uint8 (Buf : in out Buffer_Type) return Net.Uint8 with
     Pre => not Buf.Is_Null;

   --  Get a 16-bit value in network byte order from the buffer, moving the buffer read position.
   function Get_Uint16 (Buf : in out Buffer_Type) return Net.Uint16 with
     Pre => not Buf.Is_Null;

   --  Get a 32-bit value in network byte order from the buffer, moving the buffer read position.
   function Get_Uint32 (Buf : in out Buffer_Type) return Net.Uint32 with
     Pre => not Buf.Is_Null;

   --  Get an IPv4 value from the buffer, moving the buffer read position.
   function Get_Ip (Buf : in out Buffer_Type) return Net.Ip_Addr with
     Pre => not Buf.Is_Null;

   --  Get a string whose length is specified by the target value.
   procedure Get_String (Buf  : in out Buffer_Type;
                         Into : out String) with
     Pre => not Buf.Is_Null;

   --  Skip a number of bytes in the buffer, moving the buffer position <tt>Size<tt> bytes ahead.
   procedure Skip (Buf  : in out Buffer_Type;
                   Size : in Net.Uint16) with
     Pre => not Buf.Is_Null;

   --  Get the number of bytes still available when reading the packet.
   function Available (Buf : in Buffer_Type) return Net.Uint16 with
     Pre => not Buf.Is_Null;

   --  Get access to the Ethernet header.
   function Ethernet (Buf : in Buffer_Type) return Net.Headers.Ether_Header_Access with
     Pre => not Buf.Is_Null;

   --  Get access to the ARP packet.
   function Arp (Buf : in Buffer_Type) return Net.Headers.Arp_Packet_Access with
     Pre => not Buf.Is_Null;

   --  Get access to the IPv4 header.
   function IP (Buf : in Buffer_Type) return Net.Headers.IP_Header_Access with
     Pre => not Buf.Is_Null;

   --  Get access to the UDP header.
   function UDP (Buf : in Buffer_Type) return Net.Headers.UDP_Header_Access with
     Pre => not Buf.Is_Null;

   --  Get access to the TCP header.
   function TCP (Buf : in Buffer_Type) return Net.Headers.TCP_Header_Access with
     Pre => not Buf.Is_Null;

   --  Get access to the IGMP header.
   function IGMP (Buf : in Buffer_Type) return Net.Headers.IGMP_Header_Access with
     Pre => not Buf.Is_Null;

   --  Get access to the ICMP header.
   function ICMP (Buf : in Buffer_Type) return Net.Headers.ICMP_Header_Access with
     Pre => not Buf.Is_Null;

   --  Get access to the DHCP header.
   function DHCP (Buf : in Buffer_Type) return Net.Headers.DHCP_Header_Access with
     Pre => not Buf.Is_Null;

   --  The <tt>Buffer_List</tt> holds a set of network buffers.
   type Buffer_List is limited private;

   --  Returns True if the list is empty.
   function Is_Empty (List : in Buffer_List) return Boolean;

   --  Insert the buffer to the list.
   procedure Insert (Into : in out Buffer_List;
                     Buf  : in out Buffer_Type) with
     Pre => not Buf.Is_Null,
     Post => Buf.Is_Null and not Is_Empty (Into);

   --  Release all the buffers held by the list.
   procedure Release (List : in out Buffer_List);

   --  Allocate <tt>Count</tt> buffers and add them to the list.
   --  There is no guarantee that the required number of buffers will be allocated.
   procedure Allocate (List  : in out Buffer_List;
                       Count : in Natural);

   --  Peek a buffer from the list.
   procedure Peek (From : in out Buffer_List;
                   Buf  : in out Buffer_Type);

   --  Transfer the list of buffers held by <tt>From</tt> at end of the list held
   --  by <tt>To</tt>.  After the transfer, the <tt>From</tt> list is empty.
   --  The complexity is in O(1).
   procedure Transfer (To   : in out Buffer_List;
                       From : in out Buffer_List) with
     Post => Is_Empty (From);

   use type System.Address;

   --  Add a memory region to the buffer pool.
   procedure Add_Region (Addr : in System.Address;
                         Size : in Uint32) with
     Pre => Size mod NET_ALLOC_SIZE = 0 and Size > 0 and Addr /= System.Null_Address;

private

   type Packet_Buffer;
   type Packet_Buffer_Access is access all Packet_Buffer;

   type Packet_Buffer is limited record
      Next : Packet_Buffer_Access;
      Size : Uint16;
      Data : aliased Data_Type;
   end record;

   type Buffer_Type is tagged limited record
      Kind   : Packet_Type := RAW_PACKET;
      Size   : Uint16 := 0;
      Pos    : Uint16 := 0;
      Packet : Packet_Buffer_Access;
   end record;

   type Buffer_List is limited record
      Head : Packet_Buffer_Access := null;
      Tail : Packet_Buffer_Access := null;
   end record;

   NET_ALLOC_SIZE : constant Uint32 := 4 + (Packet_Buffer'Size / 8);
   NET_BUF_SIZE   : constant Uint32 := Data_Type'Size / 8;

end Net.Buffers;
