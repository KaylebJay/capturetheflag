ctf.register_on_init(function()
	ctf._set("match.map_reset_limit",    0)
end)

local old = ctf_match.next
function ctf_match.next()
	local r = ctf.setting("match.map_reset_limit")
	if r > 0 then
		minetest.chat_send_all("Resetting the map, this may take a few moments...")
		minetest.after(0.5, function()
			minetest.delete_area(vector.new(-r, -r, -r), vector.new(r, r, r))

			minetest.after(1, function()
				old()
			end)
		end)
	else
		old()
	end
end
