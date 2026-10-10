class_name PlayerControls
extends RefCounted

# Each runner owns its own action namespace. A later local/co-op player can bind
# a different device without sharing inventory, input state or Camera2D.
const ACTIONS = ["move_left", "move_right", "jump", "attack_a", "attack_b", "dodge", "heal", "skill"]
var player_index = 0
var device_id = -1
var keyboard_enabled = true

func action_name(action: String) -> String:
	return "%s_player_%d" % [action, player_index]

func sync_bindings() -> void:
	for action in ACTIONS:
		var local = action_name(action)
		if not InputMap.has_action(local): InputMap.add_action(local, 0.22)
		InputMap.action_erase_events(local)
		for source in InputMap.action_get_events(action):
			if source is InputEventKey and not keyboard_enabled: continue
			var event: InputEvent = source.duplicate()
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				event.device = device_id
			InputMap.action_add_event(local, event)

func axis() -> float:
	return Input.get_axis(action_name("move_left"), action_name("move_right"))

func pressed(action: String) -> bool:
	return Input.is_action_just_pressed(action_name(action))

func released(action: String) -> bool:
	return Input.is_action_just_released(action_name(action))
