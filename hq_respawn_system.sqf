/*
    HQ Respawn System
    -----------------
    Teleports players to the HQ flag when they respawn and heals them.

    Works with ACE medical by calling the full heal function if the mod is
    present. The system keeps the respawn marker at the flag position so that
    players respawn at HQ even if the base is relocated.
*/

// Distance from the flag where players can appear
HQ_RespawnDistance = 10;

// Create the invisible respawn marker on the server
if (isServer) then {
    deleteMarker "respawn_guerrila";

    private _m = createMarker ["respawn_guerrila", getPosATL flag_fob];
    _m setMarkerType "Empty";
    _m setMarkerAlpha 0;
};

// Add client‑side event handlers for respawn and death
if (hasInterface) then {
    // Prevent duplicates if the script is executed again
    player removeAllEventHandlers "Respawn";
    player removeAllEventHandlers "Killed";

    // Ensure the marker always matches the flag location
    player addEventHandler ["Killed", {
        "respawn_guerrila" setMarkerPos (getPosATL flag_fob);
    }];

    // Handle the actual respawn
    player addEventHandler ["Respawn", {
        params ["_unit", "_corpse"];

        _unit spawn {
            params ["_unit"];
            // Small delay to allow the engine to finish spawning the unit
            sleep 0.1;

            // Pick a random position near the flag and move the unit there
            private _flagPos = getPosATL flag_fob;
            private _angle   = random 360;
            private _dist    = random HQ_RespawnDistance;
            private _pos     = [
                (_flagPos#0) + (_dist * sin _angle),
                (_flagPos#1) + (_dist * cos _angle),
                _flagPos#2
            ];

            _pos = _pos findEmptyPosition [0,20,typeOf _unit];
            if (count _pos == 0) then {_pos = _flagPos;};

            _unit allowDamage false;
            _unit setPosATL _pos;
            _unit setDir (random 360);
            _unit setVelocity [0,0,0];

            // Heal the player. Use ACE function if it exists.
            if (!isNil "ace_medical_treatment_fnc_fullHealLocal") then {
                [_unit] call ace_medical_treatment_fnc_fullHealLocal;
            } else {
                _unit setDamage 0;
                _unit setBleedingRemaining 0;
            };

            _unit allowDamage true;
        };
    }];
};

// Keep the respawn marker positioned at the flag in case it moves
[] spawn {
    while {true} do {
        sleep 10;
        if (!isNull flag_fob) then {
            "respawn_guerrila" setMarkerPos (getPosATL flag_fob);
        };
    };
};

