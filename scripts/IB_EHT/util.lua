--[[

   Copyright 2016 Iris Blanche

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.

]]

-- #########################################################################################################
-- Util definition
-- #########################################################################################################
Util = {}
Util.__index = Util
-- #########################################################################################################
-- print the table
-- #########################################################################################################
function Util:table_print (tt, indent, done)
  done = done or {}
  indent = indent or 0
  if type(tt) == "table" then
    local sb = {}
    for key, value in pairs (tt) do
      table.insert(sb, string.rep (" ", indent)) -- indent it
      if type (value) == "table" and not done [value] then
        table.insert(sb, key .. " : ")
        done [value] = true
        table.insert(sb, "{\n");
        table.insert(sb, Util:table_print (value, indent + 2, done))
        table.insert(sb, string.rep (" ", indent)) -- indent it
        table.insert(sb, "}\n");
      elseif "number" == type(key) then
        table.insert(sb, string.format("%s\n", tostring(value)))
      else
        table.insert(sb, string.format(
            "%s = \"%s\"\n", tostring (key), tostring(value)))
       end
    end
    return table.concat(sb)
  else
    return tt .. "\n"
  end
end
-- #########################################################################################################
-- to string function for converting data to readable string
-- #########################################################################################################
function Util:to_string( tbl )
    if  "nil" == type( tbl ) then
        return tostring(nil)
    elseif  "table" == type( tbl ) then
        return Util:table_print(tbl)
    elseif  "string" == type( tbl ) then
        return tbl
    else
        return tostring(tbl)
    end
end
-- #########################################################################################################
-- is value between vmin and vmax
-- #########################################################################################################
function Util:between(v,vmin,vmax)
	return v >= vmin and v <= vmax
end
-- #########################################################################################################
-- get the diff between two values
-- #########################################################################################################
function Util:diff(v1,v2)
	return math.abs( math.abs(v1) - math.abs(v2) )
end
-- #########################################################################################################
-- divide 2 values and set a minimum of v3 or a maximum of v4 and never exceed this regardless of the result!
-- #########################################################################################################
function Util:mmDiv(v1,v2,v3,v4)
	local r = v1/v2
	if r < v3 then
		r = v3
	elseif r > v4 then
		r = v4
	end
	return r
end
-- #########################################################################################################
-- enhanced detection for player
-- #########################################################################################################
function Util:EHTdetect(p1,p2)
	local i = 0
	
	for i=-2,2,1 do
		local x = world.lineCollision({ p1[1], p1[2] + i}, { p2[1] + 0.5, p2[2] + 0.5 } )
		if x == nil then
			return true
		end
	end
	return false
end
-- #########################################################################################################
-- #########################################################################################################
-- #########################################################################################################
