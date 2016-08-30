function init()
  self.energyCost = config.getParameter("energyCost", 1)
  self.healthDamage = config.getParameter("healthDamage", 1)
  script.setUpdateDelta(config.getParameter("tickRate", 1))
  effect.addStatModifierGroup({{stat = "energyRegenPercentageRate", effectiveMultiplier = 0}})
end

function update(dt)
  mcontroller.controlModifiers(self.movementModifiers)
  if (not status.overConsumeResource("energy", self.energyCost)) and self.healthDamage > 0 then
    status.applySelfDamageRequest({
        damageType = "IgnoresDef",
        damage = self.healthDamage,
        damageSourceKind = "fire",
        sourceEntityId = entity.id()
      })
  end
end

function uninit()

end
