--!strict
--!native

local Channel = require(script.Parent.Parent.Parent.internal.Channel)
local Log = require(script.Parent.Parent.Parent.util.Log)
local Types = require(script.Parent.Parent.Parent.Types)

local pushRef = Channel.pushRef
local readu16 = buffer.readu16

local function writeInstance(ch: Types.ChannelState, value: Instance): ()
	pushRef(ch, value)
end

local function readInstance(src: buffer, pos: number, refs: { Instance }?): (Instance, number)
	local r = refs
	if not r then
		Log.error("refs array is required")
	end

	local idx = readu16(src, pos)
	if idx < 1 or idx > #r then
		Log.error(`ref index {idx} out of bounds`)
	end

	local inst = r[idx]
	if typeof(inst) ~= "Instance" then
		Log.error("ref is not an Instance")
	end
	return inst, 2
end

local InstanceCodec = {}

InstanceCodec.inst = table.freeze({
	_size = 2,
	_typeCheck = "Instance",
	write = writeInstance,
	read = readInstance,
})

return table.freeze(InstanceCodec)
