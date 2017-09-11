--飞机大战
local Class = require "lualib.class"
local Skynet = require "lualib.local_skynet"
local Env = import "scene/env"
local TimerObj = import "lualib/object"
local FrameMgr = import "scene/frame_mgr"
local SceneApi = import "scene/api"
local Net = import "lualib/net"

FWPlayer = Class("FWPlayer")

function FWPlayer:init(oGame, mArgs)
    self.m_Name = mArgs.name
    self.m_Pid = mArgs.pid
    self.m_Fd = mArgs.fd
    self.m_Color = mArgs.color
    self.m_GameObj = oGame
    self.m_Pos = {x = math.random(1,800), z = math.random(550,600)}
end

function FWPlayer:release()
    self.m_GameObj = nil
end

FighterWar = Class("FighterWar", "TimerObject")
FighterWar.m_GameModeID = GAME_FIGHTER_WAR

function FighterWar:init(game_id, mArgs)
    TimerObj.TimerObject.init(self)
    self.m_GameID = game_id
    Env.AddGameObj(self.m_GameID, self)
    self.m_FrameMgr = FrameMgr.NewFrameMgr(self)
    self.m_Players = {}
    self.m_RndSeed = math.random(1,10000)
    self.m_FrameMgr:start()
end

function FighterWar:release()
    Env.DelGameObj(self.m_GameID)
    self.m_FrameMgr:release()
    self.m_FrameMgr = nil
end

function FighterWar:add_player(pid, mArgs)
    if not self.m_FSMInitTime then
        self.m_FSMInitTime = Skynet.now()
    end
    local oPlayer = FWPlayer:new(self, mArgs)
    self.m_Players[pid] = oPlayer
    local param = {
        game_id = self.m_GameID,
        rndseed = self.m_RndSeed,
        timestamp = Skynet.now(),
        init_time = self.m_FSMInitTime,
        frame_cache = self.m_FrameMgr:frame_cache(),
    }
    self:Send2Player(pid, "gs2c_loginsuc", param)
    local ctrl_data = {
        pid = pid,
        action = ACTION_ENTER,
        enter_info = {
            name = oPlayer.m_Name,
            color = oPlayer.m_Color,
            pos = oPlayer.m_Pos,
        },
    }
    self.m_FrameMgr:push_frame(ctrl_data)
end

function FighterWar:del_player(pid)
    local oPlayer = self.m_Players[pid]
    if oPlayer then
        self.m_Players[pid] = nil
        local ctrl_data = {
            pid = pid,
            action = ACTION_LEAVE,
        }
        self.m_FrameMgr:push_frame(ctrl_data)
        oPlayer:release()
    end
end

function FighterWar:get_player(pid)
    return self.m_Players[pid]
end

function FighterWar:sync_ctrl(pid, param)
   local oPlayer = self.m_Players[pid]
   if oPlayer then
        self.m_FrameMgr:push_frame(param.ctrl_data)
   end
end

function FighterWar:Send2Player(pid, proto, param)
    Net.send_to_player(pid, proto, param, self:get_bc())
end

function FighterWar:BC2Players(proto, param, except_tbl)
    except_tbl = except_tbl or {}
    local sendlist = {}
    for pid in pairs(self.m_Players) do
        if not except_tbl[pid] then
            table.insert(sendlist, pid)
        end
    end
    Net.send_to_list(sendlist, proto, param, self:get_bc())
end

function FighterWar:get_bc()
    return SceneApi.get_scene_broadcast(self.m_GameID)
end

function NewGame(game_id, mArgs)
    return FighterWar:new(game_id, mArgs)
end