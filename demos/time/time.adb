-----------------------------------------------------------------------
--  time -- NTP example
--  Copyright (C) 2017 Stephane Carrez
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
with Interfaces;
with Ada.Real_Time;
with STM32.Board;
with HAL.Bitmap;
with BMP_Fonts;
with Net.Buffers;
with Net.Protos.Arp;
with Net.DHCP;
with Net.NTP;
with Demos;
with Time_Manager;

--  == Time Application ==
--  The <b>Time</b> application uses the NTP v4 protocol to retrieve the current date and time
--  and displays the GMT time.  The application uses the DHCP client to obtain the IP
--  configuration and then start the NTP synchronisation.  Once the NTP synchronisation is
--  obtained it convert the NTP time to display the GMT time.
--
--  The application has two tasks.  The main task loops to manage the refresh of the STM32
--  display and also to perform some network housekeeping such as the DHCP client management
--  NTP synchronisation and ARP table management.  The second task is responsible for waiting
--  Ethernet packets, analyzing them to handle ARP, ICMP and UDP packets.
procedure Time is

   use type Net.Uint16;
   use type Net.Uint32;
   use type Net.Uint64;
   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;

   procedure Refresh (Deadline : out Ada.Real_Time.Time);
   procedure Header;
   function To_Digits (Val : Net.Uint32) return String;
   function To_String (H, M, S : Net.Uint32) return String;
   procedure Server_Status (X, Y     : in Natural;
                            Server   : in out Net.NTP.Client;
                            Deadline : in out Ada.Real_Time.Time);

   Dec_String : constant String := "0123456789";

   function To_Digits (Val : Net.Uint32) return String is
      Result : String (1 .. 2);
   begin
      Result (1) := Dec_String (Positive ((Val / 10) + 1));
      Result (2) := Dec_String (Positive ((Val mod 10) + 1));
      return Result;
   end To_Digits;

   function To_String (H, M, S : Net.Uint32) return String is
   begin
      return To_Digits (H) & ":" & To_Digits (M) & ":" & To_Digits (S);
   end To_String;

   procedure Server_Status (X, Y     : in Natural;
                            Server   : in out Net.NTP.Client;
                            Deadline : in out Ada.Real_Time.Time) is
      T    : Net.NTP.NTP_Timestamp;
      H    : Net.Uint32;
      M    : Net.Uint32;
      S    : Net.Uint32;
      W    : Net.Uint64;
      Dt   : Net.Uint64;
      Ref  : constant Net.NTP.NTP_Reference := Server.Get_Reference;
      Wait : Ada.Real_Time.Time;
   begin
      Demos.Current_Font := BMP_Fonts.Font16x24;
      if not (Ref.Status in Net.NTP.SYNCED | Net.NTP.RESYNC) then
         Demos.Put (X, Y, "??:??:??");
      else
         T := Net.NTP.Get_Time (Ref);
         S := T.Seconds mod 86400;
         H := S / 3600;
         S := S mod 3600;
         M := S / 60;
         S := S mod 60;
         W := Net.Uint64 (Net.Uint32'Last - T.Sub_Seconds);
         W := Interfaces.Shift_Right (W * 1_000_000, 32);
         Wait := Ada.Real_Time.Clock + Ada.Real_Time.Microseconds (Integer (W));
         if Wait < Deadline then
            Deadline := Wait;
         end if;
         Dt := Net.Uint64 (Ref.Delta_Time / Net.NTP.ONE_USEC);
         Demos.Put (X, Y, To_String (H, M, S));
         Demos.Current_Font := BMP_Fonts.Font8x8;
         Demos.Put (X + 100, Y + 4, Dt);
      end if;
      Demos.Current_Font := BMP_Fonts.Font8x8;
   end Server_Status;

   procedure Refresh (Deadline : out Ada.Real_Time.Time) is
   begin
      Deadline := Ada.Real_Time.Clock + Ada.Real_Time.Seconds (1);
      Demos.Refresh_Ifnet_Stats;
      Server_Status (250, 130, Time_Manager.Client, Deadline);
      Server_Status (250, 160, Time_Manager.Ubuntu_Ntp.Server, Deadline);
      Server_Status (250, 190, Time_Manager.Bbox_Ntp.Server, Deadline);
      Server_Status (250, 220, Time_Manager.Pool_Ntp.Server, Deadline);
      STM32.Board.Display.Update_Layer (1);
   end Refresh;

   procedure Header is
   begin
      Demos.Current_Font := BMP_Fonts.Font16x24;
      Demos.Put (0, 130, "DHCP");
      Demos.Put (0, 160, "ntp.ubuntu.com");
      Demos.Put (0, 190, "ntp.bbox.fr");
      Demos.Put (0, 220, "pool.ntp.org");
      Demos.Put (0, 100, "Name");
      Demos.Put (250, 100, "GMT Time");
      Demos.Current_Font := BMP_Fonts.Font8x8;
      Demos.Put (390, 100, "Offset (us)");
   end Header;

   procedure Initialize is new Demos.Initialize (Header);

   use type Net.DHCP.State_Type;

   Ntp_Init       : Boolean := False;
   Dhcp_Deadline  : Ada.Real_Time.Time;
   Ntp_Deadline   : Ada.Real_Time.Time;
   Clock_Deadline : Ada.Real_Time.Time;
   Error          : Net.Error_Code;
begin
   Initialize ("STM32 NTP Time");

   Time_Manager.Ubuntu_Ntp.Port := Net.NTP.NTP_PORT + 1;
   Time_Manager.Bbox_Ntp.Port   := Net.NTP.NTP_PORT + 2;
   Time_Manager.Pool_Ntp.Port   := Net.NTP.NTP_PORT + 3;
   loop
      Net.Protos.Arp.Timeout (Demos.Ifnet);
      Demos.Dhcp.Process (Dhcp_Deadline);
      if Ntp_Init = False and then Demos.Dhcp.Get_State = Net.DHCP.STATE_BOUND then
         Time_Manager.Client.Initialize (Demos.Ifnet'Access, Demos.Dhcp.Get_Config.Ntp);
         Time_Manager.Ubuntu_Ntp.Resolve (Demos.Ifnet'Access, "ntp.ubuntu.com", Error);
         Time_Manager.Bbox_Ntp.Resolve (Demos.Ifnet'Access, "ntp.bbox.fr", Error);
         Time_Manager.Pool_Ntp.Resolve (Demos.Ifnet'Access, "pool.ntp.org", Error);
         Ntp_Init := True;
      end if;
      if Ntp_Init then
         Time_Manager.Client.Process (Ntp_Deadline);
         Time_Manager.Ubuntu_Ntp.Server.Process (Ntp_Deadline);
         Time_Manager.Bbox_Ntp.Server.Process (Ntp_Deadline);
         Time_Manager.Pool_Ntp.Server.Process (Ntp_Deadline);
      else
         Ntp_Deadline := Dhcp_Deadline;
      end if;
      Refresh (Clock_Deadline);
      if Dhcp_Deadline < Clock_Deadline then
         Clock_Deadline := Dhcp_Deadline;
      end if;
      if Ntp_Deadline < Clock_Deadline then
         Clock_Deadline := Ntp_Deadline;
      end if;
      delay until Clock_Deadline;
   end loop;
end Time;
