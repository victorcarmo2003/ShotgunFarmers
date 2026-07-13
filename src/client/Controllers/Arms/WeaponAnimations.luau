--modux ignore file
--!strict

-- Só a função utilitária de carregar track ficou aqui -- os IDs de animação por arma
-- migraram pra GunData.Animations (ver src/shared/Datas/Guns.luau), centralizados
-- junto com o resto dos dados da arma em vez de espalhados num módulo à parte.
local WeaponAnimations = {}

function WeaponAnimations.LoadTrack(animator: Animator, animationId: string): AnimationTrack?
	if animationId == "" then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	local track = animator:LoadAnimation(animation)
	--track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	return track
end

return WeaponAnimations
