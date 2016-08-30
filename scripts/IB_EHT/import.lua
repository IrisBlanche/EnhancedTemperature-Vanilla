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
-- Adding for compatibility reasons
-- #########################################################################################################
function init()
end
-- #########################################################################################################
-- Adding for compatibility reasons
-- #########################################################################################################
function uninit()
end
-- #########################################################################################################
-- The EHT import magic
-- #########################################################################################################
function activate(fireMode, shiftHeld)
	if world.getProperty("eht.biome", nil) == nil and fireMode == "primary" then
		world.sendEntityMessage( activeItem.ownerEntityId(), "checkEHT", { biome = config.getParameter("EHTBiome"), success = true, item = item.descriptor() })
	else
		world.sendEntityMessage( activeItem.ownerEntityId(), "checkEHT", { biome = config.getParameter("EHTBiome"), success = false, item = item.descriptor() })
	end
end
-- #########################################################################################################
-- #########################################################################################################
-- #########################################################################################################
