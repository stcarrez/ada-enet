-----------------------------------------------------------------------
--  ping -- Ping hosts application
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
with Interfaces;
with STM32.Board;
with BMP_Fonts;
with HAL.Bitmap;
with Net.Buffers;
with Net.Utils;
with Net.Protos.Arp;
with Receiver;
with Demos;

--  == Ping Application ==
--  The <b>Ping</b> application listens to the Ethernet network to identify some local
--  hosts and ping them using ICMP echo requests.
--
--  The <b>Ping</b> application uses the static IP address <b>192.168.1.2</b> and an initial
--  default gateway <b>192.168.1.254</b>.  While running, it discovers the gateway by looking
--  at the IGMP query membership packets.
--
--  The <b>Ping</b> application displays the lists of hosts that it currently pings with
--  the number of ICMP requests that are sent and the number of ICMP replies received.
--
--  The application has two tasks.  The main task loops to manage the refresh of the STM32
--  display and send the ICMP echo requests each second.  The second task is responsible for
--  waiting of Ethernet packets, analyzing them to handle ARP and ICMP packets.  The receiver
--  task also looks at IGMP packets to identify the IGMP queries sent by routers.
procedure Ping is

   use type Interfaces.Unsigned_32;
   use type Net.Ip_Addr;
   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;

   procedure Refresh;
   procedure Header;

   procedure Refresh is
      Y     : Natural := 90;
      Hosts : constant Receiver.Ping_Info_Array := Receiver.Get_Hosts;
   begin
      for I in Hosts'Range loop
         Demos.Put (0, Y, Net.Utils.To_String (Hosts (I).Ip));
         Demos.Put (250, Y, Net.Uint64 (Hosts (I).Seq));
         Demos.Put (350, Y, Net.Uint64 (Hosts (I).Received));
         Y := Y + 16;
      end loop;
      Demos.Refresh_Ifnet_Stats;
      STM32.Board.Display.Update_Layer (1);
   end Refresh;

   procedure Header is
   begin
      Demos.Put (0, 70, "Host");
      Demos.Put (326, 70, "Send");
      Demos.Put (402, 70, "Receive");
   end Header;

   procedure Initialize is new Demos.Initialize (Header);

   --  The ping period.
   PING_PERIOD   : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Milliseconds (1000);

   --  Send ping echo request deadline
   Ping_Deadline : Ada.Real_Time.Time;

begin
   Initialize ("STM32 Ping");

   Receiver.Add_Host ((192, 168, 1, 1));
   Receiver.Add_Host ((8, 8, 8, 8));

   --  Change font to 8x8.
   Demos.Current_Font := BMP_Fonts.Font8x8;
   Ping_Deadline := Ada.Real_Time.Clock;
   loop
      declare
         Now          : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
         Dhcp_Timeout : Ada.Real_Time.Time_Span;
      begin
         Net.Protos.Arp.Timeout (Demos.Ifnet);
         Demos.Dhcp.Process (Dhcp_Timeout);
         if Ping_Deadline < Now then
            Receiver.Do_Ping;
            Refresh;
            Ping_Deadline := Ping_Deadline + PING_PERIOD;
         end if;
         if Dhcp_Timeout < PING_PERIOD then
            delay until Now + Dhcp_Timeout;
         else
            delay until Now + PING_PERIOD;
         end if;
      end;
   end loop;
end Ping;
