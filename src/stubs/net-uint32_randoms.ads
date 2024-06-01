-----------------------------------------------------------------------
--  net-utils-random -- Network utilities random operation
--  Copyright (C) 2024 Stephane Carrez
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

with Ada.Numerics.Discrete_Random;

private
package Net.Uint32_Randoms is

   function Random return Uint32;

private

   package Uint32_Random is new Ada.Numerics.Discrete_Random (Uint32);

   Generator : Uint32_Random.Generator;

   function Random return Uint32 is (Uint32_Random.Random (Generator));

end Net.Uint32_Randoms;
