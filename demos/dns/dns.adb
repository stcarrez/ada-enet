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
with Net.DHCP;
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
   use type Ada.Real_Time.Time_Span;

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
      use type Net.DHCP.State_Type;

      Y     : Natural := 90;
      Status : Net.Error_Code;
      pragma Unreferenced (Status);
   begin
      for I in Receiver.Queries'Range loop
         if Receiver.Queries (I).Get_Name'Length > 0 then
            Demos.Put (0, Y, Receiver.Queries (I).Get_Name);
            Demos.Put (180, Y, Net.Utils.To_String (Receiver.Queries (I).Get_Ip));
            Demos.Put (300, Y, Get_Status (Receiver.Queries (I)));
            Demos.Put (350, Y, Net.Uint32'Image (Receiver.Queries (I).Get_Ttl));
            --  Put (250, Y, Net.Uint64 (Hosts (I).Seq));
            --  Demos.Put (400, Y, Net.Uint64 (Receiver.Queries (I).));
            Y := Y + 16;
         end if;
      end loop;
      Demos.Refresh_Ifnet_Stats;
      STM32.Board.Display.Update_Layer (1);

      if Demos.Dhcp.Get_State = Net.DHCP.STATE_BOUND then
         Receiver.Queries (1).Resolve (Demos.Ifnet'Access, "www.google.com", Status);
         Receiver.Queries (2).Resolve (Demos.Ifnet'Access, "www.facebook.com", Status);
         Receiver.Queries (3).Resolve (Demos.Ifnet'Access, "www.apple.com", Status);
         Receiver.Queries (4).Resolve (Demos.Ifnet'Access, "www.adacore.com", Status);
         Receiver.Queries (5).Resolve (Demos.Ifnet'Access, "github.com", Status);
         Receiver.Queries (6).Resolve (Demos.Ifnet'Access, "www.twitter.com", Status);
         Receiver.Queries (7).Resolve (Demos.Ifnet'Access, "www.kalabosse.com", Status);
      end if;
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
   Initialize ("STM32 DNS");

   Ping_Deadline := Ada.Real_Time.Clock;
   loop
      declare
         Now          : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
         Dhcp_Timeout : Ada.Real_Time.Time_Span;
      begin
         Net.Protos.Arp.Timeout (Demos.Ifnet);
         Demos.Dhcp.Process (Dhcp_Timeout);
         if Ping_Deadline < Now then
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
end Dns;
