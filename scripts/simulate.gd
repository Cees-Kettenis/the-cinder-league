extends SceneTree

const Data = preload("res://scripts/data.gd")
const Simulator = preload("res://scripts/simulator.gd")

func _initialize() -> void:
	var args := {}
	for argument in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", false, 1)
		if pair.size() == 2:
			args[pair[0]] = pair[1]
		elif pair.size() == 1:
			args[pair[0]] = true
	if args.has("help"):
		print("Use --campaign or --left=weapon --right=mage. Extra options: --level=4 --seed=42 --bouts=10 --balance=/path/balance.json --scenario=/path/fighters.json")
		quit()
		return
	var data := Data.new()
	var balance_path := str(args.get("balance", Data.DEFAULT_FILE))
	var error := data.load_profile(balance_path)
	if not error.is_empty():
		printerr(error)
		quit(1)
		return
	var simulator := Simulator.new(data)
	var left := str(args.get("left", "weapon"))
	var right := str(args.get("right", "mage"))
	if left not in Simulator.STYLES or right not in Simulator.STYLES:
		printerr("Unknown style. Choose from " + ", ".join(Simulator.STYLES))
		quit(1)
		return
	var options: Dictionary = {}
	if args.has("scenario"):
		var read = JSON.parse_string(FileAccess.get_file_as_string(str(args.scenario)))
		if not read is Dictionary:
			printerr("Scenario must be a readable JSON object.")
			quit(1)
			return
		options = read
	var seed_value := int(args.get("seed", 42))
	var result := simulator.campaign(left, seed_value, clampi(int(args.get("bouts", 40)), 1, 10000)) if args.has("campaign") else simulator.batch(
		left, right, clampi(int(args.get("level", data.rules.arena_caps.front())), 1, data.max_level()),
		seed_value, clampi(int(args.get("bouts", 10)), 1, 10000), options
	)
	print(JSON.stringify(result, "  "))
	quit(1 if result.has("error") else 0)
