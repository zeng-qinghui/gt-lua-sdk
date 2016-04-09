--
-- Created by IntelliJ IDEA.
-- User: henry
-- Date: 16-4-8
-- Time: 下午1:18
-- To change this template use File | Settings | File Templates.
--


local _M = {}
_M.GT_SDK_VERSION = 'lua_0.1'
_M.connectTimeout = 1
_M.socketTimeout = 1


local function md5(s)
    local t = io.popen("echo -n '" .. s .. "' | md5sum")
    local r = t:read(32)
    t:close()
    return r
end

local function split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    local i=1
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        t[i] = str
        i = i + 1
    end
    return t
end

local function request(url, postdata)
    local t
    if postdata then
        local url_args_chuck = {}
        for key,value in pairs(postdata) do
            table.insert(url_args_chuck, key..'='..value)
        end
        t = io.popen("curl --connect-timeout " .. _M.connectTimeout .. " --max-time " .. _M.socketTimeout .. " -s -X POST '" .. url .. "' -d '" .. table.concat(url_args_chuck,'&') .. "'")
    else
        t = io.popen("curl --connect-timeout " .. _M.connectTimeout .. " --max-time " .. _M.socketTimeout .. " -s '" .. url .. "'")
    end
    local r = t:read("*all")
    t:close()
    return r
end

local function decodeRandBase(challenge)
    local base = string.sub(challenge, 33, 34)
    return tonumber(base, 36)
end

local function json_encode(t)
    local json_chuck = {}
    for key, value in pairs(t) do
        if type(value) == 'string' then
            table.insert(json_chuck, '"' .. key .. '":"' .. value .. '"')
        else
            table.insert(json_chuck, '"' .. key .. '":' .. tostring(value))
        end
    end
    return '{' .. table.concat(json_chuck, ',') .. '}'
end

local response
local captcha_id
local private_key

function _M.init(_captcha_id, _private_key)
    captcha_id = _captcha_id
    private_key = _private_key
end

local function success_process(challenge)
    response = {
        offline=false,
        gt=captcha_id,
        challenge=md5(challenge .. private_key)
    }
end

local function failback_process()
    local rnd1 = md5(math.random(0,10000))
    local rnd2 = md5(math.random(0,10000))
    local challenge = rnd1 .. string.sub(rnd2, 1, 2)
    response = {
        offline=true,
        gt=captcha_id,
        challenge=challenge
    }
end

local function check_validate(challenge, validate)
    if string.len(validate) ~= 32 then
        return false
    end

    if md5(private_key..'geetest'..challenge) ~= validate then
        return false
    end

    return true
end

local function decode_response(challenge, str)
    if str == nil then
        return 0
    end

    if string.len(str) > 100 then
        return false
    end
    local key = {}
    local seed = {1,2,5,10,50}
    local count = 0
    local res = 0

    local challenge_len = string.len(challenge)
    local value_len = string.len(str)

    for i=1,challenge_len do
        local item = string.sub(challenge, i, i)
        if not key[item] then
            local value = seed[count % 5 + 1]
            count = count + 1
            key[item] = value
        end
    end
    for i=1,value_len do
        if key[string.sub(str, i,i)] then
            res = res + key[string.sub(str, i,i)]
        end
    end
    return res - decodeRandBase(challenge)
end

function _M.pre_process(...)
    local user_id = ...
    local url = "http://api.geetest.com/register.php?gt=" .. captcha_id

    if user_id then
        url = url .. "&user_id=" .. user_id
    end

    local challenge = request(url)

    if string.len(challenge) ~= 32 then
        failback_process()
        return false
    end
    success_process(challenge)
    return true
end

function _M.get_response_str(config)
    if config ~= nil then
        for key, value in pairs(response) do
            config[key] = value
        end
    else
        config = response
    end
    return json_encode(config)
end

function _M.get_response()
    return response
end

function _M.success_validate(...)
    local challenge, validate, seccode, user_id = ...
    if not check_validate(challenge, validate) then
        return false
    end
    local data = {
        seccode=seccode,
        sdk=_M.GT_SDK_VERSION
    }

    if user_id then
        data['user_id'] = user_id
    end

    local url = "http://api.geetest.com/validate.php"
    local codevalidate = request(url, data)

    if codevalidate == md5(seccode) then
        return true
    else
        return false
    end
end

local function get_x_pos_from_str(x_str)
    if string.len(x_str) ~= 5 then
        return 0
    end

    local x_pos_sup = 200
    local sum_val = tonumber(x_str, 16)
    local result = sum_val % x_pos_sup
    if result < 40 then
        return 40
    else
        return result
    end
end

local function get_failback_pic_ans(full_bg_index, img_grp_index)
    local full_bg_name = string.sub(md5(full_bg_index), 1, 9)
    local bg_name = string.sub(md5(img_grp_index), 11, 19)

    local answer_decode = {}
    for i=5,9 do
        if i % 2 == 1 then
            table.insert(answer_decode, string.sub(full_bg_name,i,i))
        else
            table.insert(answer_decode, string.sub(bg_name,i,i))
        end
    end
    return get_x_pos_from_str(table.concat(answer_decode))
end

function _M.fail_validate(challenge, validate, seccode)
    if validate then
        local value = split(validate, '_')
        local ans = decode_response(challenge, value[1])
        local bg_idx = decode_response(challenge, value[2])
        local grp_idx = decode_response(challenge, value[3])
        local x_pos = get_failback_pic_ans(bg_idx, grp_idx)
        local answer = math.abs(ans - x_pos)

        if answer < 4 then
            return true
        else
            return false
        end
    else
        return false
    end
end

return _M
