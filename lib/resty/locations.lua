local str_byte    = string.byte
local str_sub     = string.sub
local str_char    = string.char
local tbl_insert  = table.insert
local ngx_re_find = ngx.re.find
local ngx_log     = ngx.log
local ngx_DEBUG   = ngx.DEBUG
local ngx_ERR     = ngx.ERR
local ngx_INFO    = ngx.INFO


local ok, tab_new = pcall(require, "table.new")
if not ok then
    tab_new = function (narr, nrec) return {} end
end

local _M = {
    _VERSION = "0.2",
}
local mt = { __index = _M }


local DEBUG = false
function _M._debug(debug)
    DEBUG = debug
end

function _M.new(_, size)
    size = size or 10
    local self = {
        trie = tab_new(0, size),
        map = tab_new(0, size),
        exact_map = tab_new(0, size),
        regexes = tab_new(0, size),
    }

    return setmetatable(self, mt)
end


local function trie_insert(trie, val, len, pos)
    pos = pos or 0
    if pos >= len then
        -- Flag this point in the tree as a complete key
        trie["fin"] = true
        return
    end
    pos = pos + 1
    if DEBUG then ngx_log(ngx_DEBUG, "Insert: '", val, "'") end

    local b = str_byte(val, pos)
    trie[b] = trie[b] or {}
    trie_insert(trie[b], val, len, pos)
end


function _M.set(self, key, val, mod)
    if not key or type(key) ~= "string" or #key == 0 then
        return nil, "invalid location, must be a string"
    end
    if mod and type(mod) ~= "string" then
        return nil, "invalid modifier"
    end

    if not mod then mod = "" end

    if mod == "=" then
        if self.exact_map[key] then
            return false, "location exists"
        end
        if DEBUG then ngx_log(ngx_DEBUG, "Adding exact match: ", key) end
        self.exact_map[key] = val
        return true
    end

    local map = self.map
    if map[key] then
        return false, "location exists"
    end

    if mod == "" or mod == "^~" then
        -- Prefix match, add to trie
        if DEBUG then ngx_log(ngx_DEBUG, "Adding prefix match: ", key) end
        trie_insert(self.trie, key, #key)
    elseif mod == "~*" or mod == "~" then
        -- regex match
        if DEBUG then ngx_log(ngx_DEBUG, "Adding regex match: ", key) end
        tbl_insert(self.regexes, key)
    else
        return nil, "invalid modifier"
    end

    -- Add to map
    map[key] = { ["mod"] = mod, ["val"] = val }

    return true
end


local function trie_walk(trie, key, ret, pos, fin)
    pos = pos or 0
    pos = pos + 1
    local b = str_byte(key, pos)

    if b and trie[b] then
        if DEBUG then ngx_log(ngx_DEBUG, "found ", b, " ", trie[b]["fin"]) end
        ret[pos] = b
        if trie[b]["fin"] then
            -- This point is a complete key in the tree
            fin = pos
        end
        return trie_walk(trie[b], key, ret, pos, fin)
    else
        return fin
    end
end


function _M.lookup(self, key)
    if not key or type(key) ~= "string" then
        return nil, "invalid key"
    end

    -- Attempt to match full string first
    local match = self.exact_map[key]
    if match then
        return match
    end

    -- Search the prefix trie
    if DEBUG then ngx_log(ngx_DEBUG, "Searching: ", key) end
    local match = {}
    local fin = trie_walk(self.trie, key, match)
    if DEBUG then ngx_log(ngx_DEBUG, "fin: ", fin) end

    if fin then
        match = str_sub(str_char(unpack(match)), 1, fin)
    else
        match = nil
    end

    local prefix_match
    local map = self.map
    if match then
        prefix_match = self.map[match]
        if DEBUG then ngx_log(ngx_DEBUG, "Longest prefix: ", match) end
    end
    if DEBUG and not prefix_match then ngx_log(ngx_DEBUG, "No prefix match") end


    -- Regex lookups, don't check if prefix match has ^~ modifier
    local regex_match
    local regex_val
    if not prefix_match or prefix_match.mod ~= "^~" then
        for _, regex in ipairs(self.regexes) do
            if DEBUG then ngx_log(ngx_DEBUG, "Checking regex: ", regex) end
            local found
            regex_val = map[regex]
            if regex_val.mod == "~*" then
                -- case insensitive match
                found = ngx_re_find(key, regex, "ioj")
            else
                found = ngx_re_find(key, regex, "oj")
            end
            if found then
                regex_match = regex
                break
            end
        end

        if regex_match then
            return regex_val.val
        end
    end
    if prefix_match then
        if DEBUG then ngx_log(ngx_DEBUG, "Returning prefix match") end
        return prefix_match.val
    end
end

return _M
