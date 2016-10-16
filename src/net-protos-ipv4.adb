-----------------------------------------------------------------------
--  net-protos-Ipv4 -- IPv4 Network protocol
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
with Net.Headers;
with Net.Buffers;
with Net.Protos.Arp;
package body Net.Protos.IPv4 is

   use type Net.Protos.Arp.Arp_Status;

   procedure Send (Ifnet     : in out Net.Interfaces.Ifnet_Type'Class;
                   Target_Ip : in Ip_Addr;
                   Packet    : in out Net.Buffers.Buffer_Type) is
      Ether  : constant Net.Headers.Ether_Header_Access := Packet.Ethernet;
      Ip     : constant Net.Headers.IP_Header_Access := Packet.IP;
      Status : Net.Protos.Arp.Arp_Status;
   begin
      Ip.Ip_Ihl := 4;
      Ip.Ip_Tos := 0;
      Ip.Ip_Id  := 2;
      Ip.Ip_Off := 0;
      Ip.Ip_Ttl := 255;
      Ip.Ip_Sum := 0;
      Ip.Ip_Src := Ifnet.Ip;
      Ip.Ip_Dst := Target_Ip;
      Ip.Ip_P   := 4;
      --  Ip.Ip_Len := Net.Headers.To_Network (Packet.Get_Length);
      --  if Ifnet.Is_Local_Address (Target_Ip) then

      Ether.Ether_Shost := Ifnet.Mac;
      Ether.Ether_Type  := Net.Headers.To_Network(Net.Protos.ETHERTYPE_IP);
      Net.Protos.Arp.Resolve (Ifnet, Target_Ip, Ether.Ether_Dhost, Status);
      case Status is
         when Net.Protos.Arp.ARP_FOUND =>
            Ifnet.Send (Packet);

         when Net.Protos.Arp.ARP_PENDING | Net.Protos.Arp.ARP_NEEDED =>
            --  Net.Protos.Arp.Queue (Ifnet, Target_Ip, Packet);
            null;

         when Net.Protos.Arp.ARP_UNREACHABLE =>
            Net.Buffers.Release (Packet);

      end case;
   end Send;

end Net.Protos.IPv4;
