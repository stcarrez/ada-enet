-----------------------------------------------------------------------
--  net-protos-icmp -- ICMP v4 Network protocol
--  Copyright (C) 2016, 2017 Stephane Carrez
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
with Net.Headers;
with Net.Protos.IPv4;
package body Net.Protos.Icmp is

   --  ------------------------------
   --  Send a ICMP echo request packet to the target IP.  The ICMP header is
   --  initialized with the given sequence and identifier so that ICMP reply
   --  can be identified.
   --  ------------------------------
   procedure Echo_Request (Ifnet     : in out Net.Interfaces.Ifnet_Type'Class;
                           Target_Ip : in Ip_Addr;
                           Packet    : in out Net.Buffers.Buffer_Type;
                           Seq       : in Net.Uint16;
                           Ident     : in Net.Uint16;
                           Status    : out Error_Code) is
      Ip  : constant Net.Headers.IP_Header_Access   := Packet.IP;
      Hdr : constant Net.Headers.ICMP_Header_Access := Packet.ICMP;
   begin
      Hdr.Icmp_Type := Net.Headers.ICMP_ECHO_REQUEST;
      Hdr.Icmp_Code := 0;
      Hdr.Icmp_Seq  := Net.Headers.To_Network (Seq);
      Hdr.Icmp_Id   := Net.Headers.To_Network (Ident);
      Hdr.Icmp_Checksum := 0;
      Net.Protos.IPv4.Make_Header (Ip, Ifnet.Ip, Target_Ip, Net.Protos.IPv4.P_ICMP,
                                   Uint16 (Packet.Get_Length - 14));
      Net.Protos.IPv4.Send_Raw (Ifnet, Target_Ip, Packet, Status);
   end Echo_Request;

   --  ------------------------------
   --  Receive and handle an ICMP packet.
   --  ------------------------------
   procedure Receive (Ifnet     : in out Net.Interfaces.Ifnet_Type'Class;
                      Packet    : in out Net.Buffers.Buffer_Type) is
      Ip     : constant Net.Headers.IP_Header_Access := Packet.IP;
      Hdr    : constant Net.Headers.ICMP_Header_Access := Packet.ICMP;
      Status : Error_Code;
   begin
      if Hdr.Icmp_Type = Net.Headers.ICMP_ECHO_REQUEST and Hdr.Icmp_Code = 0 then
         Hdr.Icmp_Type := Net.Headers.ICMP_ECHO_REPLY;
         Hdr.Icmp_Checksum := 0;
         Ip.Ip_Dst := Ip.Ip_Src;
         Ip.Ip_Src := Ifnet.Ip;
         Net.Protos.IPv4.Make_Ident (Ip);
         --  Net.Protos.Arp.Update (Ifnet, Ip.Ip_Dst, Ether.Ether_Shost);
         Net.Protos.IPv4.Send_Raw (Ifnet, Ip.Ip_Dst, Packet, Status);
      else
         Net.Buffers.Release (Packet);
      end if;
   end Receive;

end Net.Protos.Icmp;
