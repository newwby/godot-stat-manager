
# Stat Manager
## Overview
The StatManager module is a decoupled part of the DDAT-GPF framework that anyone can use.

It allows the developer to replicate the statistic modifier system of the popular action-RPG 'Path of Exile'. Temporary or permanent modifiers can be stored to adjust the final value of any float (or int) property.

These modifiers are always one of three types:
* '**Flat**' modifiers which add directly to the base value
* '**Increased**' modifiers, which sum together and then multiply the base+flat by the combined sum
* '**More**' modifiers, which multiply the current value (including any previous 'more' multipliers).

Whilst ARPG or PoE players will be familiar with how these types of modifiers interact

# Contents and Setup

```
autoload/global_stat.gd
classes/stat.gd
classes/stat_logger.gd
tests/stat_tests.gd
tests/stat_tests.tscn
```

## Autoload
You should load the file '**autoload/global_stat.gd**' as a singleton in the 'autoload' tab of your ProjectSettings (make sure to enable the 'Global Variable' checkbox).

## Classes
'**Stat.gd**' contains the 'Stat' class, where logic and data for each adjusted property is stored.

'**Stat_logger.gd**' contains a lightweight implementation of the ddat-gpf GlobalLog module. It exists as an interface between stat.gd/global_stat.gd and the logger, defaulting to printing logs to console if it can't find the GlobalLog module. This class was key to decoupling this stat manager from the ddat-gpf framework.

## Tests

'**stat_tests.tscn**' contains the unit tests for stat.gd/global_stat.gd behaviour.

If you make changes to either file you should check these tests before using your changes.

### Test Setup
On loading stat_tests.tscn for the first time you may need to configure the tests.

* You may need to reattach the stat_tests.gd file to the scene if your absolute path varies from the default
* You may need to change the local path of the '**GlobalStatTest**' property to point toward 'autoload/global_stat.gd' if your absolute path varies from the default.

---

## Version 1.0
+ This version currently only supports Godot 3.5 but you are welcome to revise it for future Godot versions.
+ You are also welcome to duplicate this code under any other engine in any other language, the logic is reasonably simple to replicate.
+ As this repository is distributed under the MIT license, you are permitted to use, copy, modify, merge, publish, distribute, sublicense, or even sell, copies of this code as you wish.

## Future Plans
- Several features didn't make it into the initial release but will be added in time. Please check the issues tab ('planned features' under issue #1) of the repository to see current development progress.
- You can also use the issues tab of the repository to report bugs and suggest features or revisions you'd like to be a part of the stat system.

---

# Usage

There are two supported ways to use the StatManager module. The first more directly uses the Stat class, and the second utilises the GlobalStat API. Each has benefits and drawbacks so you should consider which is better for your workflow.

## Object-oriented method

You can directly use Stats as variants in your owner object, adjusting the setters of these variants so they return the 'get_int' or 'get_real' method from the stat instead of the stat itself.

**e.g.**
```
# Create a property with a float value
# Create a second property with a Stat value; initailise said Stat with the property value
# Create  a setter and getter
var speed := 50.0 setget set_speed, get_speed
var speed_stat = Stat.new(self, "speed", speed)

# getter that returns either the get_int() or get_real() method of the Stat
func get_speed() -> float:
  return speed.get_real()

# setter that updates the stat base value if the property is directly adjusted
func set_speed(arg_value: float) -> void:
  speed = arg_value
  if is_instance_valid(speed_stat):
    speed_stat.base_value = arg_value

```

**Pro**
+ Can call stat methods directly within the owning script
+ Low mental overhead, once set up you just call the property as normal to get the value

**Con**
- Cannot access stat object outside of the owning script (unless you use a secondary property/variant and getter to return get_int/get_real rather than the variant holding the Stat object)
- Owner and stat must be correctly scoped or passed in order to get the value
- Setter/getter setup required, and two properties required per property you wish to track with a Stat

## API method

You can alternatively use the GlobalStat singleton (once set as autoload, see the 'contents' section of this readme) to reference and keep track of stats

**e.g.**
```
# how to reference anywhere in your project

GlobalStat.get_real(owner, "speed") # returns float to do stuff

# how to initialise and use within local scope

var speed := 50.0

func _init(<args>) -> void:
  GlobalStat.add(self, "speed", speed) # initialises Stat, make sure to call this before trying to find stat

func get_speed() -> float:
  if GlobalStat.has(self, "speed"):
    return GlobalStat.get_real(self, "speed")
  else:
    return speed

func set_speed(arg_value: float) -> void:
  speed = arg_value
  if GlobalStat.has(self, "speed"):
    GlobalStat.update_base_value(self, "speed", arg_value)

# In Godot 3.5 make sure you are calling the setter to utilise the above example
e.g.
  var _get_speed = self.speed
_not_
  var _get_speed = speed

```

**Pro**
+ Can access any Stat through the GlobalStat singleton from anywhere in your project
+ Access to all Stat class methods through the API methods

**Con**
- You have to specify the lookup (owner, name) in every API method as the first two arguments. This is an additional amount of argument specifying that introduces more room for human error.
- You still have to modify getters if you wish the default property to return the modified Stat value
- Calling the Stat value requires being sure the Stat exists (use GlobalStat.has()) before anyone tries to reference it

