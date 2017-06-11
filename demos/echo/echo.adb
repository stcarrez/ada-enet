-----------------------------------------------------------------------
--  echo -- UDP Echo Server
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

with Ada.Real_Time;
with STM32.Board;
with HAL.Bitmap;
with Net.Buffers;
with Net.Protos.Arp;
with Net.Sockets.Udp;
with Net.Headers;
with Echo_Server;
with Demos;

--  == Echo Application ==
--  The <b>Echo</b> application listens to the UDP port 7 on the Ethernet network and it
--  sends back the received packet to the sender: this is the RFC 862 Echo protocol.
--  The application also maintains a list of the last 10 messages that have been received.
--  The list is then displayed on the STM32 display so that we get a visual feedback of the
--  received messages.
--
--  The <b>Echo</b> application uses the DHCP client to get and IP address and the
--  default gateway.
--
--  The application has two tasks.  The main task loops to manage the refresh of the STM32
--  display and also to perform some network housekeeping such as the DHCP client management
--  and ARP table management.  The second task is responsible for waiting Ethernet packets,
--  analyzing them to handle ARP, ICMP and UDP packets.
procedure Echo is

   use type Ada.Real_Time.Time;

   procedure Refresh;
   procedure Header;

   procedure Refresh is
      Msg : constant Echo_Server.Message_List := Echo_Server.Server.Messages.Get;
      Y   : Natural := 120;
   begin
      Demos.Refresh_Ifnet_Stats;
      Demos.Put (250, 100, Net.Uint64 (Echo_Server.Server.Count));
      for M of Msg loop
         exit when M.Id = 0;
         Demos.Put (0, Y, Natural'Image (M.Id));
         Demos.Put (100, Y, M.Content);
         Y := Y + 15;
      end loop;
      STM32.Board.Display.Update_Layer (1);
   end Refresh;

   procedure Header is
   begin
      Demos.Put (0, 100, "Echo packets");
   end Header;

   procedure Initialize is new Demos.Initialize (Header);

   Dhcp_Deadline : Ada.Real_Time.Time;

begin
   Initialize ("STM32 Echo");

   Echo_Server.Server.Bind (Demos.Ifnet'Access, (Port => Net.Headers.To_Network (7),
                                                 Addr => (others => 0)));

   loop
      Net.Protos.Arp.Timeout (Demos.Ifnet);
      Demos.Dhcp.Process (Dhcp_Deadline);
      Refresh;
      delay until Ada.Real_Time.Clock + Ada.Real_Time.Milliseconds (500);
   end loop;
end Echo;
