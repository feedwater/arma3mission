// HQ Local Movement System - allows moving components within radius of flagpole

// Define functions first
HQ_InitLocalMovement = {
    // Add movement actions to each movable object
    {
        private _object = _x;
        private _objectName = "";
        
        // Get friendly names for objects
        switch (true) do {
            case (_object == garage_fob): { _objectName = "Vehicle Garage"; };
            case (_object == arsenal_fob): { _objectName = "Arsenal Crates"; };
            case (_object == clipboard_fob): { _objectName = "Command Post"; };
            default { _objectName = "HQ Component"; };
        };
        
        // Remove existing reposition actions by checking action text
        private _actions = actionIDs _object;
        {
            private _actionText = _object actionParams _x select 0;
            if (_actionText find "Reposition" != -1) then {
                _object removeAction _x;
            };
        } forEach _actions;
        
        // Add movement action
        _object addAction [
            format ["<t color='#FFD700'>Reposition %1</t>", _objectName],
            {
                params ["_target", "_caller", "_actionId", "_arguments"];
                [_target] call HQ_StartLocalMovement;
            },
            [],
            1.4,
            true,
            true,
            "",
            "true",
            3
        ];
    } forEach HQ_MovableObjects;
};

HQ_StartLocalMovement = {
    params ["_object"];
    
    private _objectName = "";
    switch (true) do {
        case (_object == garage_fob): { _objectName = "Vehicle Garage"; };
        case (_object == arsenal_fob): { _objectName = "Arsenal Crates"; };
        case (_object == clipboard_fob): { _objectName = "Command Post"; };
        default { _objectName = "HQ Component"; };
    };
    
    // Get player's position and direction
    private _playerPos = getPosATL player;
    private _playerDir = getDir player;
    
    // Calculate position 3 meters in front of player
    private _newPos = _playerPos vectorAdd [
        3 * sin(_playerDir),
        3 * cos(_playerDir),
        0
    ];
    
    // Check if position is within radius of flagpole
    private _flagPos = getPosATL flag_fob;
    private _distance = _newPos distance2D _flagPos;
    
    if (_distance <= HQ_MaxRadius) then {
        // Move object to position in front of player
        _object setPosATL _newPos;
        _object setDir (_playerDir + 180); // Face the player
        
        // Re-initialize any special functions for moved object
        if (_object == clipboard_fob) then {
            call HQ_InitLocalMovement; // Refresh clipboard actions
        };
        if (_object == arsenal_fob) then {
            [_object, true] call ace_arsenal_fnc_initBox; // Refresh arsenal
        };
        
        hint format ["%1 moved in front of you!", _objectName];
        playSound3D ["A3\Sounds_F\arsenal\sfx\arsenal_window_close.wss", player, false, getPosATL player, 1, 1, 0];
    } else {
        hint format ["Cannot move %1 here - too far from flagpole!\nMaximum distance: %2m\nThis position would be: %3m away", _objectName, HQ_MaxRadius, round _distance];
        playSound3D ["A3\Sounds_F\sfx\UI\vehicles\vehicle_repair.wss", player, false, getPosATL player, 0.5, 2, 0];
    };
};

// Configuration
HQ_MaxRadius = 50; // Maximum distance from flagpole in meters
HQ_MovableObjects = [garage_fob, arsenal_fob, clipboard_fob]; // Objects that can be moved (excluding flagpole)

// Initialize local movement system after everything is defined
call HQ_InitLocalMovement;