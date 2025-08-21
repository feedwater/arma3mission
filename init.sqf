// Define functions first
HQ_Init = {
    // Setup ACE Arsenal if available
    if (isClass (configFile >> "CfgPatches" >> "ace_arsenal")) then {
        [arsenal_fob, true] call ace_arsenal_fnc_initBox;
    };
    
    // Remove only HQ relocation actions from clipboard to prevent duplicates
    // Use a flag to track if we've already added the HQ relocation action
    if (isNil "clipboard_hqRelocateAction_added") then {
        clipboard_hqRelocateAction_added = true;
        
        // Add relocation action to clipboard
        clipboard_fob addAction [
            "<t color='#00FF00'>Relocate HQ Base</t>",
            {call HQ_RelocateMenu},
            [],
            1.5,
            true,
            true,
            "",
            "true",
            3
        ];
    };
};

HQ_RelocateMenu = {
    openMap true;
    hint "Select new HQ location on the map";
    
    onMapSingleClick {
        params ["_pos"];
        [_pos] call HQ_Relocate;
        onMapSingleClick {};
        openMap false;
    };
};

HQ_Relocate = {
    params ["_newPos"];
    
    // Move all HQ objects maintaining relative positions and orientation
    {
        _x setPosATL (_newPos vectorAdd (HQ_OriginalPositions select _forEachIndex));
        _x setDir (getDir flag_fob); // Maintain orientation
    } forEach HQ_Objects;
    
    // Re-initialize systems
    call HQ_Init;
    
    // Re-initialize local movement system if it exists
    if (!isNil "HQ_InitLocalMovement") then {
        call HQ_InitLocalMovement;
    };
    
    // Update respawn position if respawn system exists
    if (!isNil "HQ_UpdateRespawnPosition") then {
        call HQ_UpdateRespawnPosition;
    };
    
    // Update HQ marker position if marker system exists
    if (!isNil "HQ_UpdateMarker") then {
        call HQ_UpdateMarker;
    };
    
    hint "HQ Base relocated successfully!";
    playSound3D ["A3\Sounds_F\arsenal\weapons\Pistols\Pistol_heavy_01_Closure_01.wss", player, false, getPosATL player, 1, 1, 0];
};

// HQ Objects Array - only physical objects that need to move
HQ_Objects = [garage_fob, arsenal_fob, clipboard_fob, flag_fob];

// Store original relative positions (using flag as reference point)
HQ_OriginalPositions = [];
{
    HQ_OriginalPositions pushBack (getPosATL _x vectorDiff getPosATL flag_fob);
} forEach HQ_Objects;

// Initialize HQ after everything is defined
call HQ_Init;

// Execute additional HQ systems
execVM "hq_local_movement.sqf";
execVM "hq_respawn_system.sqf";
execVM "hq_marker_system.sqf";

if (hasInterface) then {
    [
        { [] call RPG_fnc_initPlayer; },
        [],
        { !isNull player && alive player && {!isNil "ace_interact_menu_fnc_createAction"} }
    ] call CBA_fnc_waitUntilAndExecute;
};
