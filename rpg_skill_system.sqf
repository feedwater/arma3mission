// Basic RPG skill system with ACE integration and persistence

// Stats structure: [uid, endurance, carry, speed, accuracy, xp, points]
RPG_DEFAULT_STATS = [1,1,1,1,0,0];
RPG_MAX_LEVEL = 5;

// Server initialization: load saved stats and setup XP handler
RPG_fnc_initServer = {
    RPG_PlayerStats = profileNamespace getVariable ["RPG_PlayerStats", []];
    if (isNil "RPG_PlayerStats") then {RPG_PlayerStats = []};

    // migrate old entries lacking XP or point fields
    {
        if ((count _x) < 7) then {
            _x append [0,0];
            RPG_PlayerStats set [_forEachIndex, _x];
        };
    } forEach RPG_PlayerStats;
    [] call RPG_fnc_saveStats;

    addMissionEventHandler ["EntityKilled", {
        params ["_unit", "_killer", "_instigator"];
        if (isPlayer _instigator) then {
            [getPlayerUID _instigator, 10] call RPG_fnc_addXP;
        };
    }];
};

// Save stats to profileNamespace
RPG_fnc_saveStats = {
    profileNamespace setVariable ["RPG_PlayerStats", RPG_PlayerStats];
    saveProfileNamespace;
};

// Get entry for UID
RPG_fnc_getEntry = {
    params ["_uid"];
    {
        if ((_x select 0) isEqualTo _uid) exitWith {
            if ((count _x) < 7) then {
                _x append [0,0];
                RPG_PlayerStats set [_forEachIndex, _x];
                [] call RPG_fnc_saveStats;
            };
            _x
        };
    } forEach RPG_PlayerStats;
};

// Server: client requests stats
RPG_fnc_requestStats = {
    params ["_player", "_uid"];
    private _entry = [_uid] call RPG_fnc_getEntry;
    if (isNil "_entry") then {
        _entry = [_uid] + RPG_DEFAULT_STATS;
        RPG_PlayerStats pushBack _entry;
        [] call RPG_fnc_saveStats;
    };
    [_entry] remoteExec ["RPG_fnc_applyStats", _player];
};

// Server: add XP and award skill points
RPG_fnc_addXP = {
    params ["_uid", "_xp"];
    private _entry = [_uid] call RPG_fnc_getEntry;
    if (isNil "_entry") then {
        _entry = [_uid] + RPG_DEFAULT_STATS;
        RPG_PlayerStats pushBack _entry;
    };
    private _curXP = (_entry select 5) + _xp;
    private _points = _entry select 6;
    while {_curXP >= 100} do {
        _curXP = _curXP - 100;
        _points = _points + 1;
    };
    _entry set [5, _curXP];
    _entry set [6, _points];
    [] call RPG_fnc_saveStats;
    private _plr = [_uid] call BIS_fnc_getUnitByUID;
    if (!isNull _plr) then {
        [_entry] remoteExec ["RPG_fnc_applyStats", _plr];
    };
};

// Server: increase a skill value, spending points
RPG_fnc_increaseSkill = {
    params ["_uid", "_skillIndex"];
    private _entry = [_uid] call RPG_fnc_getEntry;
    if (isNil "_entry") then {
        _entry = [_uid] + RPG_DEFAULT_STATS;
        RPG_PlayerStats pushBack _entry;
    };
    private _points = _entry select 6;
    if (_points <= 0) exitWith {};
    private _val = (_entry select _skillIndex) + 1;
    if (_val > RPG_MAX_LEVEL) exitWith {};
    _entry set [_skillIndex, _val];
    _entry set [6, _points - 1];
    [] call RPG_fnc_saveStats;
    private _plr = [_uid] call BIS_fnc_getUnitByUID;
    if (!isNull _plr) then {
        [_entry] remoteExec ["RPG_fnc_applyStats", _plr];
    };
};

// Client: apply stats received from server
RPG_fnc_applyStats = {
    params ["_entry"];
    if (isNil "_entry" || { !(_entry isEqualType []) }) exitWith {};
    if ((count _entry) < 7) then { _entry append [0,0]; };
    private _stats = _entry select [1,4];
    private _xp = _entry select 5;
    private _points = _entry select 6;
    player setVariable ["RPG_stats", _stats];
    player setVariable ["RPG_xp", _xp];
    player setVariable ["RPG_points", _points];
    [player] call RPG_fnc_updateTraits;
};

// Apply traits to unit based on stats
RPG_fnc_updateTraits = {
    params ["_unit"];
    private _stats = _unit getVariable ["RPG_stats", RPG_DEFAULT_STATS select [0,4]];
    private _endurance = _stats select 0;
    private _carry = _stats select 1;
    private _speed = _stats select 2;
    private _accuracy = _stats select 3;

    // Damage reduction via HandleDamage event
    if (isNil {_unit getVariable "RPG_hdEH"}) then {
        _unit setVariable ["RPG_hdEH", _unit addEventHandler ["HandleDamage", {
            params ["_u", "", "_d"];
            private _st = _u getVariable ["RPG_stats", RPG_DEFAULT_STATS select [0,4]];
            private _end = _st select 0;
            private _mult = 1 - ((_end - 1) * 0.05);
            _d * _mult;
        }]];
    };

    // Carry capacity modifier
    _unit setUnitTrait ["loadCoef", 1 - ((_carry - 1) * 0.05)];

    // Movement speed modifier
    _unit setAnimSpeedCoef (1 + ((_speed - 1) * 0.05));

    // Accuracy modifier
    _unit setCustomAimCoef (1 - ((_accuracy - 1) * 0.05));
};

// Display current stats
RPG_fnc_showStats = {
    private _s = player getVariable ["RPG_stats", RPG_DEFAULT_STATS select [0,4]];
    private _xp = player getVariable ["RPG_xp", 0];
    private _pts = player getVariable ["RPG_points", 0];
    hint format [
        "Endurance: %1\nCarry: %2\nSpeed: %3\nAccuracy: %4\nXP: %5\nSkill Points: %6",
        _s select 0, _s select 1, _s select 2, _s select 3, _xp, _pts
    ];
};

// Client: request server to increase skill
RPG_fnc_increaseSkillRequest = {
    params ["_skill"];
    private _pts = player getVariable ["RPG_points", 0];
    if (_pts <= 0) exitWith { hint "No skill points available" };
    [getPlayerUID player, _skill + 1] remoteExec ["RPG_fnc_increaseSkill", 2];
};

// Client initialization
RPG_fnc_initPlayer = {
    [player, getPlayerUID player] remoteExec ["RPG_fnc_requestStats", 2];

    private _root = ["RPG_root", "RPG Skills", "", {}, {true}] call ace_interact_menu_fnc_createAction;
    [player, 1, ["ACE_SelfActions"], _root] call ace_interact_menu_fnc_addActionToObject;

    private _view = ["RPG_view", "View Skills", "", {[] call RPG_fnc_showStats}, {true}] call ace_interact_menu_fnc_createAction;
    [player, 1, ["ACE_SelfActions", "RPG_root"], _view] call ace_interact_menu_fnc_addActionToObject;

    {
        private _idx = _forEachIndex;
        private _name = _x;
        private _inc = [
            format ["RPG_inc_%1", _name],
            format ["Increase %1", _name],
            "",
            compile format ["[%1] call RPG_fnc_increaseSkillRequest", _idx],
            {true}
        ] call ace_interact_menu_fnc_createAction;
        [player, 1, ["ACE_SelfActions", "RPG_root"], _inc] call ace_interact_menu_fnc_addActionToObject;
    } forEach ["Endurance", "Carry", "Speed", "Accuracy"];
};
