local map, data = ...

local rng = data.rng
local room_rng = rng:create()


bit32 = bit32 or bit

local Class = require 'lib/class.lua'
local Util = require 'lib/util'
local List = require 'lib/list'
local zentropy = require 'lib/zentropy'

local messages = {}
function data_messages(prefix, data)
    if type(data) == 'table' then
        local n = 0
        for key, value in Util.pairs_by_keys(data) do
            data_messages(prefix .. '.' .. key, value)
            n = n + 1
        end
        if n == 0 then
            table.insert(messages, prefix .. ' = {}')
        end
    elseif type(data) ~= 'function' then
        table.insert(messages, prefix .. ' = ' .. data)
    end
end
data_messages('data', data)

local room = zentropy.Room:new{rng=rng:create(), map=map, data_messages=data_messages}

local DialogBox = Class:new()

function DialogBox:on_started()
    self.lines = {}
    local y = 0
    for _, text in ipairs(self.text) do
        local line = sol.text_surface.create{
            text=text,
            vertical_alignment="top",
        }
        line:set_xy(0, y)
        local width, height = line:get_size()
        y = y + height
        table.insert(self.lines, line)
    end
    self.game:set_hud_enabled(false)
    self.game:get_hero():freeze()
end

function DialogBox:on_finished()
    self.game:set_hud_enabled(true)
    self.game:get_hero():unfreeze()
end

function DialogBox:on_command_pressed(command)
    if command == 'action' then
        sol.menu.stop(self)
    end
    return true
end

function DialogBox:on_draw(dst_surface)
    for _, line in ipairs(self.lines) do
        line:draw(dst_surface)
    end
end


function is_special_room(data)
    for dir, door in pairs(data.doors) do
        if door.open == 'entrance' or door.open == 'bigkey' then
            return true
        end
    end
end



local obstacle_mask = 0
local walls = {}
for _, dir in pairs{'north','south','east','west'} do
    if data.doors[dir] then
        room:door({open=data.doors[dir].open, name=data.doors[dir].name}, dir)
        if not data.doors[dir].open and data.doors[dir].reach ~= 'bomb' then
            room.open_doors[dir] = true
        end
        if data.doors[dir].reach then
            obstacle_item = data.doors[dir].reach
        end
    else
        table.insert(walls, dir)
    end
end

local obstacle_dir = nil
if data.doors.north and data.doors.north.reach then
    obstacle_dir = (obstacle_dir or '') .. 'north'
end
if data.doors.south and data.doors.south.reach then
    obstacle_dir = (obstacle_dir or '') .. 'south'
end
if data.doors.east and data.doors.east.reach then
    obstacle_dir = (obstacle_dir or '') .. 'east'
end
if data.doors.west and data.doors.west.reach then
    obstacle_dir = (obstacle_dir or '') .. 'west'
end

for _, dir in ipairs(walls) do
    if room_rng:random(2) == 2 then
        map:get_entity('crack_' .. dir):set_enabled(true)
    end
end



local obstacle_treasure = nil
local normal_treasures = {}
for _, treasure_data in ipairs(data.treasures) do
    if treasure_data.reach then
        obstacle_treasure = treasure_data
    else
        table.insert(normal_treasures, treasure_data)
    end
end

if obstacle_treasure and obstacle_mask == 0 then
    obstacle_dir = walls[room_rng:random(#walls)]
    obstacle_item = obstacle_treasure.reach
end

if obstacle_dir then

    local obstacle_data = {}

    obstacle_data.treasure1 = obstacle_treasure
    obstacle_data.treasure2 = table.remove(normal_treasures)

    room:obstacle(obstacle_data, obstacle_dir, obstacle_item)
end

for _, treasure_data in ipairs(normal_treasures) do
    room:treasure(treasure_data)
end

for _, enemy_data in ipairs(data.enemies) do
    room:enemy(enemy_data)
end

if #messages > 0 then
     --room:sign({menu=DialogBox:new{text=messages, game=map:get_game()}})
end

if not is_special_room(data) then
    local sections = {'111', '700', '444', '007', '100', '400', '004', '001'}
    List.shuffle(rng:create(), sections)
    repeat until not room:filler()
end
