--[[
    FiveM Scripts
    Copyright C 2018  Sighmir

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published
    by the Free Software Foundation, either version 3 of the License, or
    at your option any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

---- TUNNEL CLIENT SIDE VERSION (https://github.com/ImagicTheCat/vRP)
-- Too bad that require doesn't exist client-side
-- TOOLS DEF
Tools = {}

-- TUNNEL DEF
Tunnel = {}

local function tunnel_resolve(itable,key)
  local mtable = getmetatable(itable)
  local iname = mtable.name
  local ids = mtable.tunnel_ids
  local callbacks = mtable.tunnel_callbacks
  local identifier = mtable.identifier

  -- generate access function
  local fcall = function(args,callback)
    if args == nil then
      args = {}
    end
    
    -- send request
    if type(callback) == "function" then -- ref callback if exists (become a request)
      local rid = ids:gen()
      callbacks[rid] = callback
      TriggerServerEvent(iname..":tunnel_req",key,args,identifier,rid)
    else -- regular trigger
      TriggerServerEvent(iname..":tunnel_req",key,args,"",-1)
    end

  end

  itable[key] = fcall -- add generated call to table (optimization)
  return fcall
end

-- bind an interface (listen to net requests)
-- name: interface name
-- interface: table containing functions
function Tunnel.bindInterface(name,interface)
  -- receive request
  RegisterNetEvent(name..":tunnel_req")
  AddEventHandler(name..":tunnel_req",function(member,args,identifier,rid)
    local f = interface[member]

    local delayed = false

    local rets = {}
    if type(f) == "function" then
      -- bind the global function to delay the return values using the returned function with args
      TUNNEL_DELAYED = function()
        delayed = true
        return function(rets)
          rets = rets or {}
          if rid >= 0 then
            TriggerServerEvent(name..":"..identifier..":tunnel_res",rid,rets)
          end
        end
      end

      rets = {f(table.unpack(args))} -- call function 
      -- CancelEvent() -- cancel event doesn't seem to cancel the event for the other handlers, but if it does, uncomment this
    end

    -- send response (event if the function doesn't exist)
    if not delayed and rid >= 0 then
      TriggerServerEvent(name..":"..identifier..":tunnel_res",rid,rets)
    end
  end)
end

-- get a tunnel interface to send requests 
-- name: interface name
-- identifier: unique string to identify this tunnel interface access (the name of the current resource should be fine)
function Tunnel.getInterface(name,identifier)
  local ids = Tools.newIDGenerator()
  local callbacks = {}

  -- build interface
  local r = setmetatable({},{ __index = tunnel_resolve, name = name, tunnel_ids = ids, tunnel_callbacks = callbacks, identifier = identifier })

  -- receive response
  RegisterNetEvent(name..":"..identifier..":tunnel_res")
  AddEventHandler(name..":"..identifier..":tunnel_res",function(rid,args)
    local callback = callbacks[rid]
    if callback ~= nil then
      -- free request id
      ids:free(rid)
      callbacks[rid] = nil

      -- call
      callback(table.unpack(args))
    end
  end)

  return r
end
---- END TUNNEL CLIENT SIDE VERSION
