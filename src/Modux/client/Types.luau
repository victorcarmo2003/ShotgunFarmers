--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pick = require(ReplicatedStorage.shared.Modux.Types.Pick)
local SelfOf = require(ReplicatedStorage.shared.Modux.Types.SelfOf)
local Libs = require(ReplicatedStorage.shared.Modux.Libs)
local Manifest = require(script.Parent.Manifest)

export type ControllerKey = keyof<Manifest.AllControllers>
export type ComponentKey = keyof<Manifest.AllComponents>

export type ControllerProps = {
	Require: { ControllerKey },
	Priority: number?,
}

export type ComponentProps = {
	Require: { ControllerKey },
	Priority: number?,
	Tag: string?,
}

export type ControllerSelf<ID, P> = SelfOf.Build<
	index<Manifest.AllControllers, ID>,
	{
		Dependencies: Pick.Table<Manifest.AllControllers, SelfOf.RequireOf<P>>,
		Libs: Libs.Api,
		Components: Manifest.ComponentAccess,
	}
>

export type ComponentSelf<ID, P> = SelfOf.Build<
	index<Manifest.AllComponents, ID>,
	{
		Dependencies: Pick.Table<Manifest.AllControllers, SelfOf.RequireOf<P>>,
		Libs: Libs.Api,
		Components: Manifest.ComponentAccess,
		Destroy: (self: any) -> (),
	}
>

export type ControllerBase<ID, P> = {
	OnTick: (self: any, callback: (self: ControllerSelf<ID, P>) -> (), tickRate: number?, priority: number?) -> (),
	OnInit: (self: any, callback: (self: ControllerSelf<ID, P>) -> ()) -> (),
	OnStart: (self: any, callback: (self: ControllerSelf<ID, P>) -> ()) -> (),
}

export type ComponentBase<ID, P> = {
	OnTick: (self: any, callback: (self: ComponentSelf<ID, P>) -> (), tickRate: number?, priority: number?) -> (),
	OnInit: (self: any, callback: (self: ComponentSelf<ID, P>) -> ()) -> (),
	OnStart: (self: any, callback: (self: ComponentSelf<ID, P>) -> ()) -> (),
	OnDestroy: (self: any, callback: (self: ComponentSelf<ID, P>) -> ()) -> (),
}

export type ControllerReturn<ID, P> = setmetatable<ControllerSelf<ID, P>, { __index: ControllerBase<ID, P> }>
export type ComponentReturn<ID, P> = setmetatable<ComponentSelf<ID, P>, { __index: ComponentBase<ID, P> }>

return {}
