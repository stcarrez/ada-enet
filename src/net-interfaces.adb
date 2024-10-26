-----------------------------------------------------------------------
--  net-interfaces -- Network interface
--  Copyright (C) 2016-2024 Stephane Carrez
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

package body Net.Interfaces is

   --  ------------------------------
   --  Check if the IP address is a broadcast IP address.
   --  ------------------------------
   function Is_Broadcast (Ifnet : in Ifnet_Type'Class;
                          Ip    : in Ip_Addr) return Boolean
   is

      Subnet_Broadcast : constant Ip_Addr :=
        (Ifnet.Ip (1) or not Ifnet.Netmask (1),
         Ifnet.Ip (2) or not Ifnet.Netmask (2),
         Ifnet.Ip (3) or not Ifnet.Netmask (3),
         Ifnet.Ip (4) or not Ifnet.Netmask (4));
   begin
      return Ip in (255, 255, 255, 255) | Subnet_Broadcast;
   end Is_Broadcast;

   --  ------------------------------
   --  Check if the IP address is in the same subnet as the interface IP address.
   --  ------------------------------
   function Is_Local_Network (Ifnet : in Ifnet_Type'Class;
                              Ip    : in Ip_Addr) return Boolean is
   begin
      for I in Ip'Range loop
         if (Ifnet.Netmask (I) and Ip (I)) /= (Ifnet.Netmask (I) and Ifnet.Ip (I)) then
            return False;
         end if;
      end loop;
      return True;
   end Is_Local_Network;

end Net.Interfaces;
