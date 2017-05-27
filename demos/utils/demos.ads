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
with Interfaces;
with BMP_Fonts;
with STM32.Board;
with HAL.Bitmap;
with Net;
with Net.Buffers;
with Net.Interfaces;
with Net.Interfaces.STM32;
with Net.DHCP;
package Demos is

   use type Interfaces.Unsigned_32;

   --  Reserve 256 network buffers.
   NET_BUFFER_SIZE : constant Net.Uint32 := Net.Buffers.NET_ALLOC_SIZE * 256;

   --  The Ethernet interface driver.
   Ifnet     : aliased Net.Interfaces.STM32.STM32_Ifnet;

   --  The DHCP client used by the demos.
   Dhcp      : aliased Net.DHCP.Client;

   Current_Font : BMP_Fonts.BMP_Font := BMP_Fonts.Font12x12;
   Foreground   : HAL.Bitmap.Bitmap_Color := HAL.Bitmap.White;
   Background   : HAL.Bitmap.Bitmap_Color := HAL.Bitmap.Black;

   --  Write a message on the display.
   procedure Put (X   : in Natural;
                  Y   : in Natural;
                  Msg : in String);

   --  Write the 64-bit integer value on the display.
   procedure Put (X : in Natural;
                  Y : in Natural;
                  Value : in Net.Uint64);

   --  Refresh the ifnet statistics on the display.
   procedure Refresh_Ifnet_Stats;

   --  Initialize the board and the interface.
   generic
      with procedure Header;
   procedure Initialize (Title  : in String);

   pragma Warnings (Off);

   --  Get the default font size according to the display size.
   function Default_Font return BMP_Fonts.BMP_Font is
     (if STM32.Board.LCD_Natural_Width > 480 then BMP_Fonts.Font12x12 else BMP_Fonts.Font8x8);

end Demos;
