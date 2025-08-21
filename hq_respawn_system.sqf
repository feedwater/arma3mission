// HQ Respawn System - Independent faction only with ACE Medical support
// Makes players respawn at the HQ location with full health

// Configuration
HQ_RespawnDistance = 10; // Distance from flagpole to spawn (random within this radius)

// Define functions
HQ_InitRespawn = {
    // Create respawn marker for Independent (guerrila spelling is correct for Arma)
    if (isServer) then {
        // Delete any existing respawn marker
        deleteMarker "respawn_guerrila";
        
        // Create new respawn marker at flag position
        private _marker = createMarker ["respawn_guerrila", getPosATL flag_fob];
        _marker setMarkerType "Empty";
        _marker setMarkerSize [0, 0];
        _marker setMarkerAlpha 0;
        
        publicVariable "respawn_guerrila"; // Sync to all clients
    };

 // Client-side respawn handler
    if (hasInterface) then {
        // Add killed event handler to update respawn position BEFORE death
        ["Killed", {
            params ["_unit", "_killer"];

            private _flagPos = getPosATL flag_fob;
            "respawn_guerrila" setMarkerPos _flagPos;
            player setVariable ["HQ_RespawnPos", _flagPos, false];
        }] call CBA_fnc_addPlayerEventHandler;

        // Add respawn event handler for backup teleport and medical reset
        ["Respawn", {
            params ["_unit", "_corpse"];

            [] spawn {
                sleep 0.1;

                private _flagPos = player getVariable ["HQ_RespawnPos", getPosATL flag_fob];

                if ((player distance _flagPos) > 50) then {
                    private _randomAngle = random 360;
                    private _randomDistance = random HQ_RespawnDistance;

                    private _respawnPos = [
                        (_flagPos select 0) + (_randomDistance * sin _randomAngle),
                        (_flagPos select 1) + (_randomDistance * cos _randomAngle),
                        (_flagPos select 2)
                    ];

                    _respawnPos = _respawnPos findEmptyPosition [0, 20, typeOf player];
                    if (count _respawnPos == 0) then {
                        _respawnPos = _flagPos;
                    };

                    player allowDamage false;
                    player setPosATL _respawnPos;
                    player setDir (random 360);
                    player setVelocity [0, 0, 0];
                };

                // Heal the player after respawn
                if (!isNil "ace_medical_treatment_fnc_fullHealLocal") then {
                    // Use ACE medical if available
                    [player] call ace_medical_treatment_fnc_fullHealLocal;
                    // Make sure the unit is conscious again
                    [player, false] call ace_medical_fnc_setUnconscious;
                } else {
                    // Vanilla fallback
                    player setDamage 0;
                    player setBleedingRemaining 0;
                    player setFatigue 0;
                };

                player allowDamage false;
                player setDamage 0;
                player setBleedingRemaining 0;
                player setFatigue 0;
                player setStamina 1;

                [] spawn {
                    sleep 1;
                    player allowDamage true;
                    hint "You have respawned at HQ Base - fully healed";
                };

                player setVariable ["HQ_RespawnPos", nil, false];
            };
        }] call CBA_fnc_addPlayerEventHandler;
    };
    
    // Update marker position initially
    call HQ_UpdateRespawnPosition;
};

HQ_UpdateRespawnPosition = {
    if (!isNil "flag_fob" && {!isNull flag_fob}) then {
        private _flagPos = getPosATL flag_fob;
        "respawn_guerrila" setMarkerPos _flagPos;
        "respawn_guerrila" setMarkerAlpha 0; // Keep invisible
    } else {
        systemChat "Warning: flag_fob not found!";
    };
};

// Initialize the system
[
    {
        [{ call HQ_InitRespawn; }, [], 0.5] call CBA_fnc_waitAndExecute;

        [
            {
                if (!isNil "flag_fob" && {!isNull flag_fob}) then {
                    "respawn_guerrila" setMarkerPos (getPosATL flag_fob);
                };
            },
            [],
            10
        ] call CBA_fnc_addPerFrameHandler;
    },
    [],
    { time > 0 && !isNil "flag_fob" && {!isNull flag_fob} }
] call CBA_fnc_waitUntilAndExecute;
