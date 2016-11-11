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
with Ada.Unchecked_Conversion;
package body Net.Buffers is

   ETHER_POS  : constant Natural := 0;
   IP_POS     : constant Natural := ETHER_POS + 14;
   UDP_POS    : constant Natural := IP_POS + 20;  --  Note: this is wrong due to IP options.
   TCP_POS    : constant Natural := IP_POS + 24;  --  Note: this is wrong due to IP options.
   IGMP_POS   : constant Natural := IP_POS + 24;
   ICMP_POS   : constant Natural := IP_POS + 20;
   --  DATA_POS  : constant Natural := UDP_POS + 8;

   function As_Ethernet is
     new Ada.Unchecked_Conversion (Source => System.Address,
                                   Target => Net.Headers.Ether_Header_Access);

   function As_Arp is
     new Ada.Unchecked_Conversion (Source => System.Address,
                                   Target => Net.Headers.Arp_Packet_Access);

   function As_Ip_Header is
     new Ada.Unchecked_Conversion (Source => System.Address,
                                   Target => Net.Headers.IP_Header_Access);

   function As_Udp_Header is
     new Ada.Unchecked_Conversion (Source => System.Address,
                                   Target => Net.Headers.UDP_Header_Access);

   function As_Tcp_Header is
     new Ada.Unchecked_Conversion (Source => System.Address,
                                   Target => Net.Headers.TCP_Header_Access);

   function As_Igmp_Header is
     new Ada.Unchecked_Conversion (Source => System.Address,
                                   Target => Net.Headers.IGMP_Header_Access);

   function As_Icmp_Header is
     new Ada.Unchecked_Conversion (Source => System.Address,
                                   Target => Net.Headers.ICMP_Header_Access);

   protected Manager is
      procedure Allocate (Packet : out Packet_Buffer_Access);

      procedure Release (Packet : in out Packet_Buffer_Access);

      procedure Add_Region (Addr  : in System.Address;
                            Count : in Uint32);

      procedure Release (List : in out Buffer_List);

      procedure Allocate (List  : in out Buffer_List;
                          Count : in Natural);

   private
      pragma Priority (System.Max_Interrupt_Priority);

      Free_List : Packet_Buffer_Access;
   end Manager;

   --  ------------------------------
   --  Returns true if the buffer is null (allocation failed).
   --  ------------------------------
   function Is_Null (Buf : in Buffer_Type) return Boolean is
   begin
      return Buf.Packet = null;
   end Is_Null;

   --  ------------------------------
   --  Allocate a buffer from the pool.  No exception is raised if there is no available buffer.
   --  The <tt>Is_Null</tt> operation must be used to check the buffer allocation.
   --  ------------------------------
   procedure Allocate (Buf : out Buffer_Type) is
   begin
      Manager.Allocate (Buf.Packet);
      Buf.Size   := 0;
   end Allocate;

   --  ------------------------------
   --  Release the buffer back to the pool.
   --  ------------------------------
   procedure Release (Buf : in out Buffer_Type) is
   begin
      if Buf.Packet /= null then
         Manager.Release (Buf.Packet);
      end if;
   end Release;

   --  ------------------------------
   --  Transfer the ownership of the buffer from <tt>From</tt> to <tt>To</tt>.
   --  If the destination has a buffer, it is first released.
   --  ------------------------------
   procedure Transfer (To   : in out Buffer_Type;
                       From : in out Buffer_Type) is
   begin
      if To.Packet /= null then
         Manager.Release (To.Packet);
      end if;
      To.Packet := From.Packet;
      To.Size   := From.Size;
      From.Packet := null;
   end Transfer;

   --  ------------------------------
   --  Switch the ownership of the two buffers.  The typical usage is on the Ethernet receive
   --  ring to peek a received packet and install a new buffer on the ring so that there is
   --  always a buffer on the ring.
   --  ------------------------------
   procedure Switch (To   : in out Buffer_Type;
                     From : in out Buffer_Type) is
      Size   : constant Natural := To.Size;
      Packet : constant Packet_Buffer_Access := To.Packet;
   begin
      To.Size   := From.Size;
      To.Packet := From.Packet;
      From.Size := Size;
      From.Packet := Packet;
   end Switch;

   function Get_Data_Address (Buf : in Buffer_Type) return System.Address is
   begin
      return Buf.Packet.Data (Buf.Packet.Data'First)'Address;
   end Get_Data_Address;

   function Get_Data_Size (Buf : in Buffer_Type) return Natural is
   begin
      return Buf.Size;
   end Get_Data_Size;

   procedure Set_Data_Size (Buf : in out Buffer_Type; Size : in Natural) is
   begin
      Buf.Size := Size;
      Buf.Packet.Size := Size;
   end Set_Data_Size;

   function Get_Length (Buf : in Buffer_Type) return Natural is
   begin
      return Buf.Size;
   end Get_Length;

   procedure Set_Length (Buf : in out Buffer_Type; Size : in Natural) is
   begin
      Buf.Size := Size;
      Buf.Packet.Size := Size;
   end Set_Length;

   --  ------------------------------
   --  Set the packet type.
   --  ------------------------------
   procedure Set_Type (Buf  : in out Buffer_Type;
                       Kind : in Packet_Type) is
   begin
      Buf.Kind := Kind;
   end Set_Type;

   --  ------------------------------
   --  Get access to the Ethernet header.
   --  ------------------------------
   function Ethernet (Buf : in Buffer_Type) return Net.Headers.Ether_Header_Access is
   begin
      return As_Ethernet (Buf.Packet.Data (Buf.Packet.Data'First)'Address);
   end Ethernet;

   --  ------------------------------
   --  Get access to the ARP packet.
   --  ------------------------------
   function Arp (Buf : in Buffer_Type) return Net.Headers.Arp_Packet_Access is
   begin
      return As_Arp (Buf.Packet.Data (Buf.Packet.Data'First)'Address);
   end Arp;

   --  ------------------------------
   --  Get access to the IPv4 header.
   --  ------------------------------
   function IP (Buf : in Buffer_Type) return Net.Headers.IP_Header_Access is
   begin
      return As_Ip_Header (Buf.Packet.Data (IP_POS)'Address);
   end IP;

   --  ------------------------------
   --  Get access to the UDP header.
   --  ------------------------------
   function UDP (Buf : in Buffer_Type) return Net.Headers.UDP_Header_Access is
   begin
      return As_Udp_Header (Buf.Packet.Data (UDP_POS)'Address);
   end UDP;

   --  ------------------------------
   --  Get access to the TCP header.
   --  ------------------------------
   function TCP (Buf : in Buffer_Type) return Net.Headers.TCP_Header_Access is
   begin
      return As_Tcp_Header (Buf.Packet.Data (20 + 14)'Address);
   end TCP;

   --  ------------------------------
   --  Get access to the IGMP header.
   --  ------------------------------
   function IGMP (Buf : in Buffer_Type) return Net.Headers.IGMP_Header_Access is
   begin
      return As_Igmp_Header (Buf.Packet.Data (IGMP_POS)'Address);
   end IGMP;

   --  ------------------------------
   --  Get access to the ICMP header.
   --  ------------------------------
   function ICMP (Buf : in Buffer_Type) return Net.Headers.ICMP_Header_Access is
   begin
      return As_Icmp_Header (Buf.Packet.Data (ICMP_POS)'Address);
   end ICMP;

   --  ------------------------------
   --  Returns True if the list is empty.
   --  ------------------------------
   function Is_Empty (List : in Buffer_List) return Boolean is
   begin
      return List.Head = null;
   end Is_Empty;

   --  ------------------------------
   --  Insert the buffer to the list.
   --  ------------------------------
   procedure Insert (Into : in out Buffer_List;
                     Buf  : in out Buffer_Type) is
   begin
      if Into.Tail = null then
         Into.Tail := Buf.Packet;
         Buf.Packet.Next := null;
      else
         Buf.Packet.Next := Into.Head;
      end if;
      Into.Head       := Buf.Packet;
      Buf.Packet      := null;
   end Insert;

   --  ------------------------------
   --  Release all the buffers held by the list.
   --  ------------------------------
   procedure Release (List : in out Buffer_List) is
   begin
      Manager.Release (List);
   end Release;

   --  ------------------------------
   --  Allocate <tt>Count</tt> buffers and add them to the list.
   --  There is no guarantee that the required number of buffers will be allocated.
   --  ------------------------------
   procedure Allocate (List  : in out Buffer_List;
                       Count : in Natural) is
   begin
      Manager.Allocate (List, Count);
   end Allocate;

   --  ------------------------------
   --  Peek a buffer from the list.
   --  ------------------------------
   procedure Peek (From : in out Buffer_List;
                   Buf  : in out Buffer_Type) is
   begin
      Buf.Packet := From.Head;
      Buf.Size   := Buf.Packet.Size;
      From.Head  := From.Head.Next;
   end Peek;

   --  ------------------------------
   --  Transfer the list of buffers held by <tt>From</tt> at end of the list held
   --  by <tt>To</tt>.  After the transfer, the <tt>From</tt> list is empty.
   --  The complexity is in O(1).
   --  ------------------------------
   procedure Transfer (To   : in out Buffer_List;
                       From : in out Buffer_List) is
   begin
      if To.Tail /= null then
         To.Tail.Next := From.Head;
         From.Head := To.Head;
      else
         To.Tail := From.Tail;
         To.Head := From.Head;
      end if;
      From.Head := null;
      From.Tail := null;
   end Transfer;

   --  ------------------------------
   --  Add a memory region to the buffer pool.
   --  ------------------------------
   procedure Add_Region (Addr : in System.Address;
                         Size : in Uint32) is
      Count : constant Uint32 := Size / NET_ALLOC_SIZE;
   begin
      Manager.Add_Region (Addr, Count);
   end Add_Region;

   --  ------------------------------
   --  The STM32 Ethernet driver builds the receive ring in the SDRAM and allocates the
   --  memory dynamically.  The memory area is not initialized and we need a way to force
   --  its initialization by clearing the internal <tt>Size</tt> and <tt>Packet</tt> attributes.
   --  Calling this method in another context might result in buffer leak.
   --  ------------------------------
   procedure Unsafe_Reset (Buffer : in out Buffer_Type) is
   begin
      Buffer.Packet := null;
      Buffer.Size   := 0;
   end Unsafe_Reset;

   protected body Manager is

      procedure Allocate (Packet : out Packet_Buffer_Access) is
      begin
         Packet    := Free_List;
         if Packet /= null then
            Free_List := Packet.Next;
            Packet.Size := 0;
         end if;
      end Allocate;

      procedure Allocate (List  : in out Buffer_List;
                          Count : in Natural) is
         Packet : Packet_Buffer_Access;
      begin
         for I in 1 .. Count loop
            exit when Free_List = null;
            Packet := Free_List;
            Free_List := Packet.Next;
            if List.Tail = null then
               List.Tail := Packet;
            else
               Packet.Next := List.Head;
            end if;
            List.Head := Packet;
         end loop;
      end Allocate;

      procedure Release (Packet : in out Packet_Buffer_Access) is
      begin
         Packet.Next := Free_List;
         Free_List   := Packet;
         Packet      := null;
      end Release;

      procedure Release (List : in out Buffer_List) is
      begin
         List.Tail.Next := Free_List;
         Free_List   := List.Head;
         List.Head   := null;
      end Release;

      procedure Add_Region (Addr  : in System.Address;
                            Count : in Uint32) is

         type Packet_Array is array (1 .. Count) of aliased Packet_Buffer;
         type Packet_Array_Access is access all Packet_Array;
         function As_Packet_List is
           new Ada.Unchecked_Conversion (Source => System.Address,
                                         Target => Packet_Array_Access);

         Packets : Packet_Array_Access := As_Packet_List (Addr);
      begin
         for I in 1 .. Count loop
            Packets (I).Next := Free_List;
            Free_List := Packets (I)'Unchecked_Access;
         end loop;
      end Add_Region;

   end Manager;

end Net.Buffers;
