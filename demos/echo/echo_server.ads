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

with Net.Sockets.Udp;
with Net.Buffers;
package Echo_Server is

   type Message is record
      Id      : Natural := 0;
      Content : String (1 .. 80) := (others => ' ');
   end record;
   type Message_List is array (1 .. 10) of Message;

   --  Logger that saves the message received by the echo UDP socket.
   protected type Logger is

      procedure Echo (Content : in Message);

      function Get return Message_List;
   private
      Id   : Natural := 0;
      List : Message_List;
   end Logger;

   type Echo_Server is new Net.Sockets.Udp.Socket with record
      Count    : Natural := 0;
      Messages : Logger;
   end record;

   overriding
   procedure Receive (Endpoint : in out Echo_Server;
                      From     : in Net.Sockets.Sockaddr_In;
                      Packet   : in out Net.Buffers.Buffer_Type);

   Server : aliased Echo_Server;

end Echo_Server;
