# gt-lua-sdk

## 测试
CentOS 7 x64 or Ubuntu 14.04 的 Lua 5.1 下测试通过

## 依赖
* Lua
* curl
* md5sum

为了尽量避免依赖问题，所以在sdk中调用了系统的curl和md5sum


## 获取代码

```shell
git clone https://github.com/zengohm/gt-lua-sdk.git
```

## 引用SDK
```lua
require "geetest"
```

## API
* init(captcha_id, private_key) 构造函数
    - captcha_id  验证码ID
    - private_key 验证码KEY

* pre_process(user_id=nil) 预处理接口 返回true为在线模式，false为离线模式
    - user_id 用户ID
    - @return bool

* get_response_str(extend_config={}) 获取预处理结果的接口，返回JSON
    - extend_config 扩展配置, 详见[官方文档](http://www.geetest.com/install/sections/idx-client-sdk.html#config-para)
    - @return string
    
* success_validate(challenge, validate, seccode, user_id=nil) 极验服务器状态正常的二次验证接口
    - challenge  前端提交的 geetest_challenge
    - validate  前端提交的 geetest_validate
    - seccode  前端提交的 geetest_seccode
    - user_id	用户ID
    - @return bool

* fail_validate(challenge, validate, seccode) 极验服务器状态宕机的二次验证接口
    - challenge  前端提交的 geetest_challenge
    - validate  前端提交的 geetest_validate
    - seccode  前端提交的 geetest_seccode
    - @return bool

    
## 代码示例

### 初始化验证参数
```lua
local gtsdk = require("geetest")
gtsdk.init(CAPTCHA_ID, PRIVATE_KEY)
session['gtserver'] = gtsdk.pre_process(session['user_id'])

ngx.say(gtsdk.get_response_str())

```

### 验证提交
```lua
local gtsdk = require("geetest")
gtsdk.init(CAPTCHA_ID, PRIVATE_KEY)

local args
if ngx.req.get_method() == 'POST' then
    args = ngx.req.get_post_args()
else
    args = ngx.req.get_uri_args()
end
        
if session['gtserver'] then
    if gtsdk.success_validate(args['geetest_challenge'],args['geetest_validate'],args['geetest_seccode'], session['user_id']) then
        ngx.say('YES')
    else
        ngx.say('NO')
    end
else
    if gtsdk.fail_validate(args['geetest_challenge'],args['geetest_validate'],args['geetest_seccode']) then
        ngx.say('yes')
    else
        ngx.say('no')
    end
end
```