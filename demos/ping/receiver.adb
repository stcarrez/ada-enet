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
with Net.Interfaces;
with Net.Sockets.Udp;
with Demos;
package body Receiver is

   use type Net.Ip_Addr;
   use type Net.Uint8;
   use type Net.Uint16;

   procedure ARP_Input (Ifnet : in out Net.Interfaces.Ifnet_Type'Class;
                        Packet : in out Net.Buffers.Buffer_Type);
   procedure IP_Input (Ifnet  : in out Net.Interfaces.Ifnet_Type'Class;
                       Packet : in out Net.Buffers.Buffer_Type);

   --  The protected object that holds the ping database.
   protected Pinger is

      procedure Receive (Packet : in out Net.Buffers.Buffer_Type);
      function Get_Hosts return Ping_Info_Array;
      procedure Prepare_Send (Targets : in out Ping_Info_Array);
      procedure Add_Host (Ip : in Net.Ip_Addr);

   private
      Hosts         : Ping_Info_Array (1 .. MAX_PING_HOST);
      Last_Host     : Natural := 0;
      Send_Count    : Natural := 0;
      Receive_Count : Natural := 0;
   end Pinger;

   protected body Pinger is

      procedure Receive (Packet : in out Net.Buffers.Buffer_Type) is
         Ip_Hdr : constant Net.Headers.IP_Header_Access := Packet.IP;
      begin
         for I in 1 .. Last_Host loop
            if Hosts (I).Ip = Ip_Hdr.Ip_Src then
               Hosts (I).Received := Hosts (I).Received + 1;
               Receive_Count := Receive_Count + 1;
               return;
            end if;
         end loop;
      end Receive;

      procedure Prepare_Send (Targets : in out Ping_Info_Array) is
      begin
         for I in Targets'Range loop
            Hosts (I).Seq := Hosts (I).Seq + 1;
         end loop;
         Targets := Hosts (Targets'Range);
         Send_Count := Send_Count + 1;
      end Prepare_Send;

      function Get_Hosts return Ping_Info_Array is
      begin
         return Hosts (1 .. Last_Host);
      end Get_Hosts;

      procedure Add_Host (Ip : in Net.Ip_Addr) is
      begin
         if Last_Host < Hosts'Last then
            for I in 1 .. Last_Host loop
               if Hosts (I).Ip = Ip then
                  return;
               end if;
            end loop;
            Last_Host := Last_Host + 1;
            Hosts (Last_Host).Ip  := Ip;
            Hosts (Last_Host).Seq := 0;
            Hosts (Last_Host).Received := 0;
         end if;
      end Add_Host;

   end Pinger;

   --  ------------------------------
   --  Get the list of hosts with their ping counters.
   --  ------------------------------
   function Get_Hosts return Ping_Info_Array is
   begin
      return Pinger.Get_Hosts;
   end Get_Hosts;

   --  ------------------------------
   --  Add the host to ping list.
   --  ------------------------------
   procedure Add_Host (Ip : in Net.Ip_Addr) is
   begin
      Pinger.Add_Host (Ip);
   end Add_Host;

   --  ------------------------------
   --  Send the ICMP echo request to each host.
   --  ------------------------------
   procedure Do_Ping is
      Hosts  : Ping_Info_Array := Pinger.Get_Hosts;
      Packet : Net.Buffers.Buffer_Type;
      Status : Net.Error_Code;
   begin
      Pinger.Prepare_Send (Hosts);
      for I in Hosts'Range loop
         Net.Buffers.Allocate (Packet);
         exit when Packet.Is_Null;

         Packet.Set_Length (64);
         Net.Protos.Icmp.Echo_Request (Ifnet     => Demos.Ifnet,
                                       Target_Ip => Hosts (I).Ip,
                                       Packet    => Packet,
                                       Seq       => Hosts (I).Seq,
                                       Ident     => 1234,
                                       Status    => Status);
      end loop;
   end Do_Ping;

   procedure ARP_Input (Ifnet : in out Net.Interfaces.Ifnet_Type'Class;
                        Packet : in out Net.Buffers.Buffer_Type) is
      Req : constant Net.Headers.Arp_Packet_Access := Packet.Arp;
   begin
      if Net.Headers.To_Host (Req.Arp.Ea_Hdr.Ar_Op) = Net.Protos.Arp.ARPOP_REQUEST then
         Receiver.Add_Host (Req.Arp.Arp_Spa);
      end if;
      Net.Protos.Arp.Receive (Ifnet, Packet);
   end ARP_Input;

   procedure IP_Input (Ifnet  : in out Net.Interfaces.Ifnet_Type'Class;
                       Packet : in out Net.Buffers.Buffer_Type) is
      Ip_Hdr : constant Net.Headers.IP_Header_Access := Packet.IP;
      Hdr    : constant Net.Headers.ICMP_Header_Access := Packet.ICMP;
   begin
      --  Collect the IP addresses for hosts that send packets.
      --  Ignore 0.0.0.0 due to DHCP packets.
      if Ip_Hdr.Ip_Src /= (0, 0, 0, 0) then
         Receiver.Add_Host (Ip_Hdr.Ip_Src);
      end if;
      if Ip_Hdr.Ip_P = Net.Protos.IPv4.P_ICMP then
         if Ip_Hdr.Ip_Dst = Ifnet.Ip and Hdr.Icmp_Type = Net.Headers.ICMP_ECHO_REPLY then
            Pinger.Receive (Packet);
         end if;
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
               ARP_Input (Demos.Ifnet, Packet);
            elsif Ether.Ether_Type = Net.Headers.To_Network (Net.Protos.ETHERTYPE_IP) then
               IP_Input (Demos.Ifnet, Packet);
            end if;
         else
            delay until Ada.Real_Time.Clock + Ada.Real_Time.Milliseconds (100);
         end if;
      end loop;
   end Controller;

end Receiver;
