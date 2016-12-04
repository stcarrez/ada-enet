-----------------------------------------------------------------------
--  net-sockets-udp -- UDP socket-like interface
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
with Net.Protos.IPv4;

package body Net.Sockets.Udp is

   List : access Socket'Class;

   procedure Bind (Endpoint : access Socket'Class;
                   Ifnet    : access Net.Interfaces.Ifnet_Type'Class;
                   Addr     : in Sockaddr_In) is
   begin
      if Endpoint.Ifnet = null then
         Endpoint.Next := List;
         List := Endpoint.all'Unchecked_Access;
         Endpoint.Ifnet  := Ifnet;
      end if;
      Endpoint.Listen.Port := Addr.Port;
      Endpoint.Listen.Addr := Ifnet.Ip;
   end Bind;

   procedure Send (Endpoint : in out Socket;
                   To       : in Sockaddr_In;
                   Packet   : in out Net.Buffers.Buffer_Type;
                   Status   : out Error_Code)
   is
      Ip  : constant Net.Headers.IP_Header_Access := Packet.IP;
      Hdr : constant Net.Headers.UDP_Header_Access := Packet.UDP;
      Len : constant Net.Uint16 := Packet.Get_Data_Size (Net.Buffers.IP_PACKET);
   begin
      Packet.Set_Length (Len + 20 + 14);
      Hdr.Uh_Dport := To.Port;
      Hdr.Uh_Sport := Endpoint.Listen.Port;
      Hdr.Uh_Sum   := 0;
      Hdr.Uh_Ulen  := Net.Headers.To_Network (Len);
      if Endpoint.Listen.Addr = (0, 0, 0, 0) then
         Net.Protos.IPv4.Make_Header (Ip, Endpoint.Ifnet.Ip, To.Addr, Net.Protos.IPv4.P_UDP, Len + 20);
      else
         Net.Protos.IPv4.Make_Header (Ip, Endpoint.Listen.Addr, To.Addr, Net.Protos.IPv4.P_UDP, Len + 20);
      end if;
      Net.Protos.IPv4.Send_Raw (Endpoint.Ifnet.all, To.Addr, Packet, Status);
   end Send;

   --  ------------------------------
   --  Input a UDP packet and dispatch it to the associated UDP socket.
   --  ------------------------------
   procedure Input (Ifnet  : in out Net.Interfaces.Ifnet_Type'Class;
                    Packet : in out Net.Buffers.Buffer_Type) is
      Ip   : constant Net.Headers.IP_Header_Access := Packet.IP;
      Hdr  : constant Net.Headers.UDP_Header_Access := Packet.UDP;
      Addr : Net.Sockets.Sockaddr_In;
      Soc  : access Socket'Class := List;
      Len  : Net.Uint16;
   begin
      Addr.Addr := Ip.Ip_Src;
      Addr.Port := Hdr.Uh_Sport;
      while Soc /= null loop
         if Soc.Listen.Port = Hdr.Uh_Dport then
            Len := Net.Headers.To_Host (Hdr.Uh_Ulen) - 8;
            Packet.Set_Type (Net.Buffers.UDP_PACKET);
            if Len < Packet.Get_Data_Size (Net.Buffers.UDP_PACKET) then
               Packet.Set_Length (Len + 8 + 20 + 14);
            end if;
            Soc.Receive (Addr, Packet);
            return;
         end if;
         Soc := Soc.Next;
      end loop;
      Ifnet.Rx_Stats.Ignored := Ifnet.Rx_Stats.Ignored + 1;
   end Input;

   --  ------------------------------
   --  Send a raw packet.  The packet must have the Ethernet, IP and UDP headers initialized.
   --  ------------------------------
   procedure Send (Endpoint : in out Raw_Socket;
                   Packet   : in out Net.Buffers.Buffer_Type) is
   begin
      Endpoint.Ifnet.Send (Packet);
   end Send;

end Net.Sockets.Udp;
