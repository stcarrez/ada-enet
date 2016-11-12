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

   procedure Refresh;

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
      Demos.Refresh_Ifnet_Stats (Receiver.Ifnet);
      STM32.Board.Display.Update_Layer (1);
   end Refresh;

   --  The ping period.
   PING_PERIOD   : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Milliseconds (1000);

   --  Send ping echo request deadline
   Ping_Deadline : Ada.Real_Time.Time;

begin
   Demos.Initialize (Receiver.Ifnet);

   Receiver.Add_Host ((192, 168, 1, 1));
   Receiver.Add_Host ((8, 8, 8, 8));

   for I in 1 .. 2 loop
      Demos.Current_Font := BMP_Fonts.Font16x24;
      Demos.Put (0, 0, "STM32 Ping");
      Demos.Current_Font := BMP_Fonts.Font8x8;
      Demos.Put (5, 30, "IP");
      Demos.Put (4, 40, "Gateway");
      Demos.Put (250, 30, "Rx");
      Demos.Put (250, 40, "Tx");
      Demos.Put (302, 14, "Packets");
      Demos.Put (418, 14, "Bytes");
      Demos.Put (0, 70, "Host");
      Demos.Put (326, 70, "Send");
      Demos.Put (402, 70, "Receive");
      STM32.Board.Display.Get_Hidden_Buffer (1).Draw_Horizontal_Line
        (Color => HAL.Bitmap.Blue,
         X     => 0,
         Y     => 84,
         Width => 480);
      STM32.Board.Display.Update_Layer (1);
   end loop;

   --  Change font to 8x8.
   Demos.Current_Font := BMP_Fonts.Font8x8;
   Ping_Deadline := Ada.Real_Time.Clock;
   loop
      declare
         Now     : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      begin
         Net.Protos.Arp.Timeout (Receiver.Ifnet);
         if Ping_Deadline < Now then
            Receiver.Do_Ping;
            Refresh;
            Ping_Deadline := Ping_Deadline + PING_PERIOD;
         end if;
         delay until Now + PING_PERIOD;
      end;
   end loop;
end Ping;
