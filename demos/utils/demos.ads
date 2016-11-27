-----------------------------------------------------------------------
--  demos -- Utility package for the demos
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
with Interfaces;
with BMP_Fonts;
with Net;
with Net.Buffers;
with Net.Interfaces;
with Net.DHCP;
package Demos is

   use type Interfaces.Unsigned_32;

   --  Reserve 256 network buffers.
   NET_BUFFER_SIZE : constant Interfaces.Unsigned_32 := Net.Buffers.NET_ALLOC_SIZE * 256;

   --  The DHCP client used by the demos.
   Dhcp    : aliased Net.DHCP.Client;

   Current_Font : BMP_Fonts.BMP_Font := BMP_Fonts.Font12x12;

   --  Write a message on the display.
   procedure Put (X   : in Natural;
                  Y   : in Natural;
                  Msg : in String);

   --  Write the 64-bit integer value on the display.
   procedure Put (X : in Natural;
                  Y : in Natural;
                  Value : in Net.Uint64);

   --  Refresh the ifnet statistics on the display.
   procedure Refresh_Ifnet_Stats (Ifnet : in Net.Interfaces.Ifnet_Type'Class);

   --  Initialize the board and the interface.
   generic
      with procedure Header;
   procedure Initialize (Title  : in String;
                         Ifnet  : in out Net.Interfaces.Ifnet_Type'Class);

end Demos;
