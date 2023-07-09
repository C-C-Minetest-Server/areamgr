local gui = flow.widgets
local S   = minetest.get_translator("areamgr")
local F   = minetest.formspec_escape

local function default_val(t,k,v)
	if not t[k] then t[k] = v end
	return t
end

local function fatalErrorGUI(errmsg,img)
	if type(errmsg) == "string" then
		errmsg = gui.Label {
			label = F(errmsg),
		}
	end
	if not img then img = "unknown_item.png" end
	return gui.VBox {
		w = 7,
		gui.HBox {
			gui.Image {
				w = 2, -- Optional
				h = 2, -- Optional
				texture_name = img,
			},
			errmsg,
		},
		gui.ButtonExit {
			w = 7,
			label = "Exit",
			expand=true, align_h="centre"
		}
	}
end

local function tableGarbageClean(t)
	for x,_ in pairs(t) do
		t[x] = nil
	end
end

local function toTab(tab)
	return function(player,ctx)
		ctx.tab = tab
		return true
	end
end


local main_gui = flow.make_gui(function(player, ctx)
	local name = player:get_player_name()
	if not ctx.areaid then
		return fatalErrorGUI(S("Area ID not given!"))
	end
	if not areas:isAreaOwner(ctx.areaid, name) then
		return fatalErrorGUI(S("This is not your area!"))
	end
	default_val(ctx,"tab","main")
	default_val(ctx,"history",{})
	local this = areas.areas[ctx.areaid]
	if not this then
		return fatalErrorGUI(S("The area does not exist!"))
	end
	if ctx.tab == "main" then
		local VBox = {}
		VBox.name  = "bodyscroll"
		VBox.h     = 7

		--## Name ##--
		table.insert(VBox,gui.HBox {
			gui.Label { label = S("Name: @1",this.name), expand = true, align_h = "left" },
			gui.Button {
				w = 1.2,
				label = S("Change"),
				align_v = "center",
				on_event = toTab("chg_name"),
			}
		})

		--## Owner ##--
		table.insert(VBox,gui.HBox {
			gui.Label { label = S("Owner: @1",this.owner), expand = true, align_h = "left" },
			gui.Button {
				w = 1.2,
				label = S("Change"),
				align_v = "center",
				on_event = toTab("chg_owner"),
			}
		})

		--## Parent Area ##--
		if this.parent then -- Parent Area
			local parent = areas.areas[this.parent]
			if parent then
				if areas:isAreaOwner(this.parent, name) then
					table.insert(VBox,gui.HBox {
						gui.Label { label = S("Parent:"), align_v = "top" },
						gui.VBox {
							gui.Label { label = parent.name },
							gui.Label { label = S("#@1 (Owned by @2)",this.parent,parent.owner) },
							expand = true, align_h = "left"
						},
						gui.Button {
							w = 1,
							label = S("Edit"),
							on_event = function(player,ctx)
								table.insert(ctx.history,ctx.areaid)
								ctx.areaid = this.parent
								return true
							end,
							align_v = "center",
						}
					})
				else
					table.insert(VBox,gui.Label { label = S("Parent: #@1 (Owned by @2)",this.parent,parent.owner) })
				end
			else
				table.insert(VBox,gui.Label { label = S("Parent: #@1 (ERROR! Parent has gone!)",this.parent) })
			end
		else
			table.insert(VBox,gui.Label { label = S("Parent: None") })
		end

		--## Children ##--
		local children = areas:getChildren(ctx.areaid)
		if #children > 0 then
			local ChildernVBox = {}
			for _,cid in ipairs(children) do
				local cdata = areas.areas[cid]
				table.insert(ChildernVBox,gui.HBox {
					gui.VBox {
						gui.Label { label = cdata.name },
						gui.Label { label = S("#@1 (Owned by @2)",cid,cdata.owner) },
						expand = true, align_h = "left"
					},
					gui.Button {
						w = 1,
						h = 0.7,
						label = S("Edit"),
						on_event = function(player,ctx)
							table.insert(ctx.history,ctx.areaid)
							ctx.areaid = cid
							return true
						end,
						align_v = "center"
					}
				})
			end
			table.insert(VBox,gui.HBox {
				gui.label {label = S("Childern:"), align_v = "top" },
				gui.VBox(ChildernVBox)
			})
		else
			table.insert(VBox,gui.label {label = S("Childern: None") })
		end

		--# Main VBox #--
		return gui.VBox({
			min_w = 8,
			min_h = 7,
			gui.HBox { -- Navbar
				gui.Button {
					w = 0.7,
					h = 0.7,
					name = "back",
					label = #ctx.history > 0 and "<" or "@",
					on_event = function(player, ctx)
						if #ctx.history ~= 0 then
							ctx.areaid = ctx.history[#ctx.history]
							table.remove(ctx.history,#ctx.history)
							return true
						end
					end,
				},
				gui.Label { label = S("Managing Area #@1: @2",ctx.areaid,this.name), expand = true, align_h = "left" },
				gui.ButtonExit {
					w = 0.7,
					h = 0.7,
					label = "x",
					on_event = function(player,ctx)
						tableGarbageClean(ctx)
						return false
					end,
				},
			},
			gui.ScrollableVBox(VBox)
		})
	end
end)

minetest.register_chatcommand("areamgr",{
	description = S("GUI to manage area protections"),
	params = "<areaID>",
	privs = {[areas.config.self_protection_privilege]=true},
	func = function(name,param)
		local areaid = tonumber(param)
		if not areaid then
			return false, S("Area ID not given!")
		end
		main_gui:show(name,{areaid=areaid})
		return true, S("Formspec shown.")
	end
})

