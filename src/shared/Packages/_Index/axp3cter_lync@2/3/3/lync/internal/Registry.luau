--!strict
--!optimize 2

local Log = require(script.Parent.Parent.util.Log)
local Signal = require(script.Parent.Parent.api.Signal)
local Types = require(script.Parent.Parent.Types)

local KIND_PACKET = 0
local KIND_REQUEST = 1
local KIND_RESPONSE = 2

local MAX_ID = 127

local _nextId = 0
local _registrationsById: { [number]: Types.Registration } = {}
local _registrationsByName: { [string]: Types.Registration } = {}

local Registry = {}

Registry.KIND_PACKET = KIND_PACKET
Registry.KIND_REQUEST = KIND_REQUEST
Registry.KIND_RESPONSE = KIND_RESPONSE
Registry.MAX_ID = MAX_ID

export type RegisterOptions = {
	name: string,
	kind: number,
	codec: Types.InternalCodec<any>,
	isUnreliable: boolean,
	partner: number?,
	needsGate: boolean,
	headerSize: number,
	timestampMode: number,
	openFn: (ch: Types.ChannelState, id: number) -> (),
	rateLimit: Types.RateLimitConfig?,
	validate: Types.ValidateFn?,
	maxPayloadBytes: number?,
}

function Registry.register(opts: RegisterOptions): Types.Registration
	local nextCandidate = _nextId + 1
	if nextCandidate > MAX_ID then
		Log.error(`ID limit ({MAX_ID}) exceeded; cannot register "{opts.name}"`)
	end

	if opts.kind ~= KIND_RESPONSE and _registrationsByName[opts.name] ~= nil then
		Log.error(`duplicate name "{opts.name}"`)
	end

	_nextId = nextCandidate

	local reg: Types.Registration = {
		id = nextCandidate,
		name = opts.name,
		kind = opts.kind,
		codec = opts.codec,
		isUnreliable = opts.isUnreliable,
		partner = opts.partner,
		signal = Signal.create(),
		rateLimit = opts.rateLimit,
		validate = opts.validate,
		needsGate = opts.needsGate,
		maxPayloadBytes = opts.maxPayloadBytes,
		timestampMode = opts.timestampMode,
		headerSize = opts.headerSize,
		_openFn = opts.openFn,
		bytesSent = 0,
		bytesReceived = 0,
		fires = 0,
		recvFires = 0,
		drops = 0,
	}

	_registrationsById[nextCandidate] = reg
	if opts.kind ~= KIND_RESPONSE then
		_registrationsByName[opts.name] = reg
	end
	return reg
end

function Registry.get(id: number): Types.Registration?
	return _registrationsById[id]
end

function Registry.getByName(name: string): Types.Registration?
	return _registrationsByName[name]
end

function Registry.count(): number
	return _nextId
end

function Registry.all(): { Types.Registration }
	local result = table.create(_nextId)
	for i = 1, _nextId do
		result[i] = _registrationsById[i]
	end
	return result
end

function Registry.reset(): ()
	table.clear(_registrationsById)
	table.clear(_registrationsByName)
	_nextId = 0
end

return table.freeze(Registry)
