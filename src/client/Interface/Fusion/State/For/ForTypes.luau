--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil

local Package = script.Parent.Parent.Parent
local Types = require(Package.Types)

export type SubObject<S, KI, KO, VI, VO> = {

	maybeScope: Types.Scope<S>?,
	inputKey: KI,
	inputValue: VI,
	roamKeys: boolean,
	roamValues: boolean,
	invalidateInputKey: (SubObject<S, KI, KO, VI, VO>) -> (),
	invalidateInputValue: (SubObject<S, KI, KO, VI, VO>) -> (),
	useOutputPair: (SubObject<S, KI, KO, VI, VO>, Types.Use) -> (KO?, VO?),
}

export type Disassembly<S, KI, KO, VI, VO> = Types.GraphObject & {
	populate: (Disassembly<S, KI, KO, VI, VO>, Types.Use, output: { [KO]: VO }) -> (),
}

return nil
