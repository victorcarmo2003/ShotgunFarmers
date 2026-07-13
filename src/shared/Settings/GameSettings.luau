return {
    -- Quanto histórico de posição mantemos por jogador no SnapshotService (segundos).
    SnapshotHistorySeconds = 0.5,
    -- Rewind máximo permitido na validação de hit — mais que isso e tratamos como
    -- desatualizado/suspeito em vez de rebobinar (anti-abuso).
    MaxRewindSeconds = 0.3,
    -- Fator aplicado ao Spread da arma enquanto o jogador está mirando (ADS).
    -- 1 = sem redução, 0 = sem espalhamento nenhum enquanto mira. Compartilhado entre
    -- client (spread visual/reivindicação local) e server (spread real de validação),
    -- pra os dois nunca divergirem.
    AimSpreadMultiplier = 0.4,
    -- Fator aplicado ao Spread da arma enquanto o jogador está se movendo (Humanoid.
    -- MoveDirection ~= 0). >1 = espalha mais que o parado. Combina multiplicativamente
    -- com AimSpreadMultiplier (dá pra mirar andando, só que pior que mirando parado).
    MovingSpreadMultiplier = 1.5,
}