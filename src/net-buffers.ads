-----------------------------------------------------------------------
--  net-buffers -- Network buffers
--  Copyright (C) 2016 Stephane Carrez
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
package Net.Buffers is

   --  The size of a packet buffer for memory allocation.
   NET_ALLOC_SIZE : constant Uint32;

   --  The maximum available size of the packet buffer for the application.
   --  We always have NET_BUF_SIZE < NET_ALLOC_SIZE.
   NET_BUF_SIZE   : constant Uint32;

   type Data_Type is array (0 .. 1500 + 31) of aliased Uint8 with
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

   function Get_Data_Size (Buf : in Buffer_Type) return Natural;

   procedure Set_Data_Size (Buf : in out Buffer_Type; Size : in Natural);

   function Get_Length (Buf : in Buffer_Type) return Natural;

   procedure Set_Length (Buf : in out Buffer_Type; Size : in Natural);

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

   --  The STM32 Ethernet driver builds the receive ring in the SDRAM and allocates the
   --  memory dynamically.  The memory area is not initialized and we need a way to force
   --  its initialization by clearing the internal <tt>Size</tt> and <tt>Packet</tt> attributes.
   --  Calling this method in another context might result in buffer leak.
   procedure Unsafe_Reset (Buffer : in out Buffer_Type) with
     Post => Buffer.Is_Null;

private

   type Packet_Buffer;
   type Packet_Buffer_Access is access all Packet_Buffer;

   type Packet_Buffer is limited record
      Next : Packet_Buffer_Access;
      Data : aliased Data_Type;
   end record;

   type Buffer_Type is tagged limited record
      Size   : Natural := 0;
      Packet : Packet_Buffer_Access;
   end record;

   type Buffer_List is limited record
      Head : Packet_Buffer_Access := null;
      Tail : Packet_Buffer_Access := null;
   end record;

   NET_ALLOC_SIZE : constant Uint32 := 4 + (Packet_Buffer'Size / 8);
   NET_BUF_SIZE   : constant Uint32 := Data_Type'Size / 8;

end Net.Buffers;
