-----------------------------------------------------------------------
--  net-headers -- Network headers
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
package Net.Headers is

   pragma Preelaborate;

   --  Convert integers to network byte order.
   function To_Network (Val : in Uint32) return Uint32;
   function To_Network (Val : in Uint16) return Uint16;

   --  Convert integers to host byte order.
   function To_Host (Val : in Uint32) return Uint32;
   function To_Host (Val : in Uint16) return Uint16;

   --  Ethernet header as defined for 802.3 Ethernet packet.
   type Ether_Header is record
      Ether_Dhost : Ether_Addr;
      Ether_Shost : Ether_Addr;
      Ether_Type  : Uint16;
   end record;
   type Ether_Header_Access is access all Ether_Header;

   type Arp_Header is record
      Ar_Hdr      : Uint16;
      Ar_Pro      : Uint16;
      Ar_Hln      : Uint8;
      Ar_Pln      : Uint8;
      Ar_Op       : Uint16;
   end record;

   type Ether_Arp is record
      Ea_Hdr      : Arp_Header;
      Arp_Sha     : Ether_Addr;
      Arp_Spa     : Ip_Addr;
      Arp_Tha     : Ether_Addr;
      Arp_Tpa     : Ip_Addr;
   end record;
   type Ether_Arp_Access is access all Ether_Arp;

   --  ARP Ethernet packet
   type Arp_Packet is record
      Ethernet : Net.Headers.Ether_Header;
      Arp      : Net.Headers.Ether_Arp;
   end record;
   type Arp_Packet_Access is access all Arp_Packet;

   --  IP packet header RFC 791.
   type IP_Header is record
      Ip_Ihl      : Uint8;
      Ip_Tos      : Uint8;
      Ip_Len      : Uint16;
      Ip_Id       : Uint16;
      Ip_Off      : Uint16;
      Ip_Ttl      : Uint8;
      Ip_P        : Uint8;
      Ip_Sum      : Uint16;
      Ip_Src      : Ip_Addr;
      Ip_Dst      : Ip_Addr;
   end record;
   type IP_Header_Access is access all IP_Header;

   --  UDP packet header RFC 768.
   type UDP_Header is record
      Uh_Sport    : Uint16;
      Uh_Dport    : Uint16;
      Uh_Ulen     : Uint16;
      Uh_Sum      : Uint16;
   end record;
   type UDP_Header_Access is access all UDP_Header;

   --  IGMP v2 packet header RFC 2236.
   type IGMP_Header is record
      Igmp_Type   : Uint8;
      Igmp_Code   : Uint8;
      Igmp_Cksum  : Uint16;
      Igmp_Group  : Ip_Addr;
   end record;
   type IGMP_Header_Access is access all IGMP_Header;

   IGMP_MEMBERSHIP_QUERY     : constant Uint8 := 16#11#;
   IGMP_V1_MEMBERSHIP_REPORT : constant Uint8 := 16#12#;
   IGMP_V2_MEMBERSHIP_REPORT : constant Uint8 := 16#16#;
   IGMP_V3_MEMBERSHIP_REPORT : constant Uint8 := 16#22#; --  RFC 3376.
   IGMP_V2_LEAVE_GROUP       : constant Uint8 := 16#17#;
   IGMP_DVMRP                : constant Uint8 := 16#13#;
   IGMP_PIM                  : constant Uint8 := 16#14#;

   type TCP_Header is record
      Th_Sport    : Uint16;
      Th_Dport    : Uint16;
      Th_Seq      : Uint32;
      Th_Ack      : Uint32;
      Th_Off      : Uint8;
      Th_Flags    : Uint8;
      Th_Win      : Uint16;
      Th_Sum      : Uint16;
      Th_Urp      : Uint16;
   end record;
   type TCP_Header_Access is access all TCP_Header;

   ICMP_ECHO_REPLY           : constant Uint8 := 0;
   ICMP_UNREACHABLE          : constant Uint8 := 3;
   ICMP_ECHO_REQUEST         : constant Uint8 := 8;

   type ICMP_Header is record
      Icmp_Type     : Uint8;
      Icmp_Code     : Uint8;
      Icmp_Checksum : Uint16;
      Icmp_Id       : Uint16;  --  This should be an union
      Icmp_Seq      : Uint16;
   end record;
   type ICMP_Header_Access is access all ICMP_Header;

   --  DHCP header as defined by RFC 1541.
   type DHCP_Header is record
      Op     : Uint8;
      Htype  : Uint8;
      Hlen   : Uint8;
      Hops   : Uint8;
      Xid1   : Uint16;
      Xid2   : Uint16;
      Secs   : Uint16;
      Flags  : Uint16;
      Ciaddr : Ip_Addr;
      Yiaddr : Ip_Addr;
      Siaddr : Ip_Addr;
      Giaddr : Ip_Addr;
      Chaddr : String (1 .. 16);
      Sname  : String (1 .. 64);
      File   : String (1 .. 128);
   end record;
   type DHCP_Header_Access is access all DHCP_Header;

   for DHCP_Header use record
      Op     at 0 range 0 .. 7;
      Htype  at 1 range 0 .. 7;
      Hlen   at 2 range 0 .. 7;
      Hops   at 3 range 0 .. 7;
      Xid1   at 4 range 0 .. 15;
      Xid2   at 6 range 0 .. 15;
      Secs   at 8 range 0 .. 15;
      Flags  at 10 range 0 .. 15;
      Ciaddr at 12 range 0 .. 31;
      Yiaddr at 16 range 0 .. 31;
      Siaddr at 20 range 0 .. 31;
      Giaddr at 24 range 0 .. 31;
      Chaddr at 28 range 0 .. 127;
      Sname  at 44 range 0 .. 511;
      File   at 108 range 0 .. 1023;
   end record;

end Net.Headers;
