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
        // Remove old event handlers added by this script to prevent duplicates
        if (!isNil "HQ_Respawn_EH") then {
            player removeEventHandler ["Respawn", HQ_Respawn_EH];
        };
        if (!isNil "HQ_Killed_EH") then {
            player removeEventHandler ["Killed", HQ_Killed_EH];
        };

        // Add killed event handler to update respawn position BEFORE death
        HQ_Killed_EH = player addEventHandler ["Killed", {
            params ["_unit", "_killer"];
            
            // Update respawn marker position right before death
            private _flagPos = getPosATL flag_fob;
            "respawn_guerrila" setMarkerPos _flagPos;
            
            // Store position for backup teleport
            player setVariable ["HQ_RespawnPos", _flagPos, false];
        }];
        
        // Add respawn event handler for backup teleport and medical reset
        HQ_Respawn_EH = player addEventHandler ["Respawn", {
            params ["_unit", "_corpse"];
            
            [] spawn {
                // Very short delay to ensure spawn is complete
                sleep 0.1;
                
                // Get flag position
                private _flagPos = player getVariable ["HQ_RespawnPos", getPosATL flag_fob];
                
                // Check if player spawned at wrong location (near corpse)
                if ((player distance _flagPos) > 50) then {
                    // Force teleport to HQ
                    private _randomAngle = random 360;
                    private _randomDistance = random HQ_RespawnDistance;
                    
                    private _respawnPos = [
                        (_flagPos select 0) + (_randomDistance * sin _randomAngle),
                        (_flagPos select 1) + (_randomDistance * cos _randomAngle),
                        (_flagPos select 2)
                    ];
                    
                    // Find safe position
                    _respawnPos = _respawnPos findEmptyPosition [0, 20, typeOf player];
                    if (count _respawnPos == 0) then {
                        _respawnPos = _flagPos;
                    };
                    
                    // Teleport with damage protection
                    player allowDamage false;
                    player setPosATL _respawnPos;
                    player setDir (random 360);
                    player setVelocity [0, 0, 0];
                };
                
                // ACE Medical - Full heal
                if (isClass (configFile >> "CfgPatches" >> "ace_medical")) then {
                    // ACE3 Medical full heal - this handles everything
                    [player] call ace_medical_treatment_fnc_fullHealLocal;
                } else {
                    // Fallback for vanilla medical or other medical systems
                    player setDamage 0;
                    player setBleedingRemaining 0;
                    player setFatigue 0;
                };
                
                // Additional health resets
                player allowDamage false;
                player setDamage 0;
                player setBleedingRemaining 0;
                player setFatigue 0;
                player setStamina 1;
                
                // Clear any ongoing effects
                [] spawn {
                    sleep 1;
                    player allowDamage true;
                    hint "You have respawned at HQ Base - fully healed";
                };
                
                // Clear stored position
                player setVariable ["HQ_RespawnPos", nil, false];
            };
        }];
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
[] spawn {
    // Wait for mission start and flag to exist
    waitUntil {time > 0 && !isNil "flag_fob" && {!isNull flag_fob}};
    
    // Small delay for stability
    sleep 0.5;
    
    // Initialize respawn system
    call HQ_InitRespawn;
    
    // Periodic marker position update (in case something goes wrong)
    [] spawn {
        while {true} do {
            sleep 10;
            if (!isNil "flag_fob" && {!isNull flag_fob}) then {
                "respawn_guerrila" setMarkerPos (getPosATL flag_fob);
            };
        };
    };
};

// Debug command (run in debug console if needed)
// "respawn_guerrila" setMarkerType "hd_flag"; // Makes marker visible for testing