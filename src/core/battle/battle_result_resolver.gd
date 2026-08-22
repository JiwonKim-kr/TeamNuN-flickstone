class_name BattleResultResolver
extends RefCounted

static func resolve(participants: Array[BattleParticipant]) -> int:
	var player_alive: int = 0
	var enemy_alive: int = 0
	for item: BattleParticipant in participants:
		if not item.counts_for_victory(): continue
		if item.faction() == BattleParticipant.Faction.PLAYER: player_alive += 1
		elif item.faction() == BattleParticipant.Faction.ENEMY: enemy_alive += 1
	if player_alive > 0 and enemy_alive > 0: return BattleResult.Value.ONGOING
	if player_alive > 0: return BattleResult.Value.PLAYER_VICTORY
	if enemy_alive > 0: return BattleResult.Value.PLAYER_DEFEAT
	return BattleResult.Value.DRAW
