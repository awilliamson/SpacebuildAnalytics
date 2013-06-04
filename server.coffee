restify = require 'restify'
mongoose = require 'mongoose'
bigInt = require 'big-integer'

mongoose.connection.on 'error', (err) ->
	console.log err

mongo = require './config.coffee'

Schema = mongoose.Schema

userSchema = new Schema (
	profile_id: { type: String, trim: true, required: true, index: { unique: true, dropDups: true }, match: /^[0-9]/ }
	steam_id: { type: String, trim: true, required: true, index: { unique: true, dropDups: true }, match: /^STEAM_[0-5]:[01]:\d+$/ }
	nick: { type: String, trim: true, required: true }
	os: { type: String, trim: true, required: true, enum: 'Windows Linux Mac'.split ' ' }
	resolution: { type: [ Number ] },
	date: { type: Date, default: Date.now },
	hidden: { type: Boolean, default: false }
)

User = mongoose.model 'User', userSchema

server = restify.createServer {
	name: 'Spacebuild Statistical Server',
	version: '0.0.1'
}
server.use restify.acceptParser(server.acceptable)
server.use restify.queryParser()
server.use restify.dateParser()
server.use restify.bodyParser()
server.use restify.throttle(
	burst: 100
	rate: 50
	ip: true # throttle based on source ip address
)

profToId = (profile_id) ->
	v = bigInt '76561197960265728'
	profile_id = bigInt profile_id

	if profile_id.isOdd()
		y = 1
	else
		y = 0

	steam_x = 0
	steam_y = y
	steam_z = profile_id.minus(y).minus(v).divide(2)

	return 'STEAM_'+steam_x+':'+steam_y+':'+steam_z

idToProf = (steam_id) ->
	V = bigInt '76561197960265728'

	terms = steam_id.split(':')

	Z = bigInt terms[2]
	Y = bigInt terms[1]
	X = bigInt terms[0].slice(-1)

	console.log Z.times(2).plus(Y).plus(V).toString()

	return Z.times(2).plus(Y).plus(V).toString()

save = (model, errcallback, callback) ->
	mongoose.connect mongo.host, mongo.db, mongo.port, {user: mongo.user, pass: mongo.pass}
	console.log model
	model.save ( err ) ->
		mongoose.disconnect()
		errcallback err if err
		callback()

server.get '/convert', (req, res, next) ->
	if req.query? and ( req.query['steam_id'] or req.query['profile_id'] )
		if req.query['steam_id']
			result = idToProf req.query['steam_id']
		else
			result = profToId req.query['profile_id']

		res.send 200, result
		next()
	else
		res.send 500
		next()

server.get '/user/:profile_id', (req, res, next) ->
	# Connect
	mongoose.connect mongo.host, mongo.db, mongo.port, {user: mongo.user, pass: mongo.pass}
	User.findOne { 'profile_id': req.params.profile_id }, (err, user) ->
		mongoose.disconnect()
		( res.send 500; ( console.log err.errors if err.errors ) console.log err; return handleError err ) if err
		res.send 200,user if user?
		res.send 500,'Cannot find specified user with id' if not user?
		next()

server.post '/user/:profile_id', (req, res, next) ->
	mongoose.connect mongo.host, mongo.db, mongo.port, {user: mongo.user, pass: mongo.pass}
	User.findOne { 'profile_id': req.params.profile_id }, (err, user) ->
		mongoose.disconnect()
		( res.send 500; ( console.log err.errors if err.errors ); console.log err; return handleError err ) if err
		console.log req.params
		if user?
			delete req.params['profile_id'] # Remove the profileID from req.params as it's not part of the update (better not be)

			for k of req.params

				if k is "resolution"
					console.log "K: ",k," ; Now split: ", req.params[k].split(',')
					user[k] = req.params[k].split(',')

				else
					user[k] = req.params[k]

			user.validate (err) ->
				( res.send 500; ( console.log err.errors if err.errors ); return handleError err ) if err # Validation error
				
				save( user, (arr) ->
					( res.send 500, arr; ( console.log arr.errors if arr.errors ); next(); return handleError arr ) if arr # Save error, eg. Already exists
				,() ->
					res.send 200, ["User updated",user]
					next()
				)

		res.send 500,'Cannot find specified user with id' if not user?	
		next()


server.get '/user', (req, res, next) ->
	mongoose.connect mongo.host, mongo.db, mongo.port, {user: mongo.user, pass: mongo.pass}
	User.find req.query or {}, (err, results) ->
		mongoose.disconnect()
		return handleError err if err
		res.send 200, results if results?
		next()

typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

postNewUser = ( req, res, next, v ) -> 
	newUser = new User v;
	newUser.validate (err) ->
		( res.send 500, err; ( console.log err.errors if err.errors ); return handleError err ) if err # Validation error
		save( newUser, ( arr ) -> #Err callback
			( res.send 500, arr; ( console.log arr if arr.errors ); return handleError arr ) if arr # Save error, eg. Already exists
		,() -> #Do something callback
			# Send client a 201 resource created message as we got no errors
			res.send 201, newUser
			next()
		)

server.post '/user', (req, res, next) ->

	console.log req.params
	console.log req.headers['user-agent']
	console.log req.headers['content-type']

	# Check if the request is from GMod, so valve http and content-type as url encoded
	if req.headers['user-agent'] is "Valve/Steam HTTP Client 1.0" and req.headers['content-type'] is "application/x-www-form-urlencoded"
		req.params['profile_id'] = req.params['profile_id'].replace(/(^")|("$)/g, "").trim() #Magical stuff, replace trailing and leading " with nothing, and trim spaces from them as well
		postNewUser req, res, next, req.params

	else #Normal request treat it as such

		if (typeIsArray req.params) and req.params.length >= 0
			for k,v of req.params
				postNewUser req, res, next, v

		else
			postNewUser req, res, next, req.params

server.listen 8080, () ->
	console.log '%s listening at %s', server.name, server.url