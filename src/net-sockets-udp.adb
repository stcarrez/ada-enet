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
         List := Endpoint;
         Endpoint.Ifnet  := Ifnet;
      end if;
      Endpoint.Listen.Port := Net.Headers.To_Network (Addr.Port);
      Endpoint.Listen.Addr := Ifnet.Ip;
   end Bind;

   procedure Send (Endpoint : in out Socket;
                   To       : in Sockaddr_In;
                   Packet   : in out Net.Buffers.Buffer_Type;
                   Status   : out Error_Code)
   is
      Ip  : constant Net.Headers.IP_Header_Access := Packet.IP;
      Hdr : constant Net.Headers.UDP_Header_Access := Packet.UDP;
      Len : constant Net.Uint16 := Packet.Get_Data_Size;
   begin
      Packet.Set_Length (Len);
      Hdr.Uh_Dport := To.Port;
      Hdr.Uh_Sport := Endpoint.Listen.Port;
      Hdr.Uh_Sum   := 0;
      Hdr.Uh_Ulen  := Net.Headers.To_Network (Len - 20 - 14);
      Net.Protos.IPv4.Make_Header (Ip, Endpoint.Listen.Addr, To.Addr, Net.Protos.IPv4.P_UDP, Len - 14);
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
   begin
      Addr.Addr := Ip.Ip_Src;
      Addr.Port := Hdr.Uh_Sport;
      while Soc /= null loop
         if Soc.Listen.Port = Hdr.Uh_Dport then
            Soc.Receive (Addr, Packet);
            return;
         end if;
         Soc := Soc.Next;
      end loop;
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
