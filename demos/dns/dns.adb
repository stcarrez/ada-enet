-----------------------------------------------------------------------
--  dns -- DNS Example
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
with Interfaces;

with STM32.Board;
with HAL.Bitmap;
with Net.Buffers;
with Net.Utils;
with Net.Protos.Arp;
with Net.DNS;
with Net.DHCP;
with Receiver;
with Dns_List;
with Demos;

pragma Unreferenced (Receiver);

--  == DNS Application ==
--  The <b>DNS</b> application resolves several domain names by using the DNS client and it
--  displays the IPv4 address that was resolved.  It periodically resolve the names and
--  also displays the TTL associated with the response.
--
--  The application has two tasks.  The main task loops to manage the refresh of the STM32
--  display and send the DNS resolution requests regularly.  The second task is responsible for
--  waiting of Ethernet packets, analyzing them to handle ARP and DNS response packets.
procedure Dns is

   use type Interfaces.Unsigned_32;
   use type Net.Ip_Addr;
   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;

   procedure Refresh;
   procedure Header;
   function Get_Status (Query : in Net.DNS.Query) return String;

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
      for I in Dns_List.Queries'Range loop
         if Dns_List.Queries (I).Get_Name'Length > 0 then
            Demos.Put (0, Y, Dns_List.Queries (I).Get_Name);
            Demos.Put (180, Y, Net.Utils.To_String (Dns_List.Queries (I).Get_Ip));
            Demos.Put (330, Y, Get_Status (Dns_List.Queries (I)));
            Demos.Put (400, Y, Net.Uint32'Image (Dns_List.Queries (I).Get_Ttl));
            --  Put (250, Y, Net.Uint64 (Hosts (I).Seq));
            --  Demos.Put (400, Y, Net.Uint64 (Dns_List.Queries (I).));
            Y := Y + 16;
         end if;
      end loop;
      Demos.Refresh_Ifnet_Stats;
      STM32.Board.Display.Update_Layer (1);

      if Demos.Dhcp.Get_State = Net.DHCP.STATE_BOUND then
         Dns_List.Queries (1).Resolve (Demos.Ifnet'Access, "www.google.com", Status);
         Dns_List.Queries (2).Resolve (Demos.Ifnet'Access, "www.facebook.com", Status);
         Dns_List.Queries (3).Resolve (Demos.Ifnet'Access, "www.apple.com", Status);
         Dns_List.Queries (4).Resolve (Demos.Ifnet'Access, "www.adacore.com", Status);
         Dns_List.Queries (5).Resolve (Demos.Ifnet'Access, "github.com", Status);
         Dns_List.Queries (6).Resolve (Demos.Ifnet'Access, "www.twitter.com", Status);
         Dns_List.Queries (7).Resolve (Demos.Ifnet'Access, "www.kalabosse.com", Status);
      end if;
   end Refresh;

   procedure Header is null;

   procedure Initialize is new Demos.Initialize (Header);

   --  The display refresh period.
   REFRESH_PERIOD   : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Milliseconds (1000);

   --  Refresh display deadline.
   Display_Deadline : Ada.Real_Time.Time;
   Dhcp_Deadline    : Ada.Real_Time.Time;

begin
   Initialize ("STM32 DNS");

   Display_Deadline := Ada.Real_Time.Clock;
   loop
      Net.Protos.Arp.Timeout (Demos.Ifnet);
      Demos.Dhcp.Process (Dhcp_Deadline);
      if Display_Deadline < Ada.Real_Time.Clock then
         Refresh;
         Display_Deadline := Display_Deadline + REFRESH_PERIOD;
      end if;
      if Dhcp_Deadline < Display_Deadline then
         delay until Dhcp_Deadline;
      else
         delay until Display_Deadline;
      end if;
   end loop;
end Dns;
