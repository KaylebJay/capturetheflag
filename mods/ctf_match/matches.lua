ctf.register_on_init(function()
	ctf._set("match",                    false)
	ctf._set("match.destroy_team",       false)
	ctf._set("match.break_alliances",    true)
	ctf._set("match.teams",              "")
	ctf._set("match.clear_inv",          false)
end)

-- Load next match. May be overrided
function ctf_match.next()
	ctf.reset()
	-- Note: ctf.reset calls register_on_new_game, below.
end

-- Check for winner
function ctf_match.check_for_winner()
	local winner
	for name, team in pairs(ctf.teams) do
		if winner then
			return
		end
		winner = name
	end

	-- There is a winner!
	ctf.action("match", winner .. " won!")
	minetest.chat_send_all("Team " .. winner .. " won!")
	if ctf.setting("match") then
		ctf_match.next()
	end
end

ctf.register_on_new_game(function()
	local function safe_place(pos, node)
		ctf.log("match", "attempting to place...")
		minetest.get_voxel_manip(pos, { x = pos.x + 1, y = pos.y + 1, z = pos.z + 1})
		minetest.set_node(pos, node)
		if minetest.get_node(pos).name ~= node.name then
			ctf.error("match", "failed to place node, retrying...")
			minetest.after(0.5, function()
				safe_place(pos, node)
			end)
		end
	end

	local teams = ctf.setting("match.teams")
	if teams:trim() == "" then
		return
	end
	ctf.log("match", "Setting up new game!")

	teams = teams:split(";")
	local pos = {}
	for i, v in pairs(teams) do
		local team = v:split(",")
		if #team == 5 then
			local name  = team[1]:trim()
			local color = team[2]:trim()
			local x     = tonumber(team[3]:trim())
			local y     = tonumber(team[4]:trim())
			local z     = tonumber(team[5]:trim())
			pos[name] = {
				x = x,
				y = y,
				z = z
			}

			ctf.team({
				name     = name,
				color    = color,
				add_team = true
			})

			ctf_flag.add(name, pos[name])
		else
			ctf.warning("match", "Invalid team setup: " .. dump(v))
		end
	end

	minetest.after(0, function()
		for name, flag in pairs(pos) do
			safe_place(flag, {name = "ctf_flag:flag"})
			ctf_flag.update(flag)
			local function base_at(flag, dx, dz)
				safe_place({
					x = flag.x + dx,
					y = flag.y - 1,
					z = flag.z + dz,
				}, { name = "ctf_flag:ind_base"})
			end
			base_at(flag, -1, -1)
			base_at(flag, -1,  0)
			base_at(flag, -1,  1)
			base_at(flag,  0, -1)
			base_at(flag,  0,  0)
			base_at(flag,  0,  1)
			base_at(flag,  1, -1)
			base_at(flag,  1,  0)
			base_at(flag,  1,  1)
		end
	end)

	for i, player in pairs(minetest.get_connected_players()) do
		local name       = player:get_player_name()
		local alloc_mode = tonumber(ctf.setting("allocate_mode"))
		local team       = ctf.autoalloc(name, alloc_mode)

		if alloc_mode ~= 0 and team then
			ctf.log("autoalloc", name .. " was allocated to " .. team)
			ctf.join(name, team)
		end

		ctf.move_to_spawn(name)

		if ctf.setting("match.clear_inv") then
			local inv = player:get_inventory()
			inv:set_list("main", {})
			inv:set_list("craft", {})
			give_initial_stuff(player)
		end

		player:set_hp(20)
	end
	minetest.chat_send_all("Next round!")
end)

ctf_flag.register_on_capture(function(attname, flag)
	if not ctf.setting("match.destroy_team") then
		return
	end

	local fl_team = ctf.team(flag.team)
	if fl_team and #fl_team.flags == 0 then
		ctf.action("match", flag.team .. " was defeated.")
		ctf.remove_team(flag.team)
		minetest.chat_send_all(flag.team .. " has been defeated!")
	end

	ctf_match.check_for_winner()
end)
