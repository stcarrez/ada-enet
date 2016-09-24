-----------------------------------------------------------------------
--  net-headers -- Network headers
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
package body Net.Headers is

   --  ------------------------------
   --  Convert integers to network byte order.
   --  ------------------------------
   function To_Network (Val : in Uint32) return Uint32 is
   begin
      return Val;
   end To_Network;

   function To_Network (Val : in Uint16) return Uint16 is
   begin
      return Interfaces.Rotate_Left (Val, 8);
   end To_Network;

   --  ------------------------------
   --  Convert integers to host byte order.
   --  ------------------------------
   function To_Host (Val : in Uint32) return Uint32 is
   begin
      return Val;
   end To_Host;

   function To_Host (Val : in Uint16) return Uint16 is
   begin
      return Interfaces.Rotate_Left (Val, 8);
   end To_Host;

end Net.Headers;
