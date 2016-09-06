maxTimeToTarget = 3         --  Only lead the target by this many seconds. Used to keep the missiles from trying to over-predict
                            --    a jittery target's movement at range, wasting fuel.

distanceToCharge = 1000     --  Within this distance, begin accelerating at a rate calculated to consume the last of our fuel by the time of impact.

minGuidanceDistance = 50    --  Only begin using guidance when we're at least this far from the launch vehicle.

throttleUpdateTicks = 20    --  Number of ticks between recalculating how much thrust the missile should output. Too low will cause significant lag.
                            --    Increase this value as the number of missiles in the air at any given time increases. Setting throttles is expensive!

--  End user-configurable variables. Do not edit anything below this line.


--  Available properties: .info (MissileWarningInfo object), .fuel, .thrust, .transceiver, .index, .id, .timeToThrustCalc, .hasBallast, .numThrusters
missiles = {}

tickRate = 1 / 40            --  Tick rate per second
maxMissileThrottle = 5000    --  Maximum missile throttle

--  FtD runs this function once per game tick.
function Update(I)
    missileSense(I)
    missileGuidance(I)
end

--  Detect information about missiles we've fired
function missileSense(I)
    local missileIDsSeen = {}    --  This stores the ID of each missile we see. If we don't see an ID on a given tick, we can assume that the stored
                                 --    missile no longer exists and can be removed from memory.

    local transceiverCount = I:GetLuaTransceiverCount()

    --  Iterate through each transceiver and each missile, set up variables for each missile in our data array or update as necessary.
    for transceiverIndex = 0, transceiverCount - 1 do
        local missileCount = I:GetLuaControlledMissileCount(transceiverIndex)
        local missileIndex = 0

        for missileIndex = 0, missileCount - 1 do
            local missileInfo = I:GetLuaControlledMissileInfo(transceiverIndex, missileIndex)

            --  Only try to do calculations on missiles that have data, unless you like adding nil to things
            if (missileInfo.Valid) then
                --  If this is our first iteration knowing about this missile, we'll want to calculate how much fuel it has and its default throttle
                if (missiles[missileInfo.Id] == nil) then
                    local parts = I:GetMissileInfo(transceiverIndex, missileIndex)
                    local totalFuel = 0
                    local baseThrust = 0
                    local hasBallast = false
                    local numThrusters = 0

                    --  Look through our missile parts.
                    for ix,part in pairs(parts.Parts) do
                        if (string.find(part.Name, 'fuel')) then
                            totalFuel = totalFuel + 5000
                        elseif (string.find(part.Name, 'variable')) then
                            baseThrust = baseThrust + part.Registers[2]
                            numThrusters = numThrusters + 1
                        elseif (string.find(part.Name, 'ballast')) then
                            hasBallast = true
                        end
                    end

                    --  Set up all missile variables
                    missiles[missileInfo.Id] = {}
                    missiles[missileInfo.Id].fuel = totalFuel - baseThrust
                    missiles[missileInfo.Id].thrust = baseThrust
                    missiles[missileInfo.Id].transceiver = transceiverIndex
                    missiles[missileInfo.Id].index = missileIndex
                    missiles[missileInfo.Id].id = missileInfo.Id
                    missiles[missileInfo.Id].timeToThrustCalc = throttleUpdateTicks
                    missiles[missileInfo.Id].hasBallast = hasBallast
                    missiles[missileInfo.Id].numThrusters = numThrusters
                --  If this is not the first time we've seen this missile, update its fuel counter based on its current thrust
                elseif (missiles[missileInfo.Id].fuel >= 0) then
                    missiles[missileInfo.Id].fuel = missiles[missileInfo.Id].fuel - missiles[missileInfo.Id].thrust * tickRate * missiles[missileInfo.Id].numThrusters
                end

                --  On every tick, update how long it is until we need to reconsider our throttle value, update the missile info object,
                --    and note the ID as seen this tick
                missiles[missileInfo.Id].timeToThrustCalc = missiles[missileInfo.Id].timeToThrustCalc - 1
                missiles[missileInfo.Id].info = missileInfo
                missileIDsSeen[missileInfo.Id] = true
            end
        end
    end

    --  Loop through the missiles table and remove any that we didn't update above, since that means they probably don't exist anymore.
    for id, missile in pairs(missiles) do
        if (missileIDsSeen[id] == nil) then
            table.remove(missiles, id)
        end
    end
end

--  Sets the thrust amount for the variable thruster(s) on a missile to the designated amount, then updates the missile object in our missiles table
function setThrottle(I, missile, throttle)
    local missileParts = I:GetMissileInfo(missile.transceiver, missile.index)
    if (missileParts ~= nil and missile.numThrusters > 0) then
        throttle = throttle / missile.numThrusters
        for k, v in pairs(missileParts.Parts) do
                if string.find(v.Name, 'variable') then
                    v:SendRegister(2, throttle)
                break
            end
        end

        missiles[missile.id].thrust = throttle
        missiles[missile.id].timeToThrustCalc = throttleUpdateTicks
    end
end

--  Performs missile guidance and throttle calculations
function missileGuidance(I)
    local mainframes = I:GetNumberOfMainframes()
    local position = I:GetConstructPosition()

    --  Only perform calculations when we have a valid mainframe and target
    if (mainframes > 0) then
        local targets = I:GetNumberOfTargets(0)

        if (targets > 0) then
            local transceiverCount = I:GetLuaTransceiverCount()
            local transceiverIndex = 0
            local target = I:GetTargetInfo(0, 0)

            --  Spin through all missiles to perform guidance and throttle calculations...
            for id, missile in pairs(missiles) do
                --  ...but only if we're dealing with a valid missile far enough away from the parent vehicle to begin guidance procedures
                if (missile.info.Valid and (missile.info.Position - position).magnitude > minGuidanceDistance) then

                    --  Set up variables to use for guidance and throttle calculations
                    local distToTarget = target.AimPointPosition - missile.info.Position
                    local timeToTarget = distToTarget.magnitude / math.max(missile.info.Velocity.magnitude, .000000001)
                    local angleToTarget = math.deg(math.acos(Vector3.Dot(distToTarget, missile.info.Velocity) / (distToTarget.magnitude * missile.info.Velocity.magnitude)))
                    local aimTimeToTarget = math.min(timeToTarget, maxTimeToTarget)

                    local targetAltitude = target.AimPointPosition.y + target.Velocity.y * aimTimeToTarget

                    if (missile.hasBallast == false) then
                        targetAltitude = math.max(targetAltitude, -1)
                    end


                    --  Aim at a point in front of the target based on how long it will take the missile to reach the target's current position.
                    --    Naive, but generally works out with a minimum of calculation. Only strike above-water points on the target.
                    I:SetLuaControlledMissileAimPoint(missile.transceiver, missile.index,
                        target.AimPointPosition.x + target.Velocity.x * aimTimeToTarget,
                        targetAltitude,
                        target.AimPointPosition.z + target.Velocity.z * aimTimeToTarget)

                    --  Sets acceleration speed based on angle to target, and calculates final charge
                    if (missile.timeToThrustCalc <= 0 and distToTarget.magnitude < distanceToCharge) then
                        --  Throttle up as we aim at and approach the target, based on the amount of fuel remaining
                        local boostFactor = (1 - (angleToTarget / 180.1))
                        local thrustLeft = (missile.fuel / timeToTarget)
                        setThrottle(I, missile, boostFactor * thrustLeft)
                    end
                end
            end
        end
    end
end
