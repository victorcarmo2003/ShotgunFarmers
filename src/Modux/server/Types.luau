--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pick = require(ReplicatedStorage.shared.Modux.Types.Pick)
local SelfOf = require(ReplicatedStorage.shared.Modux.Types.SelfOf)
local Libs = require(ReplicatedStorage.shared.Modux.Libs)
local Manifest = require(script.Parent.Manifest)

export type ServiceKey = keyof<Manifest.AllServices>
export type ComponentKey = keyof<Manifest.AllComponents>

export type ServiceProps = {
	Require: { ServiceKey },
	Priority: number?,
}

export type ComponentProps = {
	Require: { ServiceKey },
	Priority: number?,
	Tag: string?,
}

export type ServiceSelf<ID, P> = SelfOf.Build<
	index<Manifest.AllServices, ID>,
	{
		Dependencies: Pick.Table<Manifest.AllServices, SelfOf.RequireOf<P>>,
		Libs: Libs.Api,
		Components: Manifest.ComponentAccess,
	}
>

export type ComponentSelf<ID, P> = SelfOf.Build<
	index<Manifest.AllComponents, ID>,
	{
		Dependencies: Pick.Table<Manifest.AllServices, SelfOf.RequireOf<P>>,
		Libs: Libs.Api,
		Components: Manifest.ComponentAccess,
		Destroy: (self: any) -> (),
	}
>

export type ServiceBase<ID, P> = {
	OnTick: (self: any, callback: (self: ServiceSelf<ID, P>) -> (), tickRate: number?, priority: number?) -> (),
	OnInit: (self: any, callback: (self: ServiceSelf<ID, P>) -> ()) -> (),
	OnStart: (self: any, callback: (self: ServiceSelf<ID, P>) -> ()) -> (),
}

export type ComponentBase<ID, P> = {
	OnTick: (self: any, callback: (self: ComponentSelf<ID, P>) -> (), tickRate: number?, priority: number?) -> (),
	OnInit: (self: any, callback: (self: ComponentSelf<ID, P>) -> ()) -> (),
	OnStart: (self: any, callback: (self: ComponentSelf<ID, P>) -> ()) -> (),
	OnDestroy: (self: any, callback: (self: ComponentSelf<ID, P>) -> ()) -> (),
}

export type ServiceReturn<ID, P> = setmetatable<ServiceSelf<ID, P>, { __index: ServiceBase<ID, P> }>
export type ComponentReturn<ID, P> = setmetatable<ComponentSelf<ID, P>, { __index: ComponentBase<ID, P> }>

return {}
