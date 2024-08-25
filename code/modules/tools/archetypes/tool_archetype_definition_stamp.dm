/decl/tool_archetype/stamp
	name         = "stamp"
	tool_message = "stamping"
	tool_sound   = 'sound/effects/stamp.ogg'
	properties   = list(
		TOOL_PROP_COLOR           = "black",
		TOOL_PROP_COLOR_NAME      = "black",
		TOOL_PROP_STAMP_ICON      = "",
		TOOL_PROP_USES            = TOOL_USES_INFINITE,
		)

///Returns a positive value if there are uses left after decrementing, or 0 if there's nothing left afterwards. Doesn't validate if there's enough uses lefts!
/decl/tool_archetype/stamp/proc/decrement_uses(mob/user, obj/item/tool, decrement = 1)
	. = tool.get_tool_property(TOOL_STAMP, TOOL_PROP_USES)
	if(. == TOOL_USES_INFINITE)
		return TRUE //If negative value, we have infinite uses! Don't change the value!
	. = max(. - decrement, 0)
	tool.set_tool_property(TOOL_STAMP, TOOL_PROP_USES, .)

/decl/tool_archetype/stamp/can_use_tool(obj/item/tool, expend_fuel = 1)
	var/uses = tool.get_tool_property(TOOL_STAMP, TOOL_PROP_USES)
	return ..() && ((uses == TOOL_USES_INFINITE) || (uses - expend_fuel) >= 0) //Return true if we have infinite "fuel" or if we can cover the "fuel" cost

/decl/tool_archetype/stamp/handle_pre_interaction(mob/user, obj/item/tool, expend_fuel = 1)
	var/uses_left = tool.get_tool_property(TOOL_STAMP, TOOL_PROP_USES)
	//Check if we have infinite uses amount
	if(uses_left == TOOL_USES_INFINITE)
		return TOOL_USE_SUCCESS
	//Check if we can spare at least the ink uses expended.
	if((uses_left - expend_fuel) < 0)
		to_chat(user, SPAN_WARNING("\The [tool] is dry!"))
		return TOOL_USE_FAILURE
	return TOOL_USE_SUCCESS

/decl/tool_archetype/stamp/handle_post_interaction(mob/user, obj/item/tool, expend_fuel = 1)
	if(decrement_uses(user, tool, expend_fuel) <= 0)
		to_chat(user, SPAN_WARNING("\The [tool] has dried up!"))
	return TOOL_USE_SUCCESS
