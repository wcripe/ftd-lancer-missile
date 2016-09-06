# ftd-lancer-missile
From the Depths Lua code for the Lancer missile system. Allows variable-speed missiles with extended range, with missiles conserving fuel in order to charge their target at a high rate of speed.

To use, copy the contents of lancer-control.lua into a Lua box on your vehicle and hit "Apply changes", ensure you have transceivers attached to the missile launch pad of each gantry you are using to fire Lua-controlled missiles, and add a Lua transceiver component to the missile design itself.

We highly recommend also attaching at least one ejector to the launch pad, and setting the variable speed thruster on the missile to a fairly low value, such as 200. This ensures that the missile will be able to reach a large range at a fairly reasonable (if somewhat slow) speed before it begins its terminal burn, while retaining enough fuel to make the burn worthwhile.

The code will aim to burn as much fuel as possible by the time of impact. It will also throttle back based on the amount it has to turn to impact the target, so the missile should get extra time to turn to face the target, as well as conserving fuel for the final terminal burn.

Currently, there are 4 settings.

maxTimeToTarget: This specifies a number in seconds that limits the maximum time that the target's movement will be projected for the purposes of determining guidance. If this value is too high, targets that wobble or jitter a lot will cause the missile to behave very erratically at long range, and the missile will spend far too much time and fuel maneuvering to try to keep up with the predictions. If it's too low, the missile will have trouble converging on fast targets.

distanceToCharge: Once the missile reaches this distance from the target, the Lua code will begin controlling its throttle. The intent here is to perform a terminal burn, causing the missile to rapidly accelerate to impact the target. This conserves fuel prior to the burn, while eliminating the need to constantly recalculate the throttle at long range (which is a performance-heavy task). However, this practice also assumes that the amount of fuel and base variable speed thruster settings are reasonable, so your mileage may vary. Set this to a very high number to allow the code to control the missile's thrust for longer, or a low number (500-1000) to allow for a much higher burst of terminal speed that may be good for thumper missiles. Setting this too low will be detrimental to missile performance, as the missile will not have time to accelerate fully before impact!

minGuidanceDistance: Distance in meters before guidance kicks in. This allows you to specify for some types of missiles when guidance should take over. Vertically-launched missiles may benefit from this, as otherwise the guidance may try to turn the missiles right into an adjacent conning tower or other superstructure. Set to 0 to disable this feature.

throttleUpdateTicks: The number of ticks between each throttle calculation for the missile once it's within distanceToCharge of the target. There are 40 ticks per second in From The Depths, so the default value of 20 recalculates every half second. If there are a lot of missiles in the air at any given time, a larger number may be necessary to ensure code performance.
