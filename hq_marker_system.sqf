// MP-Compatible HQ Map Marker System
// Handles marker synchronization across all clients

// Configuration
HQ_MARKER_NAME = "marker_fob";
HQ_FLAG_OBJECT = flag_fob;
HQ_UPDATE_INTERVAL = 5; // seconds

// Initialize marker function (SERVER ONLY)
HQ_InitMarker = {
    // Check if flagpole exists
    if (isNull HQ_FLAG_OBJECT) exitWith {
        diag_log "HQ Marker System: Warning - flag_fob object not found!";
        false
    };
    
    // Create the HQ marker if it doesn't exist
    if (getMarkerType HQ_MARKER_NAME == "") then {
        createMarker [HQ_MARKER_NAME, getPosATL HQ_FLAG_OBJECT];
        HQ_MARKER_NAME setMarkerType "flag_FIA";
        HQ_MARKER_NAME setMarkerText "HQ Base";
        HQ_MARKER_NAME setMarkerColor "ColorIndependent";
        HQ_MARKER_NAME setMarkerSize [1, 1];
        diag_log "HQ Marker System: Marker created successfully";
    } else {
        // Update existing marker position
        HQ_MARKER_NAME setMarkerPos (getPosATL HQ_FLAG_OBJECT);
        diag_log "HQ Marker System: Existing marker updated";
    };
    
    // Ensure marker is global (visible to all clients)
    publicVariable "HQ_MARKER_NAME";
    true
};

// Update marker position function (SERVER ONLY)
HQ_UpdateMarker = {
    // Check if flagpole still exists
    if (isNull HQ_FLAG_OBJECT) exitWith {
        diag_log "HQ Marker System: Warning - flagpole no longer exists!";
        false
    };
    
    // Update marker position to match flagpole
    if (getMarkerType HQ_MARKER_NAME != "") then {
        private _newPos = getPosATL HQ_FLAG_OBJECT;
        private _oldPos = getMarkerPos HQ_MARKER_NAME;
        
        // Only update if position actually changed (reduces network traffic)
        if (_newPos distance2D _oldPos > 0.1) then {
            HQ_MARKER_NAME setMarkerPos _newPos;
            
            // Broadcast marker update to all clients
            [HQ_MARKER_NAME, _newPos] remoteExec ["HQ_ClientUpdateMarker", 0];
            
            diag_log format ["HQ Marker System: Marker moved from %1 to %2", _oldPos, _newPos];
        };
    };
    true
};

// Client-side marker update function (ALL CLIENTS)
HQ_ClientUpdateMarker = {
    params ["_markerName", "_newPos"];
    
    if (getMarkerType _markerName != "") then {
        _markerName setMarkerPos _newPos;
    } else {
        // If marker doesn't exist on client, create it
        createMarker [_markerName, _newPos];
        _markerName setMarkerType "flag_FIA";
        _markerName setMarkerText "HQ Base";
        _markerName setMarkerColor "ColorIndependent";
        _markerName setMarkerSize [1, 1];
    };
};

// Cleanup function
HQ_CleanupMarker = {
    if (isServer) then {
        if (getMarkerType HQ_MARKER_NAME != "") then {
            deleteMarker HQ_MARKER_NAME;
            // Broadcast deletion to all clients
            [HQ_MARKER_NAME] remoteExec ["deleteMarker", 0];
            diag_log "HQ Marker System: Marker cleaned up";
        };
    };
};

// Start automatic update loop (SERVER ONLY)
HQ_StartUpdateLoop = {
    HQ_UpdateHandle = [
        {
            params ["_args", "_id"];
            if (!isNull HQ_FLAG_OBJECT && getMarkerType HQ_MARKER_NAME != "") then {
                call HQ_UpdateMarker;
            } else {
                [_id] call CBA_fnc_removePerFrameHandler;
                diag_log "HQ Marker System: Update loop terminated";
            };
        },
        HQ_UPDATE_INTERVAL
    ] call CBA_fnc_addPerFrameHandler;
};

// Initialize the system
if (isServer) then {
    // Server creates and manages the marker
    if (call HQ_InitMarker) then {
        call HQ_StartUpdateLoop;
        diag_log "HQ Marker System: Server initialization complete";
        
        // Send initial marker data to all clients
        [HQ_MARKER_NAME, getPosATL HQ_FLAG_OBJECT] remoteExec ["HQ_ClientUpdateMarker", 0];
    } else {
        diag_log "HQ Marker System: Server initialization failed";
    };
} else {
    // Clients wait for server data
    diag_log "HQ Marker System: Client ready for marker updates";
};

// Handle player JIP (Join In Progress)
if (hasInterface) then {
    [
        {
            [
                {
                    if (getMarkerType HQ_MARKER_NAME == "") then {
                        [clientOwner] remoteExec ["HQ_SendMarkerToClient", 2];
                    };
                },
                [],
                2
            ] call CBA_fnc_waitAndExecute;
        },
        [],
        { !isNull player && time > 1 }
    ] call CBA_fnc_waitUntilAndExecute;
};

// Server function to send marker data to specific client
HQ_SendMarkerToClient = {
    params ["_clientId"];
    
    if (isServer && getMarkerType HQ_MARKER_NAME != "") then {
        private _pos = getMarkerPos HQ_MARKER_NAME;
        [HQ_MARKER_NAME, _pos] remoteExec ["HQ_ClientUpdateMarker", _clientId];
        diag_log format ["HQ Marker System: Sent marker data to client %1", _clientId];
    };
};

