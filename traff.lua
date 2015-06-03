#!/usr/bin/env lua
--[[
  Count traffic and report via email
--]]

local os = require 'os'
local eth = "eth0.1"

function get_data(data, name)
    return data:match(name..": (.-)\n")
end

function get_uptime(data)
   return tonumber(data:match("up (.-) day"))
end

function round(val, decimal)
  local exp = decimal and 10^decimal or 1
  return math.ceil(val * exp - 0.5) / exp
end

local data = {"in_bytes",  "out_bytes", 
              "week_in",   "week_out",
              "month_in",  "month_out",
              "totaly_in", "totaly_out",
              "utime",     "date",
              "uptime"
}
local info = {} -- current (new) data
local diff = {} 
local rep = "" -- text report
local dat_file = "./traffic.yml"

--- read data from yaml
do
   local f = assert(io.open(dat_file, "r"))
   local c = f:read("*all")
   f:close()
   conf = {}
   for _,key in pairs(data) do
      conf[key] = tonumber(get_data(c, key))
   end
end

--- make report
function report(dict, keys)
   local r = ""
   for _,v in pairs(keys) do
      r = r..v..": "..tostring(dict[v]).."\n"
   end
   return r
end

function save_info(file, dict, list)
    local f_ = io.open(file, "r")
    if f_ ~= nil then
	    f_:close()
        local old_file = file.."~"
	    local cmd = "cp "..file.." "..old_file
	    os.execute(cmd)
    end
    local f = io.open(file, "w")
    f:write(report(dict, list))
    f:close()
end

---info["lasttime"] = os.time()
---print( report(conf, data) )

---[[
do
  local cmd = "ifconfig "..eth
   local f = io.popen(cmd)
   C = f:read"*a"
   f:close()
end
--]]

do
  local cmd = "uptime"
   local f = io.popen(cmd)
   diff["uptime"] = f:read"*a"
   f:close()
end

---C = "RX bytes:324055142 (124.0 MB)  TX bytes:200924492 (90.9 MB)"
info.in_bytes  = tonumber(C:match("RX bytes:(.-) ")) 
info.out_bytes = tonumber(C:match("TX bytes:(.-) "))
info.date = os.date()
info.utime = os.time()

function round2mb(c)
   return round( c / 1024. / 1024., 1 )
end

if (info.in_bytes > conf.in_bytes) then
   diff.in_bytes  = info.in_bytes  - conf.in_bytes 
else
   diff.in_bytes  = info.in_bytes
end

if (info.out_bytes > conf.out_bytes) then
   diff.out_bytes = info.out_bytes - conf.out_bytes
else
   diff.out_bytes = info.out_bytes
end

info.week_in   = conf.week_in   + diff.in_bytes
info.week_out  = conf.week_out  + diff.out_bytes
info.month_in  = conf.month_in  + diff.in_bytes
info.month_out = conf.month_out + diff.out_bytes

info.uptime = get_uptime(diff["uptime"])

if (info.uptime >= conf.uptime) then
  info.totaly_in  = conf.totaly_in  + diff.in_bytes
  info.totaly_out = conf.totaly_out + diff.out_bytes
else
  info.totaly_in  = diff.in_bytes
  info.totaly_out = diff.out_bytes
end


---local rep = report(diff, data)
local rep = "in/out Mb \n"..
		   "daily:   "..round2mb(diff.in_bytes).."/"..round2mb(diff.out_bytes).."\n"
rep = rep.."weekly:  "..round2mb(info.week_in).."/"..round2mb(info.week_out).."\n"
rep = rep.."monthly: "..round2mb(info.month_in).."/"..round2mb(info.month_out).."\n"
rep = rep.."totaly:  "..round2mb(info.totaly_in).."/"..round2mb(info.totaly_out).."\n"
rep = rep..diff["uptime"]
---print(rep)

week = os.date("%w")
day  = os.date("%d")

if (week == "0") then
   info.week_in  = 0
   info.week_out = 0
end

if (day == "01") then
   info.month_in  = 0
   info.month_out = 0
end

save_info(dat_file, info, data)


---
dofile("send2email.lua")
---rep = ""
if (rep ~= "") then sendMessage("net1", rep) end