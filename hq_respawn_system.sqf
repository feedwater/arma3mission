// HQ Respawn System - Independent faction only with ACE Medical support
// Teleports players to HQ on respawn and restores health

HQ_RespawnDistance = 10; // Random offset radius from flagpole

HQ_InitRespawn = {
    if (isServer) then {
        deleteMarker "respawn_guerrila";
        private _marker = createMarker ["respawn_guerrila", getPosATL flag_fob];
        _marker setMarkerType "Empty";
        _marker setMarkerAlpha 0;
        publicVariable "respawn_guerrila";
    };

    if (hasInterface) then {
        player removeAllEventHandlers "Respawn";
        player removeAllEventHandlers "Killed";

        player addEventHandler ["Killed", {
            "respawn_guerrila" setMarkerPos (getPosATL flag_fob);
        }];

        player addEventHandler ["Respawn", {
            [] spawn {
                sleep 0.1; // allow engine to finish respawn

                private _flagPos = getPosATL flag_fob;
                private _angle = random 360;
                private _dist = random HQ_RespawnDistance;
                private _respawnPos = [
                    (_flagPos select 0) + _dist * sin _angle,
                    (_flagPos select 1) + _dist * cos _angle,
                    _flagPos select 2
                ];

                _respawnPos = _respawnPos findEmptyPosition [0, 20, typeOf player];
                if (count _respawnPos == 0) then { _respawnPos = _flagPos; };

                player allowDamage false;
                player setPosATL _respawnPos;
                player setDir (random 360);
                player setVelocity [0,0,0];

                if (isClass (configFile >> "CfgPatches" >> "ace_medical")) then {
                    [player] call ace_medical_treatment_fnc_fullHealLocal;
                    player setVariable ["ace_medical_preventInstaDeath", false, true];
                } else {
                    player setDamage 0;
                    player setBleedingRemaining 0;
                    player setFatigue 0;
                    player setStamina 1;
                };

                player allowDamage true;
                hint "You have respawned at HQ Base - fully healed";
            };
        }];
    };

    call HQ_UpdateRespawnPosition;
};

HQ_UpdateRespawnPosition = {
    if (!isNil "flag_fob" && {!isNull flag_fob}) then {
        "respawn_guerrila" setMarkerPos (getPosATL flag_fob);
        "respawn_guerrila" setMarkerAlpha 0;
    } else {
        systemChat "Warning: flag_fob not found!";
    };
};

[] spawn {
    waitUntil {time > 0 && !isNil "flag_fob" && {!isNull flag_fob}};
    sleep 0.5;
    call HQ_InitRespawn;

    [] spawn {
        while {true} do {
            sleep 10;
            if (!isNil "flag_fob" && {!isNull flag_fob}) then {
                "respawn_guerrila" setMarkerPos (getPosATL flag_fob);
            };
        };
    };
};

