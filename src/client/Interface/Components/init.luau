--!strict
local Fusion = require(script.Parent.Fusion)

local ImageButtonComponent = require(script.Buttons.ImageButton)
local ImageLabelComponent = require(script.Elements.ImageLabel)
local TextButtonComponent = require(script.Buttons.TextButton)
local TextLabelComponent = require(script.Elements.TextLabel)
local ScreenGuiComponent = require(script.Elements.ScreenGui)
local CanvasGroupComponent = require(script.Elements.CanvasGroup)
local FrameComponent = require(script.Elements.Frame)

local UIListLayoutComponent = require(script.Elements.UIListLayout)
local UIPaddingComponent = require(script.Elements.UIPadding)
local UIGridComponent = require(script.Elements.UIGridLayout)
local UIGradientComponent = require(script.Elements.UIGradient)

export type frameProps = {}

export type ComponentScope = Fusion.Scope

local Component = {
	CanvasGroup = function(self, props)
		return CanvasGroupComponent(self, props)
	end,
	Frame = function(self, props)
		return FrameComponent(self, props)
	end,
	ImageButton = function(self, props)
		return ImageButtonComponent(self, props)
	end,
	ImageLabel = function(self, props)
		return ImageLabelComponent(self, props)
	end,
	ScreenGui = function(self, props)
		return ScreenGuiComponent(self, props)
	end,
	TextButton = function(self, props)
		return TextButtonComponent(self, props)
	end,
	TextLabel = function(self, props)
		return TextLabelComponent(self, props)
	end,
	UIPadding = function(self, props)
		return UIPaddingComponent(self, props)
	end,
	UIListLayout = function(self, props)
		return UIListLayoutComponent(self, props)
	end,
	UIGridLayout = function(self, props)
		return UIGridComponent(self, props)
	end,
	UIGradient = function(self, props)
		return UIGradientComponent(self, props)
	end,
} :: ComponentMethods

Component.New = function(scope: Fusion.Scope)
	local newComponent = Fusion.scoped(Fusion)
	return setmetatable(newComponent, Component)
end

export type ComponentMethods = {
	Scope: ComponentScope,
	CanvasGroup: (scope: ComponentScope, props: CanvasGroupComponent.canvasGroupProp) -> CanvasGroup,
	Frame: (scope: ComponentScope, props: FrameComponent.frameProp) -> Frame,
	ImageLabel: (scope: ComponentScope, props: ImageLabelComponent.imageLabelProp) -> ImageLabel,
	ScreenGui: (scope: ComponentScope, props: ScreenGuiComponent.screenGuiProp) -> ScreenGui,
	TextButton: (scope: ComponentScope, props: TextButtonComponent.textButtonProp) -> TextButton,
	TextLabel: (scope: ComponentScope, props: TextLabelComponent.textLabelProp) -> TextLabel,
	UIPadding: (scope: ComponentScope, props: UIPaddingComponent.UIPaddingProps) -> UIPadding,
	UIListLayout: (scope: ComponentScope, props: UIListLayoutComponent.UIListLayoutProp) -> UIListLayout,
	UIGridLayout: (scope: ComponentScope, props: UIGridComponent.UIGridLayoutProp) -> UIGridLayout,
	UIGradient: (scope: ComponentScope, props: UIGradientComponent.UIGradientProps) -> UIGradient,
	New: (scope: ComponentScope) -> typeof(setmetatable(Fusion.scoped(Fusion), Component)),
}

return Component
