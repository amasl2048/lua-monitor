#!/usr/bin/env lua
--[[
  Weather report bot
--]]

function get_data(data, name)
    return data:match(name..": (.-)\n")
end

data = {"atmosphere", "wind", "forecast"}
params = {"humidity", "pressure", "chill", "speed", "date", "low", "high", "text"}
config = {"city", "weather_file"}

--- read config
do
   local f = assert(io.open("/etc/weather.conf", "r"))
   local c = f:read("*all")
   f:close()
   conf = {}
   for _,key in pairs(config) do
      conf[key] = get_data(c, key)
   end
end

--- get forecast
function get_url(city)
   local place = {}                                        
   place["moscow"] = "2122265"                       
   place["spb"] = "2123260"                          
   place["stockholm"]= "906057"                      
   place["nairobi"] = "1528488"          
   place["dubai"] = "1940345"
   place["barselona"] = "753692"
   local url = "'http://weather.yahooapis.com/forecastrss?w="..place[city].."&u=c\'" 
   local cmd = "curl -s "..url
   -- out = os.execute(cmd)
   -- print(out)
   local f=io.popen(cmd)
   C=f:read"*a"
   f:close()
end

get_url(conf.city)

--- parse xml
function get(data, name, par)
    temp = data:match("<yweather:"..name.."(.-)/>")
    return temp:match(par.."=\"(.-)\"")
end

function get_item(data, name)
    return data:match(name.."=\"(.-)\"")
end

weather = {}
weather[params[1]] = get(C, data[1], params[1]) -- atmosphere
weather[params[2]] = get(C, data[1], params[2])
weather[params[3]] = get(C, data[2], params[3]) -- wind 
weather[params[4]] = get(C, data[2], params[4])
weather[params[5]] = get(C, data[3], params[5]) -- forecast
weather[params[6]] = get(C, data[3], params[6])
weather[params[7]] = get(C, data[3], params[7])
weather[params[8]] = get(C, data[3], params[8])

weather.pressure = math.floor(weather.pressure * 0.75)
weather.speed = math.floor(weather.speed * 1000 / 3600)
weather["tdiff"] = weather.high - weather.low

--- make report
function report(wr)
   for _,v in pairs(params) do
      wr = wr..v..": "..weather[v].."\n"
      -- print(v, weather[v])
   end
   return wr
end

function save_weather(r, file)
      --local f = io.open("/var/weather.txt", "w")
      local f_ = io.open(file, "r")
      if f_ ~= nil then
	f_:close()
        local old_file = file.."~"
	local cmd = "cp "..file.." "..old_file
	os.execute(cmd)
      end
      local f = io.open(file, "w")
      f:write(r)
      f:close()
end

wr = ""
wr = report(wr)

--- read last file
function read_last(file)
   local f = assert(io.open(file, "r"))
   local t = f:read("*all")
   f:close()
   local last = {}
   for _,key in pairs(params) do
      last[key]= get_data(t, key)
   end
   return last
end

--- check last weather file
do
  local f = io.open(conf.weather_file, "r")
  if f ~= nil then
    f:close()
    last = read_last(conf.weather_file)
    save_weather(wr, conf.weather_file)
  else
    save_weather(wr, conf.weather_file)
    last = read_last(conf.weather_file)
  end
end

rep = ""
function high(par, max)
   if (tonumber(weather[par]) > max) then rep = rep..par.." high "..weather[par].."\n" end
end

function low(par, min)
   if (tonumber(weather[par]) < min) then rep = rep..par.." low "..weather[par].."\n" end
end

function diff(par, dt)
   local d = tonumber(weather[par] - last[par])
   if (math.abs(d) >= dt) and (d > 0) 
   	then rep = rep..par.." up to "..weather[par].." (+"..tostring(d)..")\n" end
   if (math.abs(d) >= dt) and (d < 0) 
   	then rep = rep..par.." down to "..weather[par].." ("..tostring(d)..")\n" end
end

function cond(con, txt)
   if ( string.find(weather[con], txt) ) 
   	then rep = rep..weather[con].."\n" end
end

function zero(par)
   local prev = tonumber(last[par])
   local new  = tonumber(weather[par])
   if (prev < 0) and (new > 0) 
     then rep = rep..par.." pass zero ("..last[par].."->"..weather[par]..")\n" end
   if (prev > 0) and (new < 0) 
     then rep = rep..par.." down zero ("..last[par].."->"..weather[par]..")\n" end
end

high("humidity", 90)
low("humidity", 20)

high("pressure", 765)
low("pressure", 735)
diff("pressure", 20)

low("chill", -10)
high("speed", 7)

if (weather.tdiff >= 15) 
	then rep = rep.."T_diff "..weather.tdiff.." ("..weather.low..".."..weather.high..")\n" end

if (tonumber(weather.low) < 0) and (tonumber(weather.high) > 0) 
    then rep = rep.."T pass zero".." ("..weather.low..".."..weather.high..")\n" end

zero("low")
zero("high")

diff("low", 7)
diff("high", 7)

cond("text", "Rain")
cond("text", "storm")
cond("text", "Shower")

--- print report for logger
--print(rep, "#", os.date(), "\n---\n")
--if (rep ~= "") then save_weather(rep, "report.txt") end
if (rep ~= "") then
  print(rep)
else
  print("No report")
end

--- send e-mail
local socket = require 'socket'
local smtp = require 'socket.smtp'
local ssl = require 'ssl'
local https = require 'ssl.https'
local ltn12 = require 'ltn12'

function sslCreate()
    local sock = socket.tcp()
    return setmetatable({
        connect = function(_, host, port)
            local r, e = sock:connect(host, port)
            if not r then return r, e end
            sock = ssl.wrap(sock, {mode='client', protocol='tlsv1'})
            return sock:dohandshake()
    end
   }, {
        __index = function(t,n)
            return function(_, ...)
                return sock[n](sock, ...)
            end
        end
           }) 
end
        
function sendMessage(subject, body)
   local data = {"server", "port", "user", "pass", "mailto"}
   local f = assert(io.open("/etc/yahoo.conf", "r"))
   local c = f:read("*all")
   f:close()
   local yahoo = {}
   for _,key in pairs(data) do
      yahoo[key] = get_data(c, key)
      --print(key, yahoo[key])
   end
    local msg = {
        headers = {
            to = "<"..yahoo.mailto..">",  
            subject = subject,
            date = os.date(),
            ["content-type"] = 'text/plain; charset="utf-8"',
            encoding = "8bit"
        },
        body = body
    }

    local ok, err = smtp.send {
        from = "<"..yahoo.user..">",
        rcpt = "<"..yahoo.mailto..">",
        source = smtp.message(msg),
        user = yahoo.user,
        password = yahoo.pass,
        server = yahoo.server,
        port = yahoo.port,
        create = sslCreate
    }
    if not ok then
        print("Mail send failed", err) -- better error handling required
    end
end

if (rep ~= "") then sendMessage(conf.city.." "..weather.date, rep) end

