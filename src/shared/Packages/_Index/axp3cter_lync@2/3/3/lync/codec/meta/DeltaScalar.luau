--!strict
--!native

local Base = require(script.Parent.Parent.Base)
local Baseline = require(script.Parent.Parent.Parent.internal.Baseline)
local Log = require(script.Parent.Parent.Parent.util.Log)
local Quantize = require(script.Parent.Parent.Parent.util.Quantize)
local Quat = require(script.Parent.Parent.Parent.util.Quat)
local Shared = require(script.Parent.Parent.composite.Shared)
local Types = require(script.Parent.Parent.Parent.Types)
local Varint = require(script.Parent.Parent.primitive.Varint)
local Zint = require(script.Parent.Parent.primitive.Zint)

local I32_MIN = -0x80000000
local I32_MAX = 0x7FFFFFFF

local CF_X = 0x01
local CF_Y = 0x02
local CF_Z = 0x04
local CF_ROT = 0x08
local CF_ALL = 0x0F

local ensure = Base.ensure
local allocDeltaId = Shared.allocDeltaId
local floor = math.floor
local clamp = math.clamp
local round = math.round
local band = bit32.band
local bor = bit32.bor
local readu8 = buffer.readu8
local writeu8 = buffer.writeu8
local readu32 = buffer.readu32
local writeu32 = buffer.writeu32
local bufLen = buffer.len
local varintWrite = Varint.write
local varintRead = Varint.read
local zigzagEncode = Zint.encode
local zigzagDecode = Zint.decode
local quatPack = Quat.pack
local quatUnpack = Quat.unpack
local quatFromCFrame = Quat.fromCFrame

local function quantizeVec3(v: Vector3, min: number, delta: number, scale: number): (number, number, number)
	return round(clamp(v.X - min, 0, delta) * scale),
		round(clamp(v.Y - min, 0, delta) * scale),
		round(clamp(v.Z - min, 0, delta) * scale)
end

local function validateVec3(v: Vector3, min: number, max: number, label: string): ()
	if v.X < min or v.X > max or v.Y < min or v.Y > max or v.Z < min or v.Z > max then
		Log.error(`{label} ({v.X}, {v.Y}, {v.Z}) has component out of range [{min}, {max}]`)
	end
end

local function getScalarPrev(ch: Types.ChannelState, id: number, fallback: number): number
	local cache = ch.deltas[id] :: any
	return if cache then cache.scalar :: number else fallback
end

local function setScalarCache(ch: Types.ChannelState, id: number, value: number): ()
	local cache = ch.deltas[id] :: any
	if cache then
		cache.scalar = value
	else
		ch.deltas[id] = { scalar = value } :: any
	end
end

local DeltaScalar = {}

function DeltaScalar.deltaInt(min: number, max: number): Types.InternalCodec<number>
	if min > max then
		Log.error(`min ({min}) must be <= max ({max})`)
	end
	if floor(min) ~= min or floor(max) ~= max then
		Log.error("bounds must be integers")
	end
	if max - min > I32_MAX then
		Log.error(`range too wide; (max - min) must fit in i32, got {max - min}`)
	end

	local deltaId = allocDeltaId()

	return table.freeze({
		_isDelta = true,
		_typeCheck = "number",
		_isInteger = true,
		_min = min,
		_max = max,

		write = function(ch: Types.ChannelState, value: number): ()
			if value < min or value > max then
				Log.error(`value {value} out of range [{min}, {max}]`)
			end
			if floor(value) ~= value then
				Log.error(`value {value} must be an integer`)
			end
			varintWrite(ch, zigzagEncode(value - getScalarPrev(ch, deltaId, min)))
			setScalarCache(ch, deltaId, value)
		end,

		read = function(src: buffer, pos: number, _refs: { Instance }?): (number, number)
			local raw, consumed = varintRead(src, pos)
			if consumed == 0 then
				Log.error("truncated deltaInt")
			end
			local cached = Baseline.getCache(deltaId)
			local value = (if cached ~= nil then cached :: number else min) + zigzagDecode(raw)
			if value < min or value > max then
				Log.error(`deltaInt decoded value {value} out of range [{min}, {max}]`)
			end
			Baseline.setCache(deltaId, value)
			return value, consumed
		end,
	}) :: Types.InternalCodec<number>
end

function DeltaScalar.deltaFloat(min: number, max: number, precision: number): Types.InternalCodec<number>
	if max - min == 0 then
		return Base.constant(min)
	end

	local _, _, _, scale, invScale, delta = Quantize.setup("Lync.deltaFloat", min, max, precision)
	local deltaId = allocDeltaId()

	return table.freeze({
		_isDelta = true,
		_typeCheck = "number",
		_min = min,
		_max = max,

		write = function(ch: Types.ChannelState, value: number): ()
			local q = round(clamp(value - min, 0, delta) * scale)
			varintWrite(ch, zigzagEncode(q - getScalarPrev(ch, deltaId, 0)))
			setScalarCache(ch, deltaId, q)
		end,

		read = function(src: buffer, pos: number, _refs: { Instance }?): (number, number)
			local raw, consumed = varintRead(src, pos)
			if consumed == 0 then
				Log.error("truncated deltaFloat")
			end
			local cached = Baseline.getCache(deltaId)
			local q = (if cached ~= nil then cached :: number else 0) + zigzagDecode(raw)
			Baseline.setCache(deltaId, q)
			return q * invScale + min, consumed
		end,
	}) :: Types.InternalCodec<number>
end

function DeltaScalar.deltaVec3(min: number, max: number, precision: number): Types.InternalCodec<Vector3>
	if max - min == 0 then
		return Base.constant(Vector3.new(min, min, min)) :: Types.InternalCodec<Vector3>
	end

	local _, _, _, scale, invScale, delta = Quantize.setup("Lync.deltaVec3", min, max, precision)
	local deltaId = allocDeltaId()

	return table.freeze({
		_isDelta = true,
		_typeCheck = "Vector3",
		_min = min,
		_max = max,

		write = function(ch: Types.ChannelState, value: Vector3): ()
			validateVec3(value, min, max, "Vector3")
			local qx, qy, qz = quantizeVec3(value, min, delta, scale)
			local cache = ch.deltas[deltaId] :: any
			local px, py, pz = 0, 0, 0
			if cache then
				px, py, pz = cache.qx :: number, cache.qy :: number, cache.qz :: number
			end

			varintWrite(ch, zigzagEncode(qx - px))
			varintWrite(ch, zigzagEncode(qy - py))
			varintWrite(ch, zigzagEncode(qz - pz))

			if cache then
				cache.qx, cache.qy, cache.qz = qx, qy, qz
			else
				ch.deltas[deltaId] = { qx = qx, qy = qy, qz = qz } :: any
			end
		end,

		read = function(src: buffer, pos: number, _refs: { Instance }?): (Vector3, number)
			local rx, cx = varintRead(src, pos)
			if cx == 0 then
				Log.error("truncated deltaVec3 X")
			end
			local ry, cy = varintRead(src, pos + cx)
			if cy == 0 then
				Log.error("truncated deltaVec3 Y")
			end
			local rz, cz = varintRead(src, pos + cx + cy)
			if cz == 0 then
				Log.error("truncated deltaVec3 Z")
			end

			local cached = Baseline.getCache(deltaId) :: any
			local px, py, pz = 0, 0, 0
			if cached then
				px, py, pz = cached.qx, cached.qy, cached.qz
			end
			local qx = px + zigzagDecode(rx)
			local qy = py + zigzagDecode(ry)
			local qz = pz + zigzagDecode(rz)
			Baseline.setCache(deltaId, { qx = qx, qy = qy, qz = qz })

			return Vector3.new(qx * invScale + min, qy * invScale + min, qz * invScale + min), cx + cy + cz
		end,
	}) :: Types.InternalCodec<Vector3>
end

function DeltaScalar.deltaCFrame(posMin: number, posMax: number, posPrecision: number): Types.InternalCodec<CFrame>
	local _, _, _, scale, invScale, delta = Quantize.setup("Lync.deltaCFrame", posMin, posMax, posPrecision)
	local deltaId = allocDeltaId()

	return table.freeze({
		_isDelta = true,
		_typeCheck = "CFrame",

		write = function(ch: Types.ChannelState, value: CFrame): ()
			local pos = value.Position
			validateVec3(pos, posMin, posMax, "CFrame position")
			local qx, qy, qz = quantizeVec3(pos, posMin, delta, scale)
			local packed = quatPack(quatFromCFrame(value))

			local cache = ch.deltas[deltaId] :: any
			local flag: number
			local px, py, pz = 0, 0, 0
			if cache then
				px = cache.qx :: number
				py = cache.qy :: number
				pz = cache.qz :: number
				local ppacked = cache.qrot :: number
				flag = 0
				if qx ~= px then
					flag = bor(flag, CF_X)
				end
				if qy ~= py then
					flag = bor(flag, CF_Y)
				end
				if qz ~= pz then
					flag = bor(flag, CF_Z)
				end
				if packed ~= ppacked then
					flag = bor(flag, CF_ROT)
				end
			else
				flag = CF_ALL
			end

			ensure(ch, 1)
			writeu8(ch.buff, ch.cursor, flag)
			ch.cursor += 1

			if band(flag, CF_X) ~= 0 then
				varintWrite(ch, zigzagEncode(qx - px))
			end
			if band(flag, CF_Y) ~= 0 then
				varintWrite(ch, zigzagEncode(qy - py))
			end
			if band(flag, CF_Z) ~= 0 then
				varintWrite(ch, zigzagEncode(qz - pz))
			end
			if band(flag, CF_ROT) ~= 0 then
				ensure(ch, 4)
				writeu32(ch.buff, ch.cursor, packed)
				ch.cursor += 4
			end

			if cache then
				cache.qx, cache.qy, cache.qz, cache.qrot = qx, qy, qz, packed
			else
				ch.deltas[deltaId] = { qx = qx, qy = qy, qz = qz, qrot = packed } :: any
			end
		end,

		read = function(src: buffer, pos: number, _refs: { Instance }?): (CFrame, number)
			if pos >= bufLen(src) then
				Log.error("truncated deltaCFrame header")
			end
			local flag = readu8(src, pos)
			local total = 1

			local cached = Baseline.getCache(deltaId) :: any
			local qx, qy, qz, packed = 0, 0, 0, 0
			if cached then
				qx, qy, qz, packed = cached.qx, cached.qy, cached.qz, cached.qrot
			end

			if band(flag, CF_X) ~= 0 then
				local r, c = varintRead(src, pos + total)
				if c == 0 then
					Log.error("truncated deltaCFrame X")
				end
				qx += zigzagDecode(r)
				total += c
			end
			if band(flag, CF_Y) ~= 0 then
				local r, c = varintRead(src, pos + total)
				if c == 0 then
					Log.error("truncated deltaCFrame Y")
				end
				qy += zigzagDecode(r)
				total += c
			end
			if band(flag, CF_Z) ~= 0 then
				local r, c = varintRead(src, pos + total)
				if c == 0 then
					Log.error("truncated deltaCFrame Z")
				end
				qz += zigzagDecode(r)
				total += c
			end
			if band(flag, CF_ROT) ~= 0 then
				if pos + total + 4 > bufLen(src) then
					Log.error("truncated deltaCFrame rotation")
				end
				packed = readu32(src, pos + total)
				total += 4
			end

			Baseline.setCache(deltaId, { qx = qx, qy = qy, qz = qz, qrot = packed })

			local position = Vector3.new(qx * invScale + posMin, qy * invScale + posMin, qz * invScale + posMin)
			return CFrame.new(position) * quatUnpack(packed), total
		end,
	}) :: Types.InternalCodec<CFrame>
end

return table.freeze(DeltaScalar)
