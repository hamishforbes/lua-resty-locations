use Test::Nginx::Socket;
use Cwd qw(cwd);

plan tests => repeat_each() * (blocks() * 3);

my $pwd = cwd();

$ENV{TEST_LEDGE_REDIS_DATABASE} ||= 1;

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
};

no_long_string();
run_tests();

__DATA__
=== TEST 1: Module loads in init_by_lua
--- http_config eval
"$::HttpConfig"
. q{
    init_by_lua_block {
        local locations = require("resty.locations")
        local my_locs, err = locations:new()
        local ok, err = my_locs:set("/location_a", "/location_a prefix match")
    }
}
--- config
    location /a {
        content_by_lua_block {
            ngx.say("OK")
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
OK

=== TEST 2: Exact match
--- http_config eval
"$::HttpConfig"
. q{

}
--- config
    location /a {
        content_by_lua_block {
            local locations = require("resty.locations")
            local my_locs, err = locations:new()
            local ok, err = my_locs:set("/location_a", "/location_a exact match", "=")

            local val = my_locs:lookup("/location_a")
            ngx.say(val)

            local val = my_locs:lookup("/location_a/123")
            ngx.say(val)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
/location_a exact match
nil

=== TEST 3: Prefix match
--- http_config eval
"$::HttpConfig"
. q{

}
--- config
    location /a {
        content_by_lua_block {
            local locations = require("resty.locations")
            local my_locs, err = locations:new()
            local ok, err = my_locs:set("/location_a", "/location_a prefix match")

            local val = my_locs:lookup("/location_a/123")
            ngx.say(val)

            local val = my_locs:lookup("/location_a")
            ngx.say(val)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
/location_a prefix match
/location_a prefix match

=== TEST 4: Regex match
--- http_config eval
"$::HttpConfig"
. q{

}
--- config
    location /a {
        content_by_lua_block {
            local locations = require("resty.locations")
            local my_locs, err = locations:new()
            local ok, err = my_locs:set("^/location_a", "^/location_a regex match", "~")

            local val = my_locs:lookup("/location_a")
            ngx.say(val)

            local val = my_locs:lookup("/location_A")
            ngx.say(val)

            local val = my_locs:lookup("/location_a/123")
            ngx.say(val)

            local val = my_locs:lookup("/123/location_a")
            ngx.say(val)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
^/location_a regex match
nil
^/location_a regex match
nil

=== TEST 5: Regex match, case insensitive
--- http_config eval
"$::HttpConfig"
. q{

}
--- config
    location /a {
        content_by_lua_block {
            local locations = require("resty.locations")
            local my_locs, err = locations:new()
            local ok, err = my_locs:set("^/location_a", "^/location_a insensitive regex match", "~*")

            local val = my_locs:lookup("/location_a")
            ngx.say(val)

            local val = my_locs:lookup("/LOCATION_a/123")
            ngx.say(val)

            local val = my_locs:lookup("/123/LOCATion_a")
            ngx.say(val)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
^/location_a insensitive regex match
^/location_a insensitive regex match
nil

=== TEST 6: Prefix match, no regex check
--- http_config eval
"$::HttpConfig"
. q{

}
--- config
    location /a {
        content_by_lua_block {
            local locations = require("resty.locations")
            local my_locs, err = locations:new()

            local ok, err = my_locs:set("^/location_a", "^/location_a regex match", "~")

            local ok, err = my_locs:set("/location_a", "/location_a prefix match", "^~")

            local val = my_locs:lookup("/location_a")
            ngx.say(val)

            local val = my_locs:lookup("/location_a/123")
            ngx.say(val)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
/location_a prefix match
/location_a prefix match

=== TEST 7: Regex matches prefered over prefix match
--- http_config eval
"$::HttpConfig"
. q{

}
--- config
    location /a {
        content_by_lua_block {
            local locations = require("resty.locations")
            local my_locs, err = locations:new()

            local ok, err = my_locs:set("^/location_a", "^/location_a regex match", "~")

            local ok, err = my_locs:set("/location_a", "/location_a prefix match")

            local val = my_locs:lookup("/location_a")
            ngx.say(val)

            local val = my_locs:lookup("/location_a/123")
            ngx.say(val)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
^/location_a regex match
^/location_a regex match

=== TEST 8: Prefix matches remembered with regex matches
--- http_config eval
"$::HttpConfig"
. q{

}
--- config
    location /a {
        content_by_lua_block {
            local locations = require("resty.locations")
            local my_locs, err = locations:new()

            local ok, err = my_locs:set("^/location_b", "^/location_b regex match", "~")

            local ok, err = my_locs:set("/location_a", "/location_a prefix match")

            local val = my_locs:lookup("/location_a")
            ngx.say(val)

        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
/location_a prefix match

=== TEST 9: Exact matches prefered
--- http_config eval
"$::HttpConfig"
. q{

}
--- config
    location /a {
        content_by_lua_block {
            local locations = require("resty.locations")
            local my_locs, err = locations:new()

            local ok, err = my_locs:set("^/location_a", "^/location_a regex match", "~")
            local ok, err = my_locs:set("/location_a", "/location_a prefix match")
            local ok, err = my_locs:set("/location_a", "/location_a exact match", "=")

            local val = my_locs:lookup("/location_a")
            ngx.say(val)

        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
/location_a exact match

=== TEST 10: Longest prefix prefered
--- http_config eval
"$::HttpConfig"
. q{

}
--- config
    location /a {
        content_by_lua_block {
            local locations = require("resty.locations")
            local my_locs, err = locations:new()

            local ok, err = my_locs:set("/location_a", "/location_a prefix match")
            local ok, err = my_locs:set("/location_a/123", "/location_a/123 prefix match")

            local val = my_locs:lookup("/location_a/123/456")
            ngx.say(val)

        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
/location_a/123 prefix match

=== TEST 11: Duplicate entries rejected
--- http_config eval
"$::HttpConfig"
. q{

}
--- config
    location /a {
        content_by_lua_block {
            local locations = require("resty.locations")
            local my_locs, err = locations:new()

            local ok, err = my_locs:set("/location_a", "/location_a prefix match")
            local ok, err = my_locs:set("/location_a", "/location_a rejected")
            if not ok then
                ngx.say(err)
            else
                ngx.say("/location_a added twice!")
            end


            local ok, err = my_locs:set("/location_b", "/location_b exact match", "=")
            local ok, err = my_locs:set("/location_b", "/location_b rejected", "=")
            if not ok then
                ngx.say(err)
            else
                ngx.say("/location_b added twice!")
            end

            local ok, err = my_locs:set("^/location_c", "^/location_c regex match", "~")
            local ok, err = my_locs:set("^/location_c", "^/location_c rejected", "~")
            if not ok then
                ngx.say(err)
            else
                ngx.say("/location_c added twice!")
            end
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
location exists
location exists
location exists

=== TEST 12: Only non-zero length strings accepted
--- http_config eval
"$::HttpConfig"
. q{

}
--- config
    location /a {
        content_by_lua_block {
            local locations = require("resty.locations")
            local my_locs, err = locations:new()

            local ok, err = my_locs:set({}, "table key")
            if not ok then
                ngx.say(err)
            end
            local ok, err = my_locs:set(1234, "numeric key")
            if not ok then
                ngx.say(err)
            end
            local ok, err = my_locs:set(function() return "foo" end, "function key")
            if not ok then
                ngx.say(err)
            end
            local ok, err = my_locs:set("", "empty string key")
            if not ok then
                ngx.say(err)
            end

        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
invalid location, must be a string
invalid location, must be a string
invalid location, must be a string
invalid location, must be a string

=== TEST 13: Regex match order matters
--- http_config eval
"$::HttpConfig"
. q{

}
--- config
    location /a {
        content_by_lua_block {
            local locations = require("resty.locations")
            local my_locs, err = locations:new()

            local ok, err = my_locs:set("^/location_a/1", "^/location_a/1 regex match", "~")
            local ok, err = my_locs:set("^/location_a", "^/location_a regex match", "~")


            local val = my_locs:lookup("/location_a")
            ngx.say(val)

            local val = my_locs:lookup("/location_a/123")
            ngx.say(val)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
^/location_a regex match
^/location_a/1 regex match
