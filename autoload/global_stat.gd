extends Node
# if utilising without the DDAT-GPF framework make sure you change this
#	script to extend from Node!
#extends GameGlobal

#class_name GlobalStat

##############################################################################

# Public API for Stat class management.
# See the Stat class for an explanation of how to utilise Stats.

##############################################################################

# properties

# lookup for Stats
# stored as {owner: {name: Stat, ...}, ...}
var stats := {}

##############################################################################

# virt

##############################################################################

# public


# initialises a new stat
# ALWAYS CALL THIS METHOD BEFORE TRYING TO APPLY MODS OR USE A STAT
# specify arg_allow_overwrite if you're okay overwriting an existing Stat
func add(arg_owner: Object, arg_name: String, arg_base_value: float, arg_allow_overwrite: bool = false) -> int:
	if is_instance_valid(arg_owner) == false\
	or arg_name == "":
		return ERR_INVALID_PARAMETER
	var new_stat_data = Stat.new(arg_owner, arg_name, arg_base_value)
	if is_instance_valid(new_stat_data):
		if _verify_stat(arg_owner, arg_name, arg_allow_overwrite):
			var can_create := true
			if stats[arg_owner].has(arg_name):
				can_create = true if arg_allow_overwrite else false
			if can_create:
				stats[arg_owner][arg_name] = new_stat_data
				return OK
	#else:
	return ERR_CANT_CREATE


# change method name to apply for consistency
# see _apply_modifier for argument breakdown (same arguments are used)
func apply_mod_flat(arg_owner: Object, arg_name: String, arg_mod_id: String, arg_value, arg_duration: int = -1) -> void:
	_apply_modifier(arg_mod_id, arg_owner, arg_name, Stat.MODIFIER.FLAT, arg_value, arg_duration)


# change method name to apply for consistency
# see _apply_modifier for argument breakdown (same arguments are used)
func apply_mod_inc(arg_owner: Object, arg_name: String, arg_mod_id: String, arg_value, arg_duration: int = -1) -> void:
	_apply_modifier(arg_mod_id, arg_owner, arg_name, Stat.MODIFIER.INCREASED, arg_value, arg_duration)


# change method name to apply for consistency
# see _apply_modifier for argument breakdown (same arguments are used)
func apply_mod_more(arg_owner: Object, arg_name: String, arg_mod_id: String, arg_value, arg_duration: int = -1) -> void:
	_apply_modifier(arg_mod_id, arg_owner, arg_name, Stat.MODIFIER.MORE, arg_value, arg_duration)


# if the Stat exists, returns that Stat. Otherwise throws an error.
func find(arg_owner: Object, arg_name: String) -> Stat:
	var subject_stat_data = null
	if has(arg_owner, arg_name):
		if stats.has(arg_owner):
			if typeof(stats[arg_owner]) == TYPE_DICTIONARY:
				if stats[arg_owner].has(arg_name):
					var get_stat = stats[arg_owner][arg_name]
					if get_stat is Stat:
						return get_stat
	# catchall
	StatLogger.error(self, "could not find {0} in stats[{1}]; cannot find Stat".format([arg_name, arg_owner]))
	return null


# as find() method but does not expect a Stat exists
func has(arg_owner: Object, arg_name: String) -> bool:
	var subject_stat_data = null
	if stats.has(arg_owner) == false:
		return false
	if stats[arg_owner].has(arg_name):
		subject_stat_data = stats[arg_owner][arg_name]
		if subject_stat_data is Stat:
			return true
		else:
			StatLogger.error(self, "invalid object stored in stats[{0}][{1}]! How did this happen?".\
					format([arg_owner, arg_name]))
			return false
	else:
		return false


# returns stat as an int value, rounded down to nearest whole
func get_int(arg_owner: Object, arg_name: String, arg_verbose: bool = false) -> int:
	var subject_stat_data: Stat = find(arg_owner, arg_name)
	if is_instance_valid(subject_stat_data) == false:
		StatLogger.error(self, "get_int() cannot find Stat at stats[{0}][{1}]".format([arg_owner, arg_name]))
		return 0
	else:
		var output = subject_stat_data.get_int()
		if arg_verbose:
			StatLogger.info(self, subject_stat_data.data_to_string())
		return output


# returns stat as a float value
func get_real(arg_owner: Object, arg_name: String, arg_verbose: bool = false) -> float:
	var subject_stat_data: Stat = find(arg_owner, arg_name)
	if is_instance_valid(subject_stat_data) == false:
		StatLogger.error(self, "get_real() cannot find Stat at stats[{0}][{1}]".format([arg_owner, arg_name]))
		return 0.0
	else:
		var output = subject_stat_data.get_real()
		if arg_verbose:
			StatLogger.info(self, subject_stat_data.data_to_string())
		return output


# check if specific mod exists on a Stat
func has_mod(arg_owner: Object, arg_name: String, arg_mod_key) -> bool:
	var subject_stat_data: Stat = find(arg_owner, arg_name)
	if is_instance_valid(subject_stat_data) == false:
		StatLogger.error(self, "has_mod() cannot find Stat at stats[{0}][{1}]".format([arg_owner, arg_name]))
		return false
	else:
		return subject_stat_data.has_mod(arg_mod_key)


# returns the current value of a specific mod
# arg_mod_type should be passed a value from the Stat.MODIFIER enum
# if arg_mod_type is unspecified or invalid, all mod arrays will be searched
func mod_value(arg_owner: Object, arg_name: String, arg_mod_key) -> float:
	var subject_stat_data: Stat = find(arg_owner, arg_name)
	if is_instance_valid(subject_stat_data) == false:
		StatLogger.error(self, "mod_value() cannot find Stat at stats[{0}][{1}]".format([arg_owner, arg_name]))
		return 0.0
	else:
		var mod = subject_stat_data.find_mod(arg_mod_key)
		assert(typeof(mod) == TYPE_DICTIONARY)
		# check if mod was found
		if mod.empty() == false:
			assert(mod.has(Stat.ID_MOD_VALUE))
			var mod_value = mod[Stat.ID_MOD_VALUE]
			assert(typeof(mod_value) == TYPE_REAL)
			return mod_value
		else:
			StatLogger.error(self, "mod_value() found Stat (at stats[{0}][{1}]) but could not find mod key {2}".\
					format([arg_owner, arg_name, arg_mod_key]))
			return 0.0


# returns the remaining duration of a specific mod
func remaining(arg_owner: Object, arg_name: String, arg_mod_key) -> int:
	var subject_stat_data: Stat = find(arg_owner, arg_name)
	if is_instance_valid(subject_stat_data) == false:
		StatLogger.error(self, "remaining() cannot find Stat at stats[{0}][{1}]".format([arg_owner, arg_name]))
		return 0
	else:
		return subject_stat_data.remaining(arg_mod_key)


## removes a specific mod, if it can be found
func remove_mod(arg_owner: Object, arg_name: String, arg_mod_key) -> void:
	var subject_stat_data: Stat = find(arg_owner, arg_name)
	if is_instance_valid(subject_stat_data) == false:
		StatLogger.error(self, "remove_mod() cannot find Stat at stats[{0}][{1}]".format([arg_owner, arg_name]))
		return
	else:
		subject_stat_data.remove_mod(arg_mod_key)


# rename an active mod key
func rename_mod(arg_owner: Object, arg_old_name: String, arg_new_name: String):
	var subject_stat_data: Stat = find(arg_owner, arg_old_name)
	if is_instance_valid(subject_stat_data) == false:
		StatLogger.error(self, "rename_mod() cannot find Stat at stats[{0}][{1}]".format([arg_owner, arg_old_name]))
		return false
	else:
		return subject_stat_data.rename_mod(arg_old_name, arg_new_name)
#
#
## changes the base value of a stored Stat
func update_base_value(arg_owner: Object, arg_name: String, arg_new_base_value) -> void:
	var subject_stat_data: Stat = find(arg_owner, arg_name)
	if is_instance_valid(subject_stat_data) == false:
		StatLogger.error(self, "update_base_value() cannot find Stat at stats[{0}][{1}]".format([arg_owner, arg_name]))
		return
	else:
		subject_stat_data.base_value = arg_new_base_value


# changes the duration of a specific mod, if it can be found
func update_mod_duration(arg_owner: Object, arg_name: String, arg_mod_key, arg_duration: int) -> void:
	var subject_stat_data: Stat = find(arg_owner, arg_name)
	if is_instance_valid(subject_stat_data) == false:
		StatLogger.error(self, "update_mod_duration() cannot find Stat at stats[{0}][{1}]".format([arg_owner, arg_name]))
		return
	else:
		subject_stat_data.update_mod_duration(arg_mod_key, arg_duration)


# changes the value of a specific mod, if it can be found
func update_mod_value(arg_owner: Object, arg_name: String, arg_mod_key, arg_mod_value) -> void:
	var subject_stat_data: Stat = find(arg_owner, arg_name)
	if is_instance_valid(subject_stat_data) == false:
		StatLogger.error(self, "update_mod_value() cannot find Stat at stats[{0}][{1}]".format([arg_owner, arg_name]))
		return
	else:
		subject_stat_data.update_mod_value(arg_mod_key, arg_mod_value)


##############################################################################

# private


# arg_mod_key is the identifier for the stat modifier, used to change or remove it later
# arg_owner is the object the stat belongs to
# arg_name is the name of the object that the stat adjusts
# arg_mod_type is the type of modifier (see Stat.MODIFIER enum)
# arg_value is the change applied by the modifier, this should always be a float (though stats can also return int)
# arg_duration is how long the modifier lasts for; if negative it will never automatically expire
func _apply_modifier(arg_mod_key: String, arg_owner: Object, arg_name: String, arg_mod_type: int, arg_value, arg_duration: int):
	var subject_stat_data: Stat = find(arg_owner, arg_name)
	if is_instance_valid(subject_stat_data) == false:
		StatLogger.error(self, "stat not found for {0}.{1}".format([arg_owner, arg_name]))
		return
	match arg_mod_type:
		subject_stat_data.MODIFIER.FLAT:
			subject_stat_data.apply_mod(arg_mod_type, arg_mod_key, arg_value, arg_duration)
		subject_stat_data.MODIFIER.INCREASED:
			subject_stat_data.apply_mod(arg_mod_type, arg_mod_key, arg_value, arg_duration)
		subject_stat_data.MODIFIER.MORE:
			subject_stat_data.apply_mod(arg_mod_type, arg_mod_key, arg_value, arg_duration)


# check arguments are valid and an entry exists for them (creates one if not)
# specify arg_allow_duplicate as true if you're alright overwriting a stat
func _verify_stat(arg_owner: Object, arg_name: String, arg_allow_duplicate: bool = false) -> bool:
	if stats.has(arg_owner):
		if typeof(stats[arg_owner]) != TYPE_DICTIONARY:
			StatLogger.error(self, "invalid data structure at stats[{0}]".format([arg_owner]))
	else:
		stats[arg_owner] = {}
	
	var is_owner_valid = is_instance_valid(arg_owner)
	if is_owner_valid == false:
		StatLogger.error(self, "owner instance invalid")
	
	var is_name_valid = (name != "")
	if stats[arg_owner].has(name):
		StatLogger.error(self, "already tracking {0} as Stat of {1}".format([arg_name, arg_owner]))
		if arg_allow_duplicate == false:
			is_name_valid = false
	
	return is_owner_valid and is_name_valid
