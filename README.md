#lua-resty-locations

Lua library implementing nginx style 'location' uri matching.

As nginx's [location](http://nginx.org/en/docs/http/ngx_http_core_module.html#location) feature.   
Supports longest prefix matching, regex matching, case insensitive regex matching and exact matches.

* Exact matches are checked first, search returns on hit.
* Prefix matches then checked and the longest match is remembered.
 * If prefix match has `^~` modifier search returns
* Regexes are checked *in order*
* If no regex match longest prefix is returned

#Overview

```
lua_package_path "/path/to/lua-resty-locations/lib/?.lua;;";

init_by_lua_block {
        local locations = require("resty.locations")
        my_locs = locations:new()

        -- Prefix match
        local ok, err = my_locs:set("/foo", "/foo")

        -- exact match
        local ok, err = my_locs:set("/bar", "= /bar", "=")

        -- regex match
        local ok, err = my_locs:set("^/baz", "~ ^/baz", "~")

        -- case insensitive regex match
        local ok, err = my_locs:set("^/qux", "~* ^/qux", "~*")

        -- prefix match, no regex check
        local ok, err = my_locs:set("/bazfoo", "^~ /bazfoo", "^~")
}

server {
    listen 80 default_server;

    server_name locations;

    location / {
        content_by_lua_block {
            local val, err = my_locs:lookup(ngx.var.uri)
            if val then
                -- do something based on val
                ngx.say("Matched: ", val)
            else
                if err then
                    ngx.log(ngx.ERR, err)
                end
                ngx.exit(404)
            end
        }
    }
}
```

# Methods
### new
`syntax: my_locations, err = locations:new(size?)`

Creates a new instance of resty-locations with an optional initial size

### set
`syntax: ok, err = my_locations:set(key, value, modifier?)`

Adds a new key with associated value and modifier, default is an empty string for prefix match.   
Keys must be strings.   
Returns false and an error message on failure.

Modifiers are as the nginx location feature.
 * `` (empty string) - Prefix match
 * `=` - Exact match
 * `~` - Regex match
 * `~*` - Case insensitive regex match
 * `^~` - Prefix match, skip regexes

### lookup
`syntax: val, err = my_locations:lookup(uri)`

Retrieves value for provided uri.   
Returns nil and an error message on failure
