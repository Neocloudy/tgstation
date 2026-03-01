/*!
 * Copyright (c) 2020 Aleksej Komarov
 * SPDX-License-Identifier: MIT
 */

/// Hosts TGUI chat and its features
/datum/tgui_panel
	/// The client that owns this
	var/client/client
	/// The window to use
	var/datum/tgui_window/window
	/// `world.time` when this datum was initialized
	var/initialized_at
	/// Each client notifies on protected playback, so this prevents spamming admins
	var/static/admins_warned = FALSE

/datum/tgui_panel/New(client/client, id)
	src.client = client
	window = new(client, id)
	window.subscribe(src, PROC_REF(on_message))

/datum/tgui_panel/Del()
	window.unsubscribe(src)
	window.close()
	return ..()

/// Returns `TRUE` if the panel is ready to receive messages
/datum/tgui_panel/proc/is_ready()
	return window.is_ready()

/// Initializes the panel
/datum/tgui_panel/proc/initialize()
	set waitfor = FALSE
	// Minimal sleep to defer initialization to after client constructor
	sleep(1 TICKS)
	initialized_at = world.time
	// Perform a clean initialization
	window.initialize(
		strict_mode = TRUE,
		assets = list(
			get_asset_datum(/datum/asset/simple/tgui_panel),
		))
	window.send_asset(get_asset_datum(/datum/asset/simple/namespaced/fontawesome))
	window.send_asset(get_asset_datum(/datum/asset/simple/namespaced/tgfont))
	window.send_asset(get_asset_datum(/datum/asset/spritesheet_batched/chat))
	// Other setup
	request_telemetry()
	addtimer(CALLBACK(src, PROC_REF(on_initialize_timed_out)), 5 SECONDS)
	window.send_message("testTelemetryCommand")

/// Called 5 seconds after initialization, this direct outputs some
/// text to the client to allow them to refresh the panel.
/datum/tgui_panel/proc/on_initialize_timed_out()
	PRIVATE_PROC(TRUE)
	// Currently does nothing but sending a message to old chat.
	SEND_TEXT(client, span_userdanger("Failed to load fancy chat, click <a href='byond://?src=[REF(src)];reload_tguipanel=1'>HERE</a> to attempt to reload it."))

/**
 * Callback for handling incoming TGUI messages.
 *
 * Arguments:
 * * `type`—The incoming message type
 * * `payload`—Associative list of parameters
 */
/datum/tgui_panel/proc/on_message(type, payload)
	PRIVATE_PROC(TRUE)
	if(type == "ready")
		window.send_message("update", list(
			"config" = list(
				"client" = list(
					"ckey" = client.ckey,
					"address" = client.address,
					"computer_id" = client.computer_id,
				),
				"window" = list(
					"locked" = FALSE,
				),
			),
		))
		return TRUE

	if(type == "audio/setAdminMusicVolume")
		client.admin_music_volume = payload["volume"]
		return TRUE

	if(type == "audio/protected")
		if(!admins_warned)
			message_admins(span_notice("Audio returned a protected playback error, likely due to being copyrighted."))
			admins_warned = TRUE
			addtimer(VARSET_CALLBACK(src, admins_warned, FALSE), 10 SECONDS)
		return TRUE

	if(type == "telemetry")
		analyze_telemetry(payload)
		return TRUE

/// Sends the round restart notification
/datum/tgui_panel/proc/send_roundrestart()
	window.send_message("roundrestart")
