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
-- additonal scripts
-- #########################################################################################################
require "/scripts/util.lua"
require "/scripts/messageutil.lua"
require "/quests/scripts/portraits.lua"
require "/scripts/IB_EHT/main.lua"
require "/scripts/IB_EHT/util.lua"

-- #########################################################################################################
-- Initialize EHT
-- #########################################################################################################
function init()
	
	-- Storage
	storage.complete = storage.complete or false
	storage.tick = storage.tick or 1

	-- Quest description
	self.descriptions = config.getParameter("descriptions")
	
	-- Quest text
	quest.setText(config.getParameter("text"))
	quest.setTitle(config.getParameter("title"))
	
	-- load data
	loadData()
	
	-- apply starter effect (will do nothing when already given)
	self.EHT:applyStarterEffect()
	
	-- set portrait
	setPortraits()
	
	-- init tracker
	quest.setObjectiveList({
		{ self.descriptions.showInfo, false }
	})
	
	sb.logInfo("EHT initialized")
end

-- #########################################################################################################
-- Uninitialize EHT
-- #########################################################################################################
function uninit()
	saveData()
end

-- #########################################################################################################
-- Load data
-- #########################################################################################################
function loadData()
	-- EHT storage load
	self.EHT = EHT.create()
	storage.EHT = storage.EHT or { lvlFlag = self.EHT.lvlFlag, offset = self.EHT.offset, hasStarterEffect = self.EHT.hasStarterEffect }
	
	-- Make sure we have the right values
	self.EHT.lvlFlag = Util:ValCheck(self.EHT.lvlFlag, storage.EHT.lvlFlag)
	self.EHT.offset = Util:ValCheck(self.EHT.offset, storage.EHT.offset)
	self.EHT.hasStarterEffect = Util:ValCheck(self.EHT.hasStarterEffect, storage.EHT.hasStarterEffect)
end

-- #########################################################################################################
-- Save data
-- #########################################################################################################
function saveData()
	storage.EHT.lvlFlag = self.EHT.lvlFlag
	storage.EHT.offset = self.EHT.offset
	storage.EHT.hasStarterEffect = self.EHT.hasStarterEffect
end

-- #########################################################################################################
-- EHT update script
-- #########################################################################################################
function update(dt)
	
	-- Temperature
	local temperature = self.EHT:CalculateTemperature()

	-- Messagetick
	if storage.tick >= config.getParameter("exposureTick") then
		self.EHT:ShowMessage(self.EHT:CalculateModifier(temperature))
		storage.tick = 1
	else
		storage.tick = storage.tick + 1
	end
	
	-- Update quest tracker for keeping the information about the actual status "up to date"
	quest.setObjectiveList({
		{"Exposure: " .. string.format("%.0f", math.modf(status.resource("exposure") - 100 )) .. "\n- Current Temp: " ..  string.format("%.1f", temperature) .. " C", false}
	})
	
	-- Debug
	sb.setLogMap("Current world type", "%s", world.type())
	
	-- Save data
	saveData()
end

-- #########################################################################################################
-- #########################################################################################################
-- #########################################################################################################
