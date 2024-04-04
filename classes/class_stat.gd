extends Reference

class_name Stat

##############################################################################

# Stat class for applying complex temporary modifiers to a float value
# Extends from reference so freed when no longer in use

# There are two supported ways to utilise the Stat class.
#
# The first is that you can directly use Stats in your owning object,
#	and adjust your variant setters to return get_int or get_real.
#	e.g.
#		var speed = Stat.new(self, "speed", 50) setget , get_speed
#		func get_speed() -> float:
#			return speed.get_real()
#
#	With this first pratice you will have to call Stat methods directly,
#		and make sure the Stat is scoped correctly to be accessed.
#
# The second is that you can use the GlobalStat singleton (once set as
#	autoload) to reference and keep track of Stats.
#	e.g.
#		GlobalStat.add(owner, "speed", 50) # initialises Stat
#		GlobalStat.get_real(owner, "speed") # returns float to do stuff
#
#	With this second practice you access Stats entirely through the GlobalStat
#		public API, and can access any existing Stat of any object from
#		anywhere. The trade-off is that you have to specify the lookup
#		(owner, name) arguments on every method.

##############################################################################

# Different modifiers apply in different ways, and in a specific order of
#	operations. FLAT modifiers are applied first, INCREASED modifiers are
#	summed and applied as a single value second, and MORE modifiers are
#	applied individually as the last step.
# FLAT = additional value (int/float) that is added to (use negative for
#	subtraction) the value on get
# INCREASED - additional values (preferably float but int accepted) that are
#	summed to create a multiplier/coefficient applied to the value on get
#	'Increased' values should be provided as decimal increases, e.g. 0.1
#		to mean '+10%'. Increased values are added to a base of 1.0 (or
#		100%) so negative increased mods will not immediately nil the value
# MORE - values (preferably float but int accepted) are applied to the
#	value on get as coefficients
#	'More' values should be provided as decimal multipliers, e.g 0.05 to
#		mean 5% of current value or 1.4 to mean 140% of current value
enum MODIFIER {FLAT, INCREASED, MORE}

# Stats are always stored as floats but can be returned as integers
const ID_MOD_KEY := "ModKey" # how is this modifier identified; if duplicated will overwrite
const ID_MOD_TYPE := "ModType" # what type of modifier is it (see MODIFIER enum)
const ID_MOD_VALUE := "ModValue" # what is the effect of this modfiier
const ID_MOD_EXPIRY := "ExpiryMsec" # when will this modifier expire, negative is never

# identifier for the stat
var name: String = "" setget set_name
# must be set for Stat to be valid; this is the object the stat 'belongs' to
var owner: Object = null setget set_owner
# the value of the stat before any modifiers are applied
# set at initiailisation or modified through direct call
var base_value: float = 0.0

# the last calculated value of the Stat, will be returned on get
#	if all current mods are still valid (after tickstamps are checked)
# should not be directly modified
var _value: float = 0.0

# requires owner and name to be correctly set
var _is_valid := false

# array of all mods (stored as dictionaries whose keys equal the ID_MOD constants)
var _mods := []

##############################################################################

# constructor


func _init(arg_owner: Object, arg_name: String, arg_base_value: float = 0.0):
	self.owner = arg_owner
	self.name = arg_name
	self.base_value = arg_base_value
	if is_valid():
		# set initial _value
		_recalculate()


##############################################################################

# setters/getters


func set_name(arg_value: String) -> void:
	name = arg_value
	if is_valid():
		_recalculate()


func set_owner(arg_value: Object) -> void:
	owner = arg_value
	if is_valid():
		_recalculate()


##############################################################################

# public methods


#	arg_mod_type = the type of modifier, see the MODIFIER enum for detail
#		will default to adding a flat modifier if arg_mod_type is invalid
#	arg_mod_key = identifier for the modifier, important to find, change, or delete, later
#	arg_mod_value = the int or float value for the mod
#	arg_expiry = the msec (Time.get_ticks_msec) the mod will no longer be active
#		mod expiry is only checked when the value is fetched
#		if this value is set negative the mod will never expire
#	dev note: take care using msec and timer nodes in conjunction (converting
#		seconds to milliseconds) as small differences can become inaccurate
#		If you require exact notification of modifier expiry (e.g. for a status
#			effect) it is better to use a timer node elsewhere in your logic
#			and connect the timer expiry signal to a call to remove the mod
func apply_mod(
		arg_mod_type: int,
		arg_mod_key: String,
		arg_mod_value,
		arg_duration: int = -1) -> void:
	if not arg_mod_type in MODIFIER.values():
		arg_mod_type = MODIFIER.FLAT
	if typeof(arg_mod_value) == TYPE_INT:
		arg_mod_value = float(arg_mod_value)
	if _is_valid and typeof(arg_mod_value) == TYPE_REAL:
		var expiry = _get_mod_expiry(arg_duration)
		
		# if mod key doesn't exist, add the new mod
		if has_mod(arg_mod_key) == false:
			_add_new_modifier(arg_mod_type, arg_mod_key, arg_mod_value, expiry)
		# if it does, overwrite the previous mod
		else:
			StatLogger.warning(self, "mod at key {0} is being overwritten".format([arg_mod_key]))
			update_mod_duration(arg_mod_key, arg_duration)
			update_mod_type(arg_mod_key, arg_mod_type)
			update_mod_value(arg_mod_key, arg_mod_value)
	else:
		StatLogger.error(self, "cannot apply mod, invalid value or Stat")
		pass


# forces recalculation of modifiers and logging of the process
func calc_to_logs() -> void:
	_recalculate(true)


# returns a representation of all current active mods on the name
func data_to_string() -> String:
	# reformat keys for human-readable printing
	var modified_stats = {
		MODIFIER.keys()[MODIFIER.FLAT]: find_all_mods(MODIFIER.FLAT),
		MODIFIER.keys()[MODIFIER.INCREASED]: find_all_mods(MODIFIER.INCREASED),
		MODIFIER.keys()[MODIFIER.MORE]: find_all_mods(MODIFIER.MORE)
	}
	return "Stat {0} (_is_valid: {1})\n{2}.{3}\nStat Value:{4} (Base: {5})\n{6}".format([
		str(self), _is_valid,
		str(owner), name,
		_value, base_value,
		str(modified_stats)
	])


# returns an array of all mods of a specific type (or all if arg_mod_type
#	is unspecified or invalid)
func find_all_mods(arg_mod_type: int = -1) -> Array:
	var mods_found := []
	for mod in _mods:
		assert(_is_valid_mod(mod))
		if mod[ID_MOD_TYPE] == arg_mod_type or not arg_mod_type in MODIFIER.values():
			mods_found.append(mod)
	return(mods_found)


# looks through a mod array to find and return a mod by key
# if arg_mod_type is not specified or is invalid, all mod arrays will be searched
func find_mod(arg_mod_key) -> Dictionary:
	if _mods.empty():
		# do not log error/warning, sometimes you need to verify a mod doesn't exist
		#	so sometimes the expected result is empty/sometimes no mods are applied!
		return {}
	# lookup
	var mod_id = ""
	for mod in _mods:
		assert(_is_valid_mod(mod))
		mod_id = mod[ID_MOD_KEY]
		if mod_id == arg_mod_key:
			return mod
	# else not found
	return {}


# looks through active mods to get index of first mod that shares the same key
# will return negative value (-1) if cannot be found
func find_mod_index(arg_mod_key) -> int:
	if _mods.empty():
		StatLogger.warning(self, "find_mod_index cannot find mod with key {0}".format([arg_mod_key]))
		return -1
	else:
		var mod = find_mod(arg_mod_key)
		if mod.empty():
			return -1
		else:
			return _mods.find(mod)


# as get_real but returns as integer instead of float
# rounds toward nearets whole instead of truncating
func get_int() -> int:
	return int(round(get_real()))

# checks expiry of all modifiers - if none are expired will return
#	the current value, otherwise will recalculate (having pruned the
#	expired modifiers)
func get_real() -> float:
	if _are_mods_active() != OK:
		_recalculate()
	return self._value


# returns whether mod id exists in a mod array
# if arg_mod_type is not specified or is invalid, all mod arrays will be searched
# find_mod will return an empty dict if mod not found
func has_mod(arg_mod_key) -> bool:
	var mod_lookup: Dictionary = find_mod(arg_mod_key)
	return !mod_lookup.empty()


# if all validation checks will toggle the _is_valid flag
# called on init or when owner/name changes
func is_valid() -> bool:
	if _validate_owner() and name != "":
		self._is_valid = true
	else:
		# no error logging as is called on init/owner setter
		self._is_valid = false
	return _is_valid


# arg_mod_key is the mod to look up
# get the mod duration that is remaining; returns in msec
# if arg_mod_type is not specified or is invalid, all mod arrays will be searched
func remaining(arg_mod_key) -> int:
	var expiry = 0
	var remaining = 0
	var mod_lookup: Dictionary = find_mod(arg_mod_key)
	if mod_lookup.empty():
		StatLogger.warning(self, "remaining could not find mod with key {0}".format([arg_mod_key]))
		return 0
	else:
		expiry = mod_lookup[ID_MOD_EXPIRY]
		assert(typeof(expiry) == TYPE_INT)
		remaining = mod_lookup[ID_MOD_EXPIRY]-Time.get_ticks_msec()
		return remaining


# arg_mod_key is the mod to erase
# removes a single mod from the relevant mod array
# if arg_mod_type is not specified or is invalid, all mod arrays will be searched
func remove_mod(arg_mod_key) -> void:
	var mod_lookup: Dictionary = find_mod(arg_mod_key)
	if not mod_lookup.empty():
		_prune_mods([mod_lookup])
	_recalculate()
	return


func rename_mod(arg_old_mod_key, arg_new_mod_key):
	var mod_index = -1
	mod_index = find_mod_index(arg_old_mod_key)
	var does_new_key_already_exist = has_mod(arg_new_mod_key)
	if does_new_key_already_exist:
		StatLogger.warning(self, "cannot rename mod to {0}, this key already exists".format([arg_new_mod_key]))
		return
	# is found
	if mod_index != -1:
		# update value
		_mods[mod_index][ID_MOD_KEY] = arg_new_mod_key
	else:
		StatLogger.error(self, "{0} not found on {1} call".format([arg_old_mod_key, "rename_mod"]))
		return


# arg_mod_key is the mod to find and update
# arg_duration is the mod duration to replace
#	if set positive or nil the expiry will be reset to current msec + duration
#	if set negative the duration will be reset to infinite
func update_mod_duration(arg_mod_key, arg_duration: int = 0) -> void:
	var mod_index = -1
	mod_index = find_mod_index(arg_mod_key)
	if mod_index != -1:
		# update duration
		# apply new duration only if argument isn't nil (don't change)
		var new_expiry = _get_mod_expiry(arg_duration)
		if new_expiry != 0:
			_mods[mod_index][ID_MOD_EXPIRY] = new_expiry
		# must check for expired mods after updating a duration
		if _are_mods_active() != OK:
			_recalculate()
	else:
		StatLogger.error(self, "{0} not found on {1} call".format([arg_mod_key, "update_mod_duration"]))
		return


# arg_mod_key is the mod to find and update
# arg_mod_type is the new type to replace the old type with
# if arg_mod_type is invalid the method will exit
func update_mod_type(arg_mod_key, arg_mod_type: int) -> void:
	if not arg_mod_type in MODIFIER.values():
		StatLogger.error(self, "invalid parameter ({0}) for update_mod_type".format([arg_mod_type]))
		return
	var mod_index = -1
	mod_index = find_mod_index(arg_mod_key)
	# is found
	if mod_index != -1:
		# update value
		_mods[mod_index][ID_MOD_TYPE] = arg_mod_type
		# must update value after changing mod values
		_recalculate()
	else:
		StatLogger.error(self, "{0} not found on {1} call".format([arg_mod_key, "update_mod_type"]))
		return


# arg_mod_key is the mod to find and update
# arg_mod_value is the value to replace in the mod
func update_mod_value(arg_mod_key, arg_mod_value) -> void:
	var mod_index = -1
	mod_index = find_mod_index(arg_mod_key)
	# is found
	if mod_index != -1:
		# update value
		_mods[mod_index][ID_MOD_VALUE] = arg_mod_value
		# must update value after changing mod values
		_recalculate()
	else:
		StatLogger.error(self, "{0} not found on {1} call".format([arg_mod_key, "update_mod_value"]))
		return


##############################################################################

# private methods


# do not call directly, call apply_mod instead to properly validate values
func _add_new_modifier(arg_mod_type: int, arg_mod_key: String, arg_mod_value, expiry: int) -> void:
		var new_mod = {
				ID_MOD_KEY: arg_mod_key,
				ID_MOD_VALUE: arg_mod_value,
				ID_MOD_TYPE: arg_mod_type,
				ID_MOD_EXPIRY: expiry
			}
		_mods.append(new_mod)
		_recalculate()


# returns OK if no mods are expired, otherwise prunes the expired mods
#	and returns an error (signalling that get_stat should recalculate)
func _are_mods_active() -> int:
	# tickstamp sampled at start of method so everything is compared to equal value
	var current_msec = Time.get_ticks_msec()
	var mods_have_not_expired := OK
	# mods with the following keys are pruned at the end of the method
	var expired_mods := []
	
	if _mods.size() > 0:
		for modifier in _mods:
			assert(_is_valid_mod(modifier))
			if _is_mod_expired(current_msec, modifier):
				expired_mods.append(modifier)
		# if any mods were expired, remove them and ready an error for return
		if expired_mods.size() > 0:
			_prune_mods(expired_mods)
			mods_have_not_expired = ERR_TIMEOUT
		expired_mods.resize(0)
	
	# else
	return mods_have_not_expired


# determine mod expiry time from duration argument
# if duration value is nil or negative just returns the value
# negative values never expire; the mod must be manually removed
# nil values will expire immediately (on next check)
#	(unless utilised as part of update_mod, where a nil value instead means
#	'do not change the previous value')
func _get_mod_expiry(arg_duration) -> int:
	if arg_duration <= 0:
		return arg_duration
	else:
		return Time.get_ticks_msec()+arg_duration


# pass any mod from _mods, _mods_inc, _mods_more to validate if expired
func _is_mod_expired(arg_tickstamp: int, arg_mod: Dictionary) -> bool:
	assert(_is_valid_mod(arg_mod))
	# check for expired mods and call to remove any found
	var mod_key = arg_mod[ID_MOD_KEY]
	var expiry_msec = arg_mod[ID_MOD_EXPIRY]
	assert(typeof(expiry_msec) == TYPE_INT)
	# negative values mean 'never expires'
	if (expiry_msec < 0):
		return false
	# otherwise the current Time(.get_ticks_msec) must be greater than
	#	the stored expiry msec or the modifier is expired
	elif (expiry_msec < arg_tickstamp):
		assert(typeof(mod_key) == TYPE_STRING)
		return true
	else:
		return false


# does NOT recalculate the current value after removing mods, make sure
#	to call _recalculate after using this method!
func _prune_mods(arg_prune_values: Array) -> void:
	for value in arg_prune_values:
		if value in _mods:
			_mods.erase(value)


# test if passed value is a valid mod or not
# used for verification in specific methods
func _is_valid_mod(arg_mod) -> bool:
	var is_dict := false
	var has_keys := false
	is_dict = typeof(arg_mod) == TYPE_DICTIONARY
	if is_dict:
		has_keys = arg_mod.has_all([ID_MOD_KEY, ID_MOD_TYPE, ID_MOD_VALUE, ID_MOD_EXPIRY])
	assert(is_dict)
	assert(has_keys)
	return is_dict and has_keys


#// calculates the _value based off of the base_value and active
#	modifiers. Is only called on get if any modifier is found to be expired,
#	otherwise the stored value is used.
# called with 'arg_log_steps' in public method 'calc_to_string'
func _recalculate(arg_log_steps: bool = false, arg_benchmark: bool = false) -> void:
	if arg_benchmark:
		GlobalLog.trace(self, "current time at recalculate call start = {0}".format([Time.get_ticks_msec()]))
	if arg_log_steps:
		GlobalLog.trace(self, "Logging _recalculate steps for {0}.{1}".format([
			str(owner), name
		]))
		GlobalLog.trace(self, "Base value is {0}".format([base_value]))
	
	var new_value = float(base_value)
	var mods_flat = find_all_mods(MODIFIER.FLAT)
	var mods_inc = find_all_mods(MODIFIER.INCREASED)
	var mods_more = find_all_mods(MODIFIER.MORE)
	
	if mods_flat.size() > 0:
		var fmod_total = 0.0
		for fmodifier in mods_flat:
			assert(_is_valid_mod(fmodifier))
			assert(typeof(fmodifier[ID_MOD_VALUE]) == TYPE_REAL)
			fmod_total += float(fmodifier[ID_MOD_VALUE])
			if arg_log_steps:
				GlobalLog.info(self, "flat mod '{0}' value {1}".format([
					fmodifier[ID_MOD_KEY], fmodifier[ID_MOD_VALUE]]))
		new_value += round(fmod_total)
		if arg_log_steps:
			GlobalLog.trace(self, "value after all flat mods (sum {0}) = {1}".format([
				fmod_total, new_value]))
	
	if mods_inc.size() > 0:
		var imod_total = 1.0
		for imodifier in mods_inc:
			assert(_is_valid_mod(imodifier))
			assert(typeof(imodifier[ID_MOD_VALUE]) == TYPE_REAL)
			imod_total += float(imodifier[ID_MOD_VALUE])
			if arg_log_steps:
				GlobalLog.info(self, "increased mod '{0}' value {1}".format([
					imodifier[ID_MOD_KEY], imodifier[ID_MOD_VALUE]]))
		new_value *= imod_total
		if arg_log_steps:
			GlobalLog.trace(self, "value after all increased mods (sum {0}) = {1}".format([
				imod_total, new_value]))
	
	if mods_more.size() > 0:
		for mmodifier in mods_more:
			assert(_is_valid_mod(mmodifier))
			assert(typeof(mmodifier[ID_MOD_VALUE]) == TYPE_REAL)
			new_value *= float(mmodifier[ID_MOD_VALUE])
			if arg_log_steps:
				GlobalLog.info(self, "increased mod '{0}' value {1}".format([
					mmodifier[ID_MOD_KEY], mmodifier[ID_MOD_VALUE]]))
				GlobalLog.info(self, "value after this more mod = {0}".format([new_value]))
	
	# apply
	self._value = float(new_value)

	if arg_log_steps:
		GlobalLog.trace(self, "Output final value is {0}".format([_value]))
	if arg_benchmark:
		GlobalLog.trace(self, "current time at recalculate call end = {0}".format([Time.get_ticks_msec()]))


# check owner exists/isn't null (with error logging)
func _validate_owner() -> bool:
	var owner_is_valid: bool = is_instance_valid(owner)
	# no default error logging on false as this is called on init/owner setter
	return owner_is_valid

