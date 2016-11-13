-----------------------------------------------------------------------
--  net-dhcp -- DHCP client
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
with Interfaces; use Interfaces;
with Net.Headers;
with Ada.Real_Time;
with Net.Interfaces;
with Net.Buffers;
with Net.Protos.IPv4;
with Net.Sockets.Udp;
package body Net.DHCP is

   DEF_VENDOR_CLASS : constant String := "Ada Embedded Network";

   DHCP_DISCOVER : constant Net.Uint8 := 1;
   DHCP_OFFER    : constant Net.Uint8 := 2;
   DHCP_REQUEST  : constant Net.Uint8 := 3;
   DHCP_DECLINE  : constant Net.Uint8 := 4;
   DHCP_ACK      : constant Net.Uint8 := 5;
   DHCP_NACK     : constant Net.Uint8 := 6;
   DHCP_RELEASE  : constant Net.Uint8 := 7;

   --  ------------------------------
   --  Fill the DHCP options in the request.
   --  ------------------------------
   procedure Fill_Options (Request : in Client;
                           Packet  : in out Net.Buffers.Buffer_Type;
                           Kind    : in Net.Uint8;
                           Mac     : in Net.Ether_Addr) is
   begin
      --  DHCP magic cookie.
      Packet.Put_Uint8 (99);
      Packet.Put_Uint8 (130);
      Packet.Put_Uint8 (83);
      Packet.Put_Uint8 (99);

      --  Option 53: DHCP message type
      Packet.Put_Uint8 (53);
      Packet.Put_Uint8 (1);
      Packet.Put_Uint8 (Kind); --  Discover

      --  Option 50: Requested IP Address
      Packet.Put_Uint8 (50);
      Packet.Put_Uint8 (4);
      Packet.Put_Ip (Request.Ip);

      --  Option 54: DHCP Server Identifier.
      if Request.Server_Ip /= (0, 0, 0, 0) then
         Packet.Put_Uint8 (54);
         Packet.Put_Uint8 (4);
         Packet.Put_Ip (Request.Server_Ip);
      end if;

      --  Option 55: Parameter request List
      Packet.Put_Uint8 (55);
      Packet.Put_Uint8 (10);
      Packet.Put_Uint8 (1);
      Packet.Put_Uint8 (3);
      Packet.Put_Uint8 (6);
      Packet.Put_Uint8 (12);
      Packet.Put_Uint8 (15);
      Packet.Put_Uint8 (28);
      Packet.Put_Uint8 (42);
      Packet.Put_Uint8 (51);
      Packet.Put_Uint8 (58);
      Packet.Put_Uint8 (59);

      --  Option 60: Vendor class identifier.
      Packet.Put_Uint8 (60);
      Packet.Put_Uint8 (DEF_VENDOR_CLASS'Length);
      Packet.Put_String (DEF_VENDOR_CLASS);

      --  Option 61: Client identifier;
      Packet.Put_Uint8 (61);
      Packet.Put_Uint8 (7);
      Packet.Put_Uint8 (1);  --  Hardware type: Ethernet
      for V of Mac loop
         Packet.Put_Uint8 (V);
      end loop;

      --  Option 255: End
      Packet.Put_Uint8 (255);
   end Fill_Options;

   --  ------------------------------
   --  Send the DHCP discover packet to initiate the DHCP discovery process.
   --  ------------------------------
   procedure Discover (Request : in out Client;
                       Ifnet   : access Net.Interfaces.Ifnet_Type'Class) is
      Packet : Net.Buffers.Buffer_Type;
      Ether  : Net.Headers.Ether_Header_Access;
      Ip     : Net.Headers.IP_Header_Access;
      Udp    : Net.Headers.UDP_Header_Access;
      Hdr    : Net.Headers.DHCP_Header_Access;
      Len    : Net.Uint16;
      Addr   : Net.Sockets.Sockaddr_In;
   begin
      Addr.Port := Net.Headers.To_Network (68);
      Request.Bind (Ifnet, Addr);

      --  Generate a XID for the DHCP process.
      if Request.Xid = 0 then
         Request.Xid := Ifnet.Random;
      end if;
      Net.Buffers.Allocate (Packet);
      Packet.Set_Type (Net.Buffers.DHCP_PACKET);
      Ether := Packet.Ethernet;
      Ip  := Packet.IP;
      Udp := Packet.UDP;
      Hdr := Packet.DHCP;

      --  Fill the DHCP header.
      Hdr.Op    := 1;
      Hdr.Htype := 1;
      Hdr.Hlen  := 6;
      Hdr.Hops  := 0;
      Hdr.Flags := 0;
      Hdr.Xid1  := Net.Uint16 (Request.Xid and 16#0ffff#);
      Hdr.Xid2  := Net.Uint16 (Shift_Right (Request.Xid, 16));
      Hdr.Secs  := Net.Headers.To_Network (Request.Secs);
      Hdr.Ciaddr := (0, 0, 0, 0);
      Hdr.Yiaddr := (0, 0, 0, 0);
      Hdr.Siaddr := (0, 0, 0, 0);
      Hdr.Giaddr := (0, 0, 0, 0);
      Hdr.Chaddr := (others => Character'Val (0));
      for I in 1 .. 6 loop
         Hdr.Chaddr (I) := Character'Val (Ifnet.Mac (I));
      end loop;
      Hdr.Sname  := (others => Character'Val (0));
      Hdr.File   := (others => Character'Val (0));
      Fill_Options (Request, Packet, DHCP_DISCOVER, Ifnet.Mac);

      --  Get the packet length and setup the UDP header.
      Len := Packet.Get_Data_Size;
      Packet.Set_Length (Len);
      Udp.Uh_Sport := Net.Headers.To_Network (68);
      Udp.Uh_Dport := Net.Headers.To_Network (67);
      Udp.Uh_Ulen  := Net.Headers.To_Network (Len - 20 - 14);
      Udp.Uh_Sum   := 0;

      --  Set the IP header to broadcast the packet.
      Net.Protos.IPv4.Make_Header (Ip, (0, 0, 0, 0), (255, 255, 255, 255),
                                   Net.Protos.IPv4.P_UDP, Uint16 (Len - 14));

      --  And set the Ethernet header for the broadcast.
      Ether.Ether_Shost := Ifnet.Mac;
      Ether.Ether_Dhost := (others => 16#ff#);
      Ether.Ether_Type  := Net.Headers.To_Network (Net.Protos.ETHERTYPE_IP);

      --  Broadcast the DHCP packet.
      Ifnet.Send (Packet);
   end Discover;

   overriding
   procedure Receive (Request  : in out Client;
                      From     : in Net.Sockets.Sockaddr_In;
                      Packet   : in out Net.Buffers.Buffer_Type) is
      Hdr    : Net.Headers.DHCP_Header_Access := Packet.DHCP;
   begin
      if Hdr.Op /= 2 or Hdr.Htype /= 1 or Hdr.Hlen /= 6 then
         return;
      end if;
      if Hdr.Xid1 /= Net.Uint16 (Request.Xid and 16#0ffff#) then
         return;
      end if;
      if Hdr.Xid2 /= Net.Uint16 (Shift_Right (Request.Xid, 16)) then
         return;
      end if;
      Request.Ip := Hdr.Yiaddr;
   end Receive;

end Net.DHCP;
