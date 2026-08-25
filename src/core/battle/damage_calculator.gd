class_name DamageCalculator
extends RefCounted


static func resolve(context: DamageContext, status: SimStatus) -> DamageResult:
	if not status.is_ok():
		return DamageResult.new()
	if context == null or not context.is_initialized():
		status.fail(
			SimStatus.Code.INVALID_DAMAGE_CONTEXT,
			SimStatus.Operation.DAMAGE_RESOLVE,
			0,
			0
		)
		return DamageResult.new()
	if context.impact_speed_raw() < DamageLimits.DAMAGE_THRESHOLD_SPEED_RAW:
		return DamageResult.create(
			context.attacker_body_id(),
			context.victim_body_id(),
			0,
			0,
			0,
			false
		)

	var mass_ratio_raw: int = FixMath.div_raw(
		context.attacker_mass_raw(), context.victim_mass_raw(), status
	)
	var weight_ratio_raw: int = FixMath.sqrt_raw(mass_ratio_raw, status)
	weight_ratio_raw = FixMath.clamp_explicit_raw(
		weight_ratio_raw,
		DamageLimits.WEIGHT_RATIO_MIN_RAW,
		DamageLimits.WEIGHT_RATIO_MAX_RAW,
		status
	)
	var attack_raw: int = FixMath.from_int(context.attacker_attack(), status)
	var speed_ratio_raw: int = FixMath.div_raw(
		context.impact_speed_raw(),
		DamageLimits.DAMAGE_REFERENCE_SPEED_RAW,
		status
	)
	var value_raw: int = FixMath.mul_raw(attack_raw, speed_ratio_raw, status)
	value_raw = FixMath.mul_raw(value_raw, weight_ratio_raw, status)
	var outgoing_factor_raw: int = FixMath.add_raw(
		FixMath.ONE_RAW, context.outgoing_ratio_bonus_raw(), status
	)
	var incoming_factor_raw: int = FixMath.sub_raw(
		FixMath.ONE_RAW, context.incoming_ratio_reduction_raw(), status
	)
	value_raw = FixMath.mul_raw(value_raw, outgoing_factor_raw, status)
	value_raw = FixMath.mul_raw(value_raw, incoming_factor_raw, status)
	if context.same_non_neutral_faction():
		value_raw = FixMath.mul_ratio_raw(
			value_raw,
			DamageLimits.FRIENDLY_DAMAGE_NUMERATOR,
			DamageLimits.FRIENDLY_DAMAGE_DENOMINATOR,
			status
		)
	value_raw = FixMath.mul_raw(value_raw, context.clean_hit_damage_multiplier_raw(), status)
	if context.critical_applied():
		value_raw = FixMath.mul_ratio_raw(
			value_raw,
			DamageLimits.CRITICAL_DAMAGE_NUMERATOR,
			DamageLimits.CRITICAL_DAMAGE_DENOMINATOR,
			status
		)
	var fixed_increase_raw: int = FixMath.from_int(
		context.fixed_increase(), status
	)
	var fixed_reduction_raw: int = FixMath.from_int(
		context.fixed_reduction(), status
	)
	value_raw = FixMath.add_raw(value_raw, fixed_increase_raw, status)
	value_raw = FixMath.sub_raw(value_raw, fixed_reduction_raw, status)
	var resolved_damage: int = FixMath.to_int_round(value_raw, status)
	if not status.is_ok():
		return DamageResult.new()
	resolved_damage = maxi(1, resolved_damage)
	var applied_damage: int = mini(
		context.victim_current_hp(), resolved_damage
	)
	return DamageResult.create(
		context.attacker_body_id(),
		context.victim_body_id(),
		weight_ratio_raw,
		resolved_damage,
		applied_damage,
		applied_damage == context.victim_current_hp()
	)
