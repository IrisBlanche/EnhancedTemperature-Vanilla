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
-- additional scripts needed
-- #########################################################################################################
require "/scripts/IB_EHT/util.lua"

-- #########################################################################################################
-- set old update (oupdate)
-- #########################################################################################################
oupdate = update

-- #########################################################################################################
-- update behaviour
-- #########################################################################################################
function update(dt)
	-- Call old update if present
	Util:safe_call(oupdate, dt)
	
	-- get config values
	local ehtdata = object.getConfigParameter("ehtdata", nil)
	
	if ehtdata ~= nil then
		-- provide warmth based on animation state by config
		object.setConfigParameter("provideWarmth", (animator.animationState(ehtdata.state) == ehtdata.value) )
	end
end

-- #########################################################################################################
-- #########################################################################################################
-- #########################################################################################################
