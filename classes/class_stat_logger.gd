extends Node

class_name StatLogger

##############################################################################

# Utility for GlobalStat autoload and Stat class to use to log
# Normally would use the inbuilt DDAT-GPF.core GlobalLog functionality, but
#	would rather not have a DDAT-GPF dependency. Instead this static class
#	serves as an interface to log through DDAT-GPF.core if it is present,
#	and through default print to console behaviour if it isn't.

# This class is a lightweight version of the DDAT-GPF.core GlobalLog module,
#	so if you like what this is doing consider checking out the full version
#	for free at https://github.com/newwby/ddat-gpf.core
# Other features in the full version include
#	- log time tracking
#	- asynchronous logging
#	- logging to disk
#	- configurable logging permissions

##############################################################################

# properties

##############################################################################

# virtual methods

##############################################################################

# public


static func error(arg_log_caller: Object, arg_log_string: String):
	_log(arg_log_caller, arg_log_string, "error")


# access method
static func info(arg_log_caller: Object, arg_log_string: String):
	_log(arg_log_caller, arg_log_string, "info")


static func warning(arg_log_caller: Object, arg_log_string: String):
	_log(arg_log_caller, arg_log_string, "warning")


##############################################################################

# private


# check if the GlobalLog singleton is loaded and correctly specified
static func _get_ddat_gpf_logger():
	return Engine.get_main_loop().root.get_node("GlobalLog")


# actual logger method, but do not call directly
static func _log(arg_log_caller: Object, arg_log_string: String, arg_log_type: String) -> void:
	# check if can use GlobalLog (part of the DDAT-GPF)
	var ddat_logger = _get_ddat_gpf_logger()
	if ddat_logger != null:
		if ddat_logger.has_method(arg_log_type):
			ddat_logger.call(arg_log_type, arg_log_caller, arg_log_string)
			return
	# if cannot
	var full_log_string = "{0} | StatLogger.{1}: {2}".format([arg_log_caller, arg_log_type.to_upper(), arg_log_string])
	match arg_log_type:
		# debugger errors
		"error":
			push_error(full_log_string)
		# debugger warnings
		"warning":
			push_warning(full_log_string)
		# any other
		_:
			print(full_log_string)

