--!strict
--!optimize 2

local _server: any = nil
local _client: any = nil

local Transport = {}

function Transport.server(): any
	if not _server then
		_server = require(script.Parent.Parent.transport.Server)
	end
	return _server
end

function Transport.client(): any
	if not _client then
		_client = require(script.Parent.Parent.transport.Client)
	end
	return _client
end

return table.freeze(Transport)
