-----------------------------------------------------------------------
--  dns -- DNS Example
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
with HAL.Bitmap;
with Net.Buffers;
with Net.Utils;
with Net.Protos.Arp;
with Net.DNS;
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
procedure Dns is

   use type Interfaces.Unsigned_32;
   use type Net.Ip_Addr;
   use type Ada.Real_Time.Time;

   procedure Refresh;
   procedure Header;

   function Get_Status (Query : in Net.DNS.Query) return String is
      use type Net.DNS.Status_Type;

      S : constant Net.DNS.Status_Type := Query.Get_Status;
   begin
      if S = Net.DNS.PENDING then
         return "...";
      elsif S = Net.DNS.NOERROR then
         return "OK";
      elsif S = Net.DNS.NOQUERY then
         return "";
      else
         return "FAIL";
      end if;
   end Get_Status;

   procedure Refresh is
      Y     : Natural := 90;
   begin
      for I in Receiver.Queries'Range loop
         if Receiver.Queries (I).Get_Name'Length > 0 then
            Demos.Put (0, Y, Receiver.Queries (I).Get_Name);
            Demos.Put (200, Y, Net.Utils.To_String (Receiver.Queries (I).Get_Ip));
            Demos.Put (350, Y, Get_Status (Receiver.Queries (I)));
            Demos.Put (400, Y, Net.Uint32'Image (Receiver.Queries (I).Get_Ttl));
            --  Put (250, Y, Net.Uint64 (Hosts (I).Seq));
            --  Put (350, Y, Net.Uint64 (Hosts (I).Received));
            Y := Y + 16;
         end if;
      end loop;
      Demos.Refresh_Ifnet_Stats (Receiver.Ifnet);
      STM32.Board.Display.Update_Layer (1);

      Receiver.Queries (1).Resolve (Receiver.Ifnet'Access, "www.google.com");
      Receiver.Queries (2).Resolve (Receiver.Ifnet'Access, "www.facebook.com");
      Receiver.Queries (3).Resolve (Receiver.Ifnet'Access, "www.apple.com");
      Receiver.Queries (4).Resolve (Receiver.Ifnet'Access, "www.adacore.com");
      Receiver.Queries (5).Resolve (Receiver.Ifnet'Access, "github.com");
      Receiver.Queries (6).Resolve (Receiver.Ifnet'Access, "www.twitter.com");
      Receiver.Queries (7).Resolve (Receiver.Ifnet'Access, "www.kalabosse.com");
   end Refresh;

   procedure Header is
   begin
      null;
   end Header;

   procedure Initialize is new Demos.Initialize (Header);

   --  The ping period.
   PING_PERIOD   : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Milliseconds (1000);

   --  Send ping echo request deadline
   Ping_Deadline : Ada.Real_Time.Time;

begin
   Initialize ("STM32 DNS", Receiver.Ifnet);

   Ping_Deadline := Ada.Real_Time.Clock;
   loop
      declare
         Now     : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      begin
         Net.Protos.Arp.Timeout (Receiver.Ifnet);
         if Ping_Deadline < Now then
            Refresh;
            Ping_Deadline := Ping_Deadline + PING_PERIOD;
         end if;
         delay until Now + PING_PERIOD;
      end;
   end loop;
end Dns;
