extends Node

#class_name Name

var GlobalStatTest = preload("res://src/_game/autoload/global_stat.gd").new()

##############################################################################

##############################################################################

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

##############################################################################

# classes


class TestEntity:
	var speed: int = 25
	var damage: int = 40
	var life: float = 100.0


##############################################################################

# virt


# Called when the node enters the scene tree for the first time.
func _ready():
	
	# test structure and optional arg
	var test_output := {
	}
	var log_verbose := true
	
	# run tests
#	test0_logger_tests()
	test_output[1] = test1_api_basic_function(log_verbose)
	test_output[2] = test2_class_basic_function(log_verbose)
	test_output[3] = yield(test3_mods_can_expire(log_verbose), "completed")
	test_output[4] = yield(test4_mod_continuity(log_verbose), "completed")
	test_output[5] = test5_remove_mod(log_verbose)
	test_output[6] = test6_change_mod(log_verbose)
	test_output[7] = test7_change_mod_name(log_verbose)
	test_output[8] = yield(test8_update_mod_duration(log_verbose), "completed")
	
	# results
	print("\n---------------\n\n{0}\n".format([str(test_output)]))
	var total_output := true
	if test_output.empty() == false:
		for value in test_output.values():
			if value != true:
				total_output = false
	var outcome_string := "ALL TESTS PASSED" if total_output else "AT LEAST ONE TEST FAILED!!"
	print(outcome_string)
	print("\n---------------\n")


# force call/debugging test functions only, do not run as part of test suite
func test0_logger_tests() -> void:
	# do not enable these normally
	StatLogger.error(self, "test error")
	StatLogger.info(self, "test log")
	StatLogger.warning(self, "test warning")


func test1_api_basic_function(arg_verbose: bool = false) -> bool:
	print("\n---------------\n### new test; test1 ###\n")
	var subject_test = TestEntity.new()
	# initialise data
	var base_value = subject_test.speed
	GlobalStatTest.add(subject_test, "speed", base_value)
	var data_file = GlobalStatTest.find(subject_test, "speed")
	if not data_file is Stat:
		print("data file error")
		return false
	# add mods
	var mod_id_1 := "test_mod1_+50"
	var mod_id_2 := "test_mod2_+100%"
	var mod_id_3 := "test_mod3_*1.5"
	var mod_value_1 := 50
	var mod_value_2 := 1.0
	var mod_value_3 := 1.5
	GlobalStatTest.apply_mod_flat(subject_test, "speed", mod_id_1, mod_value_1)
	GlobalStatTest.apply_mod_inc(subject_test, "speed", mod_id_2, mod_value_2)
	GlobalStatTest.apply_mod_more(subject_test, "speed", mod_id_3, mod_value_3)
	var mod_lookup = GlobalStatTest.mod_value(subject_test, "speed", mod_id_2)
	var mod_lookup_test: bool = (mod_value_2 == mod_lookup)
	if arg_verbose:
		print("looking up mod '{0}'; value expected {1}, value is {2}; success = {3}".format([
				mod_id_2, mod_value_2, mod_lookup, mod_lookup_test]))
#	mod_value
	# get result
	var test_output = GlobalStatTest.get_real(subject_test, "speed")
	if arg_verbose:
		print("\nperforming sum test...\nbase_value = {0} \nmodified_value = {1} \ndata = {2}".format([\
			subject_test.speed,
			test_output,
			data_file.data_to_string()
			]))
	if arg_verbose:
		print("current GlobalStats.stats:\n{0}".format([GlobalStatTest.stats]))
	var expected_value = (((base_value+mod_value_1)*(1.0+mod_value_2))*mod_value_3)
	if (test_output == expected_value) and mod_lookup_test:
		print("\ntest success!\n{0}\n{1}".format([
			"sum output {0}".format([str([test_output])]),
			"comparison output {0}".format([mod_lookup_test])
		]))
		return true
	else:
		print("\ntest failure!\n{0}\n{1}".format([
			"sum output {0}; expected {1}".format([str([test_output, expected_value])]),
			"comparison output {0}; expected true".format([mod_lookup_test])
		]))
		return false
#	print("\n###test ended###\n")


# further calculation test focusing on Stat as a separate mod
func test2_class_basic_function(arg_verbose: bool = false) -> bool:
	print("\n---------------\n### new test; test2 ###\n")
	var subject_test = TestEntity.new()
	var new_speed_data = Stat.new(subject_test, "speed", subject_test.speed)
	if arg_verbose:
		print(new_speed_data.data_to_string())
		print("\nApplying Flat Mods")
	new_speed_data.apply_mod(Stat.MODIFIER.FLAT, "+30", 30)
	new_speed_data.apply_mod(Stat.MODIFIER.FLAT, "-15", -15)
	if arg_verbose:
		print(new_speed_data.data_to_string())
		print("\nApplying Increased Mods")
	new_speed_data.apply_mod(Stat.MODIFIER.INCREASED, "+120%", 1.2)
	new_speed_data.apply_mod(Stat.MODIFIER.INCREASED, "+40%", 0.4)
	new_speed_data.apply_mod(Stat.MODIFIER.INCREASED, "-50%", -0.5)
	if arg_verbose:
		print(new_speed_data.data_to_string())
		print("\nApplying More Mods")
	new_speed_data.apply_mod(Stat.MODIFIER.MORE, "x3", 3.0)
	new_speed_data.apply_mod(Stat.MODIFIER.MORE, "/2", 0.5)
	var test_output = new_speed_data.get_real()
	if arg_verbose:
		print(new_speed_data.data_to_string())
		print("\n Beginning recalculation \n")
		new_speed_data.calc_to_logs()
	if test_output == 126.0:
		print("test success!")
		return true
	else:
		print("test failure! output {0}".format([str([test_output])]))
		return false
#	print("\n###test ended###\n")


func test3_mods_can_expire(arg_verbose: bool = false) -> bool:
	print("\n---------------\n### new test; test3 ###\n")
	var timer_node := Timer.new()
	timer_node.autostart = false
	timer_node.one_shot = true
	self.call_deferred("add_child", timer_node)
	yield(timer_node, "tree_entered")
	
	var subject_test = TestEntity.new()
	GlobalStatTest.add(subject_test, "speed", subject_test.speed)
	
	# test on a mod expiring (rechecking to see if it isn't there)
	var msec_duration = 1200
	var expected_expiry = Time.get_ticks_msec()+msec_duration
	var mod_id := "test_mod1"
	GlobalStatTest.apply_mod_flat(subject_test, "speed", mod_id, 35, msec_duration)
	# get result
	if arg_verbose:
		print("\nlogging result after 0s")
		print("current time = ", Time.get_ticks_msec())
	var pretest_output = GlobalStatTest.get_real(subject_test, "speed", arg_verbose)
	if arg_verbose:
		print("value before time = {0}".format([pretest_output]))
		print("current GlobalStats.stats:\n{0}".format([GlobalStatTest.stats]))
	# wait
	# comparing engine milliseconds to timer seconds is inaccurate
	# (due to timer checks being locked; see timer docs)
	# so we're going to loop until done, with a breakout of 100
	var expired := false
	var iteration := 0
	var breakout := 200
	var actual_expiry = 0
	print() # separate line
	while expired == false:
		iteration += 1
		timer_node.start(0.05)
		yield(timer_node, "timeout")
		var result = GlobalStatTest.get_real(subject_test, "speed")
		if arg_verbose:
			if GlobalStatTest.has_mod(subject_test, "speed", mod_id):
				print("mod '{0}' remaining ticks: {1}".format([mod_id, GlobalStatTest.remaining(subject_test, "speed", mod_id)]))
		if result == 25:
			actual_expiry = Time.get_ticks_msec()
			expired = true
		if iteration >= breakout:
			break
	if expired and arg_verbose:
		print("\nIt took {0}s to expire on {1}msec".format([iteration*0.05, msec_duration]))
		print("Expected expiry was {0}, actual expiry was {1}".format([expected_expiry, actual_expiry]))
	# always print failure condition even if not verbose logging
	else:
		print("\nexpiry test iteration breakout, test failure")
		return false
	# recheck result
	if arg_verbose:
		print("\nlogging result after 1s")
		print("current time = ", Time.get_ticks_msec())
	var post_output = GlobalStatTest.get_real(subject_test, "speed", arg_verbose)
	if arg_verbose:
		print("value before time = {0}".format([post_output]))
		print("current GlobalStats.stats:\n{0}".format([GlobalStatTest.stats]))
	
	if pretest_output == 60\
	and post_output == 25:
		print("test success!")
		return true
	else:
		print("test failure! output {0}".format([str([pretest_output, post_output])]))
		return false
#	print("\n###test ended###\n")


func test4_mod_continuity(arg_verbose: bool = false) -> bool:
	print("\n---------------\n### new test; test4 ###\n")
	var timer_node := Timer.new()
	timer_node.autostart = false
	timer_node.one_shot = true
	self.call_deferred("add_child", timer_node)
	yield(timer_node, "tree_entered")
	
	var subject_test = TestEntity.new()
	GlobalStatTest.add(subject_test, "speed", subject_test.speed)
	var current_time := 0
	
	var initial_wait := 1.2
	var secondary_wait := 0.4
	
	# test on a mod still being present close to expiring and whether it
	#	is still there after it should expire (rechecking to see if it isn't there)
	GlobalStatTest.apply_mod_inc(subject_test, "speed", "test_mod1", 1.0, 1250)
	# get result
	print()
	current_time = Time.get_ticks_msec()
	var pretest_output = GlobalStatTest.get_real(subject_test, "speed", arg_verbose)
	if arg_verbose:
		print("\nlogging result after 0s")
		print("current time = {0} | value at time = {1}".format([current_time, pretest_output]))
	# wait
	timer_node.start(initial_wait)
	yield(timer_node, "timeout")
	# recheck result
	print()
	current_time = Time.get_ticks_msec()
	var mid_output = GlobalStatTest.get_real(subject_test, "speed", arg_verbose)
	if arg_verbose:
		print("\nlogging result after {0}s".format([initial_wait]))
		print("current time = {0} | value at time = {1}".format([current_time, mid_output]))
	# wait
	# requires a slight extra delay due to timer/Time.get_msec inconsistency
	timer_node.start(secondary_wait)
	yield(timer_node, "timeout")
	# recheck result
	print()
	current_time = Time.get_ticks_msec()
	var post_output = GlobalStatTest.get_real(subject_test, "speed", arg_verbose)
	if arg_verbose:
		print("\nlogging result after {0}s (total {1}s)".format([secondary_wait, (initial_wait+secondary_wait)]))
		print("current time = {0} | value at time = {1}".format([current_time, post_output]))
	
	print()
	if pretest_output == 50\
	and mid_output == 50\
	and post_output == 25:
		print("test success!")
		return true
	else:
		print("test failure! output {0}".format([str([pretest_output, mid_output, post_output])]))
		return false
#	print("\n###test ended###\n")


# further calculation test focusing on Stat as a separate mod
func test5_remove_mod(arg_verbose: bool = false) -> bool:
	print("\n---------------\n### new test; test5 ###\n")
	# setup
	var subject_test = TestEntity.new()
	var test_mod_name := "x2.2_testmod"
	var multiplier := 2.2
	var base_value = subject_test.damage
	var new_damage_data = Stat.new(subject_test, "damage", base_value)
	
	# step 1; add mod
	if arg_verbose:
		print(new_damage_data.data_to_string())
		print("\nApplying More Mod '{0}'\n".format([test_mod_name]))
	new_damage_data.apply_mod(Stat.MODIFIER.MORE, test_mod_name, multiplier)
	var test_output_1 = new_damage_data.get_real()
	
	# step 2; remove mod
	new_damage_data.remove_mod(test_mod_name)
	if arg_verbose:
		print(new_damage_data.data_to_string())
		print("\nRemoved test mod '{0}'\n".format([test_mod_name]))
	var test_output_2 = new_damage_data.get_real()
	
	# check result
	if (test_output_1 == (base_value*multiplier)) and (test_output_2 == base_value):
		print("test success!")
		return true
	else:
		print("test failure! output {0}".format([str([test_output_1, test_output_2])]))
		return false


# further calculation test focusing on Stat as a separate mod
func test6_change_mod(arg_verbose: bool = false) -> bool:
	print("\n---------------\n### new test; test6 ###\n")
	# setup
	var subject_test = TestEntity.new()
	var test_mod_name := "+80%_then+50%_testmod"
	var initial_boost := 0.8
	var updated_boost := 0.5
	var base_value = subject_test.damage
	var new_damage_data = Stat.new(subject_test, "damage", base_value)
	
	# step 1; add mod
	new_damage_data.apply_mod(Stat.MODIFIER.INCREASED, test_mod_name, initial_boost)
	if arg_verbose:
		print("\nApplied Inc Mod '{0}'\n".format([test_mod_name]))
		print(new_damage_data.data_to_string())
	var test_output_1 = new_damage_data.get_real()
	
	# step 2; remove mod
	new_damage_data.update_mod_value(test_mod_name, updated_boost)
	if arg_verbose:
		print("\nUpdated test mod '{0}' from +{1}% to +{2}%\n".\
				format([test_mod_name, initial_boost, updated_boost]))
		print(new_damage_data.data_to_string())
	var test_output_2 = new_damage_data.get_real()
	
	# check result
	if (test_output_1 == (base_value*(1.0+initial_boost))) and (test_output_2 == (base_value*(1.0+updated_boost))):
		print("test success!")
		return true
	else:
		print("test failure! output {0}".format([str([test_output_1, test_output_2])]))
		return false


# test to check if a mod successfully renames
func test7_change_mod_name(arg_verbose: bool = false) -> bool:
	print("\n---------------\n### new test; test7 ###\n")
	# setup
	var subject_test = TestEntity.new()
	var test_mod_name_1 := "original name"
	var test_mod_name_2 := "rewritten name"
	var base_value = subject_test.life
	var mod_value := 50
	var new_life_data = Stat.new(subject_test, "life", base_value)
	new_life_data.apply_mod(Stat.MODIFIER.FLAT, test_mod_name_1, mod_value)
	
	# comparison 1
	var has_mod_1 = new_life_data.has_mod(test_mod_name_1)
	var has_mod_2 = new_life_data.has_mod(test_mod_name_2)
	var outcome_1 = (has_mod_1 == true) and (has_mod_2 == false)
	if arg_verbose:
		print("at step comparison 1 output is {0} so outcome is {1}".format([str([has_mod_1, has_mod_2]), outcome_1]))
	
	# change
	new_life_data.rename_mod(test_mod_name_1, test_mod_name_2)
	
	# comparison 2
	has_mod_1 = new_life_data.has_mod(test_mod_name_1)
	has_mod_2 = new_life_data.has_mod(test_mod_name_2)
	var outcome_2 = (has_mod_1 == false) and (has_mod_2 == true)
	if arg_verbose:
		print("at step comparison 2 output is {0} so outcome is {1}".format([str([has_mod_1, has_mod_2]), outcome_2]))
	
	# check result
	if outcome_1 and outcome_2:
		print("test success!")
		return true
	else:
		print("test failure! output {0} but expected [true, true]".format([str([outcome_1, outcome_2])]))
		return false


#//TODO
# test to have infinite mod, wait 2 seconds, call value, then update it to
#	expire in 1s, wait a further 1s, then call value again
func test8_update_mod_duration(arg_verbose: bool = false) -> bool:
	print("\n---------------\n### new test; test8 ###\n")
	# setup
	var timer_node := Timer.new()
	timer_node.autostart = false
	timer_node.one_shot = true
	self.call_deferred("add_child", timer_node)
	yield(timer_node, "tree_entered")
	
	var subject_test = TestEntity.new()
	var base_value = subject_test.life
	var mod_name = "life_mod_test_x1.75"
	var mod_multiplier := 1.75
	GlobalStatTest.add(subject_test, "life", base_value)
	GlobalStatTest.apply_mod_more(subject_test, "life", mod_name, mod_multiplier)
	
	var initial_wait_duration := 1.5
	var secondary_wait_duration := 0.5
	
	# wait
	timer_node.start(initial_wait_duration)
	yield(timer_node, "timeout")
	
	# comparison 1
	print()
	var outcome_step_1 := false
	var mod_value_at_step_1 = GlobalStatTest.get_real(subject_test, "life", arg_verbose)
	var expected_at_step_1 = (base_value*mod_multiplier)
	outcome_step_1 = (mod_value_at_step_1 == (expected_at_step_1))
	if arg_verbose:
		print("\ntest outcome step 1 = {0}, value was {1} and expected was {2}".\
				format([outcome_step_1, mod_value_at_step_1, expected_at_step_1]))
	
	# change duration to basically immediately finish
	GlobalStatTest.update_mod_duration(subject_test, "life", mod_name, 1)
	# wait
	timer_node.start(secondary_wait_duration)
	yield(timer_node, "timeout")
	
	# comparison 2
	print()
	var outcome_step_2 := false
	var mod_value_at_step_2 = GlobalStatTest.get_real(subject_test, "life", arg_verbose)
	var expected_at_step_2 = (base_value)
	outcome_step_2 = (mod_value_at_step_2 == expected_at_step_2)
	if arg_verbose:
		print("\ntest outcome step 2 = {0}, value was {1} and expected was {2}".\
				format([outcome_step_2, mod_value_at_step_2, expected_at_step_2]))
	
	# check result
	if outcome_step_1 and outcome_step_2:
		print("test success!")
		return true
	else:
		print("test failure! output {0} but expected [true, true]".format([str([outcome_step_1, outcome_step_2])]))
		return false


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


##############################################################################

# public

##############################################################################

# private

