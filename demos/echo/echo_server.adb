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

   protected body Logger is

      procedure Echo (Content : in Message) is
      begin
         Id := Id + 1;
         if Id <= List'Last then
            List (Id).Id := Id;
            List (Id).Content := Content.Content;
         else
            List (1 .. List'Last - 1) := List (2 .. List'Last);
            List (List'Last).Id := Id;
            List (List'Last).Content := Content.Content;
         end if;
      end Echo;

      function Get return Message_List is
      begin
         return List;
      end Get;

   end Logger;

   overriding
   procedure Receive (Endpoint : in out Echo_Server;
                      From     : in Net.Sockets.Sockaddr_In;
                      Packet   : in out Net.Buffers.Buffer_Type) is
      use type Net.Uint16;

      Size   : constant Net.Uint16 := Packet.Get_Data_Size (Net.Buffers.UDP_PACKET);
      Status : Net.Error_Code;
      Msg    : Message;
      Len    : constant Natural
        := (if Size > Msg.Content'Length then Msg.Content'Length else Natural (Size));
   begin
      Packet.Get_String (Msg.Content (1 .. Len));
      Packet.Set_Data_Size (Size);
      Endpoint.Count := Endpoint.Count + 1;
      Endpoint.Messages.Echo (Msg);
      Endpoint.Send (To => From, Packet => Packet, Status => Status);
   end Receive;

end Echo_Server;
