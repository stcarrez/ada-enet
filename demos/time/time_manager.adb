-----------------------------------------------------------------------
--  time_manager -- NTP Client instance
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

with Demos;
package body Time_Manager is

   --  ------------------------------
   --  Save the answer received from the DNS server.  This operation is called for each answer
   --  found in the DNS response packet.  The Index is incremented at each answer.  For example
   --  a DNS server can return a CNAME_RR answer followed by an A_RR: the operation is called
   --  two times.
   --
   --  This operation can be overriden to implement specific actions when an answer is received.
   --  ------------------------------
   overriding
   procedure Answer (Request  : in out Client_Type;
                     Status   : in Net.DNS.Status_Type;
                     Response : in Net.DNS.Response_Type;
                     Index    : in Natural) is
      use type Net.DNS.Status_Type;
      use type Net.DNS.RR_Type;
      use type Net.Uint16;
   begin
      if Status = Net.DNS.NOERROR and then Response.Of_Type = Net.DNS.A_RR then
         Request.Server.Initialize (Demos.Ifnet'Access, Response.Ip, Request.Port);
      end if;
   end Answer;

end Time_Manager;
