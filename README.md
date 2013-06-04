# Spacebuild 4.0 Analytics


This is the server-side node application for Spacebuild 4.0's new User Analytics. This will form the REST API Layer, and will use [mongoose](https://github.com/LearnBoost/mongoose) library for connecting to the local MongoDB server. The REST functionality is provided by [restify](https://github.com/mcavage/node-restify). If you wish to run this, you will also need have installed [coffeescript](https://npmjs.org/package/coffee-script).

Big thanks to [big-integer](https://npmjs.org/package/big-integer), I know there are many big int style libraries out there, but I found this the easiest to implement and use. Big-Integer is used to handle the conversion between `STEAM_ID` and `PROFILE_ID` as the 'constant' used for the formula is too long to be stored natively by js.

See `package.json` for a list of dependencies as well as versions

## Installation & Usage
First ensure all the correct packages are installed which server depends upon.
```
npm install
```
This will check the `package.json` file for dependencies and install the appropriate versions specified.


To run the server without compiling, execute the following within the install directory:
```
coffee ./server.coffee
```

or you can compile the `.coffee`:
```
coffee -c ./server.coffee
```
and run the compiled JS with `node ./server.js`



#### Config.coffee
server.coffee requires a `./config.coffee` file which will serve as access to the mongoDB server.

Below is an example of such file:
```coffee
module.exports = {
	'host': domain.com',
	'port': '27017', # This is the standard mongoDB port
	'user': 'username', # Username of your defined user
	'pass': 'password',
	'db': 'database'
    #db is the database which your users collection will be established on.
    #It must also have the specified user configured and authorized for readWrite roles.
}
```

## Notes

This is by no means a fully implemented REST solution, its purpose is to serve as a means for clients to send information via HTTP to the server, and interact with the database in a safe.

This is a typical example of what a query against the database will return for a single user.   
```lua
{
      "steam_id":"STEAM_0:1:20447854",
      "profile_id":"76561198001161437",
      "nick":"Radon",
      "os":"Windows",
      "_id":"51a7c76fd5df3ad415000001",
      "__v":0,"hidden":false,
      "date":"2013-05-30T21:41:03.378Z",
      "resolution":[1600,900]
}
```
The preferred content-type is `application/json` for those making requests from within browser or from command-line.
However GMod will only encode as `x-www-form-urlencoded` and as such, information sent in this way must be constructed slightly different than the one-to-one style of JSON.

The function used on clients from within GMod is as follows:
```lua
local function getMe()
	-- Encode resolution as a string, delimited by a comma ','
        -- The server will split this into the 2 number values required.
	return {
		steam_id = LocalPlayer():SteamID(), -- A string, it will send " and delimit them.
                -- Resulting message ' \"msg\" '
		nick = LocalPlayer():GetName(), -- Same as above
		os = getOS(), -- os is an enumerated string, accepting only "Windows","Linux", or "Mac
		resolution = ScrW()..","..ScrH() -- x,y will be delimited by the API Layer, with commas.
	}
end
```

## HTTP Methods
__GET__ and __POST__ may be executed on `/user`:

*  __GET:__ Will return all users in the collection, __WARNING:__ This currently has no limit set
*  __POST:__ `[ JSON Obj ]` Will add all Objs within the array, even if it's just a single user.

__GET__ and __POST__ may also be executed on `/user/PROFILE_ID`:

*  __GET:__ Will return the user associated with the `PROFILE_ID` or will return 500, and `'Cannot find specified user with id'`
*  __POST:__ Will update the user associated with the `PROFILE_ID`. If the user is not found it will return 500, and `'Cannot find specified user with id'`. If the post data is not valid, according to Schema rules, then it will also return 500.

__GET__ may also be executed on `/convert`:

* __GET:__ If you call GET with ?profile_id or ?steam_id appended to the url as a query, you will receive the converted form of what you entered. Eg:  ```
'http://domain.com/convert?steam_id=STEAM_0:1:20447854'
  ``` Would return `'76561198001161437'` in the body aswell as a 200 OK response.

  and, likewise with profile_id:

  ```
  'http://domain.com/convert?profile_id=76561198001161437'
  ``` Would return `'STEAM_0:1:20447854'` in the body aswell as an 200 OK response.



