-----------------------------------------------------------------------
--  receiver -- Ethernet Packet Receiver
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
with Ada.Real_Time;
with Net.Buffers;
with Net.Protos.Arp;
with Net.Protos.Icmp;
with Net.Protos.IPv4;
with Net.Headers;
with Net.Sockets.Udp;
with Net.Interfaces;
with Demos;
package body Receiver is

   use type Net.Ip_Addr;
   use type Net.Uint8;
   use type Net.Uint16;

   procedure IP_Input (Ifnet  : in out Net.Interfaces.Ifnet_Type'Class;
                       Packet : in out Net.Buffers.Buffer_Type);

   procedure IP_Input (Ifnet  : in out Net.Interfaces.Ifnet_Type'Class;
                       Packet : in out Net.Buffers.Buffer_Type) is
      Ip_Hdr : constant Net.Headers.IP_Header_Access := Packet.IP;
   begin
      if Ip_Hdr.Ip_P = Net.Protos.IPv4.P_ICMP then
         Net.Protos.Icmp.Receive (Ifnet, Packet);

      elsif Ip_Hdr.Ip_P = Net.Protos.IPv4.P_UDP then
         Net.Sockets.Udp.Input (Ifnet, Packet);

         --  To find our gateway, we look at the IGMP query general packets and we assume
         --  that hosts that send IGMP membership query are gateways.
         --  224.0.0.1 is the All Hosts multicast group.
      elsif Ip_Hdr.Ip_P = Net.Protos.IPv4.P_IGMP and Ip_Hdr.Ip_Dst = (224, 0, 0, 1) then
         declare
            Group : constant Net.Headers.IGMP_Header_Access := Packet.IGMP;
         begin
            if Group.Igmp_Type = Net.Headers.IGMP_MEMBERSHIP_QUERY then
               Ifnet.Gateway := Ip_Hdr.Ip_Src;
            end if;
         end;
      end if;
   end IP_Input;

   task body Controller is
      use type Ada.Real_Time.Time;

      Packet  : Net.Buffers.Buffer_Type;
      Ether   : Net.Headers.Ether_Header_Access;
   begin
      while not Demos.Ifnet.Is_Ready loop
         delay until Ada.Real_Time.Clock + Ada.Real_Time.Seconds (1);
      end loop;
      loop
         if Packet.Is_Null then
            Net.Buffers.Allocate (Packet);
         end if;
         if not Packet.Is_Null then
            Demos.Ifnet.Receive (Packet);
            Ether := Packet.Ethernet;
            if Ether.Ether_Type = Net.Headers.To_Network (Net.Protos.ETHERTYPE_ARP) then
               Net.Protos.Arp.Receive (Demos.Ifnet, Packet);
            elsif Ether.Ether_Type = Net.Headers.To_Network (Net.Protos.ETHERTYPE_IP) then
               IP_Input (Demos.Ifnet, Packet);
            end if;
         else
            delay until Ada.Real_Time.Clock + Ada.Real_Time.Milliseconds (100);
         end if;
      end loop;
   end Controller;

end Receiver;
