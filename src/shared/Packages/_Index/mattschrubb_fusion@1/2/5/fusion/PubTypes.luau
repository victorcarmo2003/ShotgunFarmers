--!strict

type Set<T> = { [T]: any }

export type Symbol = {
	type: string,
	name: string,
}

export type Animatable =
	number
	| CFrame
	| Color3
	| ColorSequenceKeypoint
	| DateTime
	| NumberRange
	| NumberSequenceKeypoint
	| PhysicalProperties
	| Ray
	| Rect
	| Region3
	| Region3int16
	| UDim
	| UDim2
	| Vector2
	| Vector2int16
	| Vector3
	| Vector3int16

export type Task =
	Instance
	| RBXScriptConnection
	| () -> ()
	| { destroy: (any) -> () }
	| { Destroy: (any) -> () }
	| { Task }

export type Version = {
	major: number,
	minor: number,
	isRelease: boolean,
}

export type Dependency = {
	dependentSet: Set<Dependent>,
}

export type Dependent = {
	update: (Dependent) -> boolean,
	dependencySet: Set<Dependency>,
}

export type StateObject<T> = Dependency & {
	type: string,
	kind: string,
	get: (StateObject<T>, asDependency: boolean?) -> T,
}

export type CanBeState<T> = StateObject<T> | T

export type Value<T> = StateObject<T> & {

	set: (Value<T>, newValue: any, force: boolean?) -> (),
}

export type Computed<T> = StateObject<T> & Dependent & {}

export type ForPairs<KO, VO> = StateObject<{ [KO]: VO }> & Dependent & {}

export type ForKeys<KO, V> = StateObject<{ [KO]: V }> & Dependent & {}

export type ForValues<K, VO> = StateObject<{ [K]: VO }> & Dependent & {}

export type Tween<T> = StateObject<T> & Dependent & {}

export type Spring<T> = StateObject<T> & Dependent & {}

export type Observer = Dependent & {

	onChange: (Observer, callback: () -> ()) -> () -> (),
}

export type SpecialKey = {
	type: string,
	kind: string,
	stage: string,
	apply: (SpecialKey, value: any, applyTo: Instance, cleanupTasks: { Task }) -> (),
}

export type Children = Instance | StateObject<Children> | { [any]: Children }

export type PropertyTable = { [string | SpecialKey]: any }

return nil
