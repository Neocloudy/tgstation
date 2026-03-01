/*!
 * External tgui definitions, such as src_object APIs.
 *
 * Copyright (c) 2020 Aleksej Komarov
 * SPDX-License-Identifier: MIT
 */

/**
 * Used to open and update UIs on demand.
 * If this proc is not implemented properly, the UI will not update correctly.
 *
 * Arguments:
 * * `user`—The mob who opened/is using the UI
 * * `ui`—The UI to be updated, if it exists
 */
/datum/proc/ui_interact(mob/user, datum/tgui/ui)
	return FALSE // Not implemented.

/**
 * Data to be sent to the UI.
 * This must return an associative list for a UI to work.
 *
 * Arguments:
 * * `user`—The mob who opened/is using the UI
 */
/datum/proc/ui_data(mob/user)
	return list() // Not implemented.

/**
 * Static data to be sent to the UI.
 *
 * Static data differs from normal data in that it's sent less frequently
 * (only during window open and forced updates). This is implemented for heavy
 * UIs that would be sending a lot of redundant data frequently.
 *
 * Don't use this for anything that needs to update more often than during
 * window open and/or forced updates, as updates can slow down UIs with
 * a loading screen during each update/window open.
 *
 * Static data is bundled with data on the frontend side. This must return
 * an associative list.
 *
 * Arguments:
 * * `user`—The mob who opened/is using the UI
 */
/datum/proc/ui_static_data(mob/user)
	return list()

/**
 * Forces an update on static data. Should be done manually whenever something
 * happens to change static data. *Should not* be done during frequent events
 * like processing ticks, as updates can slow down UIs with loading screens.
 *
 * Arguments:
 * * `user`—The mob who opened/is using the UI
 * * `ui`—The UI to be updated, if it exists
 * * `always_instant`—When set to TRUE, stops the UI update cooldown from happening
 */
/datum/proc/update_static_data(mob/user, datum/tgui/ui, always_instant)
	if(!ui)
		ui = SStgui.get_open_ui(user, src)
	if(ui)
		ui.send_full_update(always_instant = always_instant)

/**
 * Forces an update on static data for all viewers.
 *
 * Should be done manually whenever something happens to change static data.
 * *Should not* be done during frequent events like processing ticks, as
 * updates can slow down UIs with loading screens.
 */
/datum/proc/update_static_data_for_all_viewers()
	for (var/datum/tgui/window as anything in open_uis)
		window.send_full_update()

/**
 * Forces an update on non-static data for all viewers.
 *
 * Use when you are manually controlling UI data updates,
 * such as when you are not using the auto-update system.
 */
/datum/proc/update_data_for_all_viewers()
	for(var/datum/tgui/ui as anything in open_uis)
		ui.send_update()

/**
 * Called on a UI when the UI receieves an action from `act(...)` on the frontend.
 * Think of this as `Topic` but for TGUI.
 *
 * **In your implementation, you MUST call parent using `. = ..()` and return
 * if it's truthy:**
 * ```dm
 * 	. = ..()
 * 	if(.)
 * 		return
 * ```
 * This is a security measure that prevents interacting with uninteractable UIs.
 *
 * Return TRUE to force a UI update and prevent descendants from running.
 *
 * Arguments:
 * * `action`—The action/button that has been invoked by the user
 * * `params`—An associative list of parameters attached to the button
 */
/datum/proc/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	SHOULD_CALL_PARENT(TRUE)
	SEND_SIGNAL(src, COMSIG_UI_ACT, usr, action, params)
	// If UI is not interactive or usr calling Topic is not the UI user, bail.
	if(!ui || ui.status != UI_INTERACTIVE)
		return TRUE
	if(action == "change_ui_state")
		var/mob/living/user = ui.user
		//write_preferences will make sure it's valid for href exploits.
		user.client.prefs.write_preference(GLOB.preference_entries[layout_prefs_used], params["new_state"])

/**
 * Called on an object when a TGUI datum is being created, allowing you to
 * push various assets to TGUI, like spritesheets.
 *
 * Must return a list of asset datums or file paths.
 *
 * Arguments:
 * * `user`—The mob who opened/is using the UI
 */
/datum/proc/ui_assets(mob/user)
	return list()

/**
 * Returns the UI's host object (usually src_object).
 *
 * This allows datums to point to something that *hosts* them,
 * for the purpose of UI updating/closing.
 *
 * Arguments:
 * * `user`—The mob who opened/is using the UI
 */
/datum/proc/ui_host(mob/user)
	return src // Default src.

/**
 * The UI's state controller to be used for created UIs.
 *
 * This is a getter proc over a var for memory reasons.
 *
 * Returns a `/datum/ui_state` global datum.
 *
 * Arguments:
 * * `user`—The mob who opened/is using the UI
 */
/datum/proc/ui_state(mob/user)
	return GLOB.default_state

/// Associative list of JSON-encoded shared states set by TGUI clients
/datum/var/list/tgui_shared_states

/// The mob's open TGUI datums
/mob/var/list/tgui_open_uis = list()

/// The mob's open TGUI window IDs
/client/var/list/tgui_windows = list()

/// TRUE if the cache was reloaded by the TGUI dev server at least once
/client/var/tgui_cache_reloaded = FALSE

/**
 * Called on a UI's object when the UI is closed. Not to be confused with
 * `/client/verb/uiclose()`, which closes the UI window and is a verb
 * so `winset` can call it.
 *
 * Arguments:
 * * `user`—Mob who opened/is using the UI
 */
/datum/proc/ui_close(mob/user)
	SIGNAL_HANDLER

/**
 * Called by UIs when they are closed.
 * Must be a verb so winset() can call it.
 *
 * Arguments:
 * * `window_id`—The ID of the UI that was closed
 */
/client/verb/uiclose(window_id as text)
	// Name the verb, and hide it from the user panel.
	set name = "uiclose"
	set hidden = TRUE
	var/mob/user = src?.mob
	if(!user)
		return
	// Close all tgui datums based on window_id.
	SStgui.force_close_window(user, window_id)

/**
 * Middleware for /client/Topic.
 *
 * If this returns TRUE, it prevents propagation of the topic call.
 */
/proc/tgui_Topic(href_list)
	// Skip non-tgui topics
	if(!href_list["tgui"])
		return FALSE
	var/type = href_list["type"]
	// Unconditionally collect tgui logs
	if(type == "log")
		var/context = href_list["window_id"]
		if (href_list["ns"])
			context += " ([href_list["ns"]])"
		log_tgui(usr, href_list["message"],
			context = context)
	// Reload all tgui windows
	if(type == "cacheReloaded")
		if(!check_rights(R_ADMIN) || usr.client.tgui_cache_reloaded)
			return TRUE
		// Mark as reloaded
		usr.client.tgui_cache_reloaded = TRUE
		// Notify windows
		var/list/windows = usr.client.tgui_windows
		for(var/window_id in windows)
			var/datum/tgui_window/window = windows[window_id]
			if (window.status == TGUI_WINDOW_READY)
				window.on_message(type, null, href_list)
		return TRUE
	// Locate window
	var/window_id = href_list["window_id"]
	var/datum/tgui_window/window
	if(window_id)
		window = usr.client.tgui_windows[window_id]
		if(!window)
			log_tgui(usr,
				"Error: Couldn't find the window datum, force closing.",
				context = window_id)
			SStgui.force_close_window(usr, window_id)
			return TRUE

	// Decode payload
	var/payload
	if(href_list["payload"])
		var/payload_text = href_list["payload"]

		if (!rustg_json_is_valid(payload_text))
			log_tgui(usr, "Error: Invalid JSON")
			return TRUE

		payload = json_decode(payload_text)

	// Pass message to window
	if(window)
		window.on_message(type, payload, href_list)
	return TRUE
