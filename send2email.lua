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
