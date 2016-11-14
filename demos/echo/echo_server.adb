-----------------------------------------------------------------------
--  echo_server -- A simple UDP echo server
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

package body Echo_Server is

   overriding
   procedure Receive (Endpoint : in out Echo_Server;
                      From     : in Net.Sockets.Sockaddr_In;
                      Packet   : in out Net.Buffers.Buffer_Type) is
      Status : Net.Error_Code;
   begin
      Endpoint.Count := Endpoint.Count + 1;
      Endpoint.Send (To => From, Packet => Packet, Status => Status);
   end Receive;

end Echo_Server;
