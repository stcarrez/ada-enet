-----------------------------------------------------------------------
--  demos -- Utility package for the demos
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
with Bitmapped_Drawing;
with Bitmap_Color_Conversion;
with STM32.SDRAM;
with STM32.RNG.Interrupts;
with Net.Utils;
with Receiver;
package body Demos is

   function Scale (Point : in HAL.Bitmap.Point) return HAL.Bitmap.Point;

   function Scale (Point : in HAL.Bitmap.Point) return HAL.Bitmap.Point is
      pragma Warnings (Off);
   begin
      if STM32.Board.LCD_Natural_Width > 480 then
         return (Point.X * 800 / 480, Point.Y * 480 / 272);
      else
         return Point;
      end if;
   end Scale;

   --  ------------------------------
   --  Write a message on the display.
   --  ------------------------------
   procedure Put (X   : in Natural;
                  Y   : in Natural;
                  Msg : in String) is
   begin
      Bitmapped_Drawing.Draw_String (Buffer     => STM32.Board.Display.Hidden_Buffer (1).all,
                                     Start      => Scale ((X, Y)),
                                     Msg        => Msg,
                                     Font       => Current_Font,
                                     Foreground => Foreground,
                                     Background => Background);
   end Put;

   --  ------------------------------
   --  Write the 64-bit integer value on the display.
   --  ------------------------------
   procedure Put (X     : in Natural;
                  Y     : in Natural;
                  Value : in Net.Uint64) is
      Buffer : constant HAL.Bitmap.Any_Bitmap_Buffer := STM32.Board.Display.Hidden_Buffer (1);
      FG     : constant HAL.UInt32 := Bitmap_Color_Conversion.Bitmap_Color_To_Word (Buffer.Color_Mode,
                                                                                   Foreground);
      BG     : constant HAL.UInt32 := Bitmap_Color_Conversion.Bitmap_Color_To_Word (Buffer.Color_Mode,
                                                                                   Background);
      V      : constant String := Net.Uint64'Image (Value);
      Pos    : HAL.Bitmap.Point := (X + 100, Y);
      D      : Natural := 1;
   begin
      for I in reverse V'Range loop
         Bitmapped_Drawing.Draw_Char (Buffer     => Buffer.all,
                                      Start      => Scale (Pos),
                                      Char       => V (I),
                                      Font       => Current_Font,
                                      Foreground => FG,
                                      Background => BG);
         Pos.X := Pos.X - 8;
         D := D + 1;
         if D = 4 then
            D := 1;
            Pos.X := Pos.X - 4;
         end if;
      end loop;
   end Put;

   --  ------------------------------
   --  Refresh the ifnet statistics on the display.
   --  ------------------------------
   procedure Refresh_Ifnet_Stats is
      use type Net.DHCP.State_Type;
      use type Receiver.Us_Time;

      State    : constant Net.DHCP.State_Type := Dhcp.Get_State;
      Min_Time : constant Receiver.Us_Time := Receiver.Min_Receive_Time;
      Max_Time : constant Receiver.Us_Time := Receiver.Max_Receive_Time;
      Avg_Time : constant Receiver.Us_Time := Receiver.Avg_Receive_Time;
   begin
      case State is
         when Net.DHCP.STATE_BOUND | Net.DHCP.STATE_DAD
            | Net.DHCP.STATE_RENEWING | Net.DHCP.STATE_REBINDING =>
            if State = Net.DHCP.STATE_REBINDING then
               Foreground := HAL.Bitmap.Red;
            elsif State /= Net.DHCP.STATE_BOUND then
               Foreground := HAL.Bitmap.Blue;
            end if;
            Put (80, 30, Net.Utils.To_String (Ifnet.Ip));
            Put (80, 40, Net.Utils.To_String (Ifnet.Gateway));
            Put (80, 50, Net.Utils.To_String (Ifnet.Dns));

         when Net.DHCP.STATE_SELECTING =>
            Foreground := HAL.Bitmap.Blue;
            Put (80, 30, "Selecting");

         when Net.DHCP.STATE_REQUESTING =>
            Foreground := HAL.Bitmap.Blue;
            Put (80, 30, "Requesting");

         when others =>
            Foreground := HAL.Bitmap.Blue;
            Put (80, 30, "Initialize   ");
            Put (80, 40, "             ");
            Put (80, 50, "             ");

      end case;
      Foreground := HAL.Bitmap.White;
      Put (250, 30, Net.Uint64 (Ifnet.Rx_Stats.Packets));
      Put (350, 30, Ifnet.Rx_Stats.Bytes);
      Put (250, 40, Net.Uint64 (Ifnet.Tx_Stats.Packets));
      Put (350, 40, Ifnet.Tx_Stats.Bytes);
      if Min_Time < 1_000_000 and Min_Time > 0 then
         Put (250, 50, Net.Uint64 (Min_Time));
      end if;
      if Avg_Time < 1_000_000 and Avg_Time > 0 then
         Put (300, 50, Net.Uint64 (Avg_Time));
      end if;
      if Max_Time < 1_000_000 and Max_Time > 0 then
         Put (350, 50, Net.Uint64 (Max_Time));
      end if;
   end Refresh_Ifnet_Stats;

   --  ------------------------------
   --  Initialize the board and the interface.
   --  ------------------------------
   procedure Initialize (Title  : in String) is
   begin
      STM32.RNG.Interrupts.Initialize_RNG;
      STM32.Board.Display.Initialize;
      STM32.Board.Display.Initialize_Layer (1, HAL.Bitmap.ARGB_1555);

      --  Static IP interface, default netmask and no gateway.
--        Ifnet.Ip := (192, 168, 1, 2);
--        Ifnet.Gateway := (192, 168, 1, 240);
--        Ifnet.Dns := (192, 168, 1, 240);

      --  STMicroelectronics OUI = 00 81 E1
      Ifnet.Mac := (0, 16#81#, 16#E1#, 5, 5, 1);

      --  Setup some receive buffers and initialize the Ethernet driver.
      Net.Buffers.Add_Region (STM32.SDRAM.Reserve (Amount => HAL.UInt32 (NET_BUFFER_SIZE)),
                              NET_BUFFER_SIZE);
      Ifnet.Initialize;
      Receiver.Start;

      --  Initialize the DHCP client.
      Dhcp.Initialize (Ifnet'Access);
      for I in 1 .. 2 loop
         Current_Font := BMP_Fonts.Font16x24;
         Put (0, 0, Title);
         Current_Font := Default_Font;
         Put (5, 30, "IP");
         Put (4, 40, "Gateway");
         Put (4, 50, "DNS");
         Put (250, 30, "Rx");
         Put (250, 40, "Tx");
         Put (250, 50, "Rec time");
         Put (302, 14, "Packets");
         Put (418, 14, "Bytes");
--           Put (0, 70, "Host");
--           Put (326, 70, "Send");
--           Put (402, 70, "Receive");
         Header;
         STM32.Board.Display.Hidden_Buffer (1).Set_Source (HAL.Bitmap.Blue);
         STM32.Board.Display.Hidden_Buffer (1).Draw_Horizontal_Line
           (Pt    => (X => 0, Y => 84),
            Width => STM32.Board.LCD_Natural_Width);
         STM32.Board.Display.Update_Layer (1);
      end loop;
   end Initialize;

end Demos;
