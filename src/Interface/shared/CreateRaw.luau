--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

type Instances = {
	UIPadding: UIPadding,
	UIScale: UIScale,
	UIStroke: UIStroke,
	UISizeConstraint: UISizeConstraint,
	UITextSizeConstraint: UITextSizeConstraint,
	UIFlexItem: UIFlexItem,
	UIPageLayout: UIPageLayout,
	UITableLayout: UITableLayout,
	ViewportFrame: ViewportFrame,
	VideoFrame: VideoFrame,
	Sound: Sound,
	Highlight: Highlight,
	Part: Part,
	Model: Model,
	Attachment: Attachment,
}

type function Properties(instance: type?)
	local properties = types.newtable()

	while instance do
		for key, value in instance:properties() do
			local connector = value.read and value.read.tag == "table" and value.read:readproperty(types.singleton("Connect"))
			if connector then
				local params = connector:parameters().head
				if not params then
					continue
				end
				local listener = params[2]
				if not listener then
					continue
				end
				properties:setproperty(key, types.optional(listener))
			elseif value.write then
				properties:setproperty(key, types.optional(types.unionof(value.write, types.newfunction({}, { head = { value.write } }))))
			end
		end

		instance = instance:readparent()
	end

	properties:setindexer(types.number, types.any)

	return properties
end

export type CreateRaw = <Name>(Name | keyof<Instances>) -> (Properties<index<Instances, Name>>) -> index<Instances, Name>

return (Vide.create :: any) :: CreateRaw
