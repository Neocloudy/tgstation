/*!
 * Copyright (c) 2020 Aleksej Komarov
 * SPDX-License-Identifier: MIT
 */

/**
 * `/datum/tgui_window` represents a raw TGUI window.
 *
 * Use this if you're making a completely new interface from almost scratch,
 * like the TGUI chat panel.
 */
/datum/tgui_window
	/// Unique ID of the window
	var/id
	/// Client that owns the window
	var/client/client
	/// If the window can be pooled
	var/pooled
	/// Index of the window in the pool
	var/pool_index
	/// If the window is displayed in a BYOND browser
	var/is_browser = FALSE
	/// The window status
	var/status = TGUI_WINDOW_CLOSED
	/// If the window is locked
	var/locked = FALSE
	/// The UI datum this is locked by
	var/datum/tgui/locked_by
	/// If the window is visible
	var/visible = FALSE
	/// Datum we are subscribed to for consuming window messages
	var/datum/subscriber_object
	/// Proc name on `subscriber_object` to call
	var/subscriber_delegate
	/// If the window has fatally errored
	var/fatally_errored = FALSE
	/// List of messages that will be sent when the UI is ready
	var/list/message_queue
	/// Assets that have been sent
	var/list/sent_assets = list()
	/// Initial status of strict mode
	var/initial_strict_mode
	/// Initial assets of the window
	var/initial_assets
	/// Initial inline HTML of the window
	var/initial_inline_html
	/// Initial inline JS of the window
	var/initial_inline_js
	/// Initial inlince CSS of the window
	var/initial_inline_css
	/// Associative list of oversized payloads to be handled
	var/list/oversized_payloads = list()

/**
 * Creates a new tgui window.
 *
 * Arguments:
 * * `client`—The client that owns the UI
 * * `id`—A unique window identifier
 * * `pooled`—If the window can be added to the pool
 */
/datum/tgui_window/New(client/client, id, pooled = FALSE)
	src.id = id
	src.client = client
	src.client.tgui_windows[id] = src
	src.pooled = pooled
	if(pooled)
		src.pool_index = TGUI_WINDOW_INDEX(id)

/**
 * Initializes the window with a fresh page. Puts window into the "loading"
 * state. You can begin sending messages right after initializing. Messages
 * will be put into the queue until the window finishes loading.
 *
 * Arguments:
 * * `strict_mode`—Enables strict error handling and BSOD. You should enable this.
 * * `assets`—List of assets to load during initialization
 * * `inline_html`—Custom HTML to inject
 * * `inline_js`—Custom JS to inject
 * * `inline_css`—Custom CSS to inject
 */
/datum/tgui_window/proc/initialize(
	strict_mode = FALSE,
	assets = list(),
	inline_html = "",
	inline_js = "",
	inline_css = "",
)
	log_tgui(client,
		context = "[id]/initialize",
		window = src)
	if(!client)
		return
	src.initial_assets = assets
	src.initial_inline_html = inline_html
	src.initial_inline_js = inline_js
	src.initial_inline_css = inline_css
	status = TGUI_WINDOW_LOADING
	fatally_errored = FALSE
	// Build window options
	var/options = "file=[id].html;can_minimize=0;auto_format=0;titlebar=0;can_resize=0;"
	// Generate page html
	var/html = SStgui.basehtml
	html = replacetextEx(html, "\[tgui:windowId]", id)
	html = replacetextEx(html, "\[tgui:strictMode]", strict_mode)
	// Inject assets
	var/inline_assets_str = ""
	for(var/datum/asset/asset in assets)
		var/mappings = asset.get_url_mappings()
		for(var/name in mappings)
			var/url = mappings[name]
			// Not encoding since asset strings are considered safe
			if(copytext(name, -4) == ".css")
				inline_assets_str += "Byond.loadCss('[url]', true);\n"
			else if(copytext(name, -3) == ".js")
				inline_assets_str += "Byond.loadJs('[url]', true);\n"
		asset.send(client)
	if(length(inline_assets_str))
		inline_assets_str = "<script>\n" + inline_assets_str + "</script>\n"
	html = replacetextEx(html, "<!-- tgui:assets -->\n", inline_assets_str)
	// Inject inline HTML
	if (inline_html)
		html = replacetextEx(html, "<!-- tgui:inline-html -->", isfile(inline_html) ? file2text(inline_html) : inline_html)
	// Inject inline JS
	if (inline_js)
		inline_js = "<script>\n'use strict';\n[isfile(inline_js) ? file2text(inline_js) : inline_js]\n</script>"
		html = replacetextEx(html, "<!-- tgui:inline-js -->", inline_js)
	// Inject inline CSS
	if (inline_css)
		inline_css = "<style>\n[isfile(inline_css) ? file2text(inline_css) : inline_css]\n</style>"
		html = replacetextEx(html, "<!-- tgui:inline-css -->", inline_css)
	// Open the window
	client << browse(html, "window=[id];[options]")
	// Detect whether the control is a browser
	is_browser = winexists(client, id) == "BROWSER"
	// Instruct the client to signal UI when the window is closed.
	if(!is_browser)
		winset(client, id, "on-close=\"uiclose [id]\"")

/// Reinitializes the panel with the previous data used for initialization
/datum/tgui_window/proc/reinitialize()
	initialize(
		strict_mode = initial_strict_mode,
		assets = initial_assets,
		inline_html = initial_inline_html,
		inline_js = initial_inline_js,
		inline_css = initial_inline_css)
	// Resend assets
	for(var/datum/asset/asset in sent_assets)
		send_asset(asset)

/// Checks if the window is ready to receive data
/datum/tgui_window/proc/is_ready()
	return status == TGUI_WINDOW_READY

/// Checks if the window can be safely suspended
/datum/tgui_window/proc/can_be_suspended()
	return !fatally_errored \
		&& pooled \
		&& pool_index > 0 \
		&& pool_index <= TGUI_WINDOW_SOFT_LIMIT \
		&& status == TGUI_WINDOW_READY

/**
 * Acquire the window lock. Pool will not be able to provide this window
 * to other UIs for the duration of the lock.
 *
 * Can be given an optional UI datum, which will be automatically
 * subscribed to incoming messages via the `on_message` proc.
 *
 * Arguments:
 * * `ui`—The UI this is being locked by
 */
/datum/tgui_window/proc/acquire_lock(datum/tgui/ui)
	locked = TRUE
	locked_by = ui

/// Releases the window lock
/datum/tgui_window/proc/release_lock()
	// Clean up assets sent by tgui datum which requested the lock
	if(locked)
		sent_assets = list()
	locked = FALSE
	locked_by = null

/**
 * Subscribes the datum to consume window messages on a specified proc.
 *
 * Note, that this supports only one subscriber, because code for that
 * is simpler and therefore faster. If necessary, this can be rewritten
 * to support multiple subscribers.
 */
/datum/tgui_window/proc/subscribe(datum/object, delegate)
	subscriber_object = object
	subscriber_delegate = delegate

/// Unsubscribes from a datum. Don't forget to call this when cleaning up.
/datum/tgui_window/proc/unsubscribe(datum/object)
	subscriber_object = null
	subscriber_delegate = null

/**
 * Closes the window.
 *
 * Arguments:
 * * `can_be_suspended`—If the window can be suspended
 */
/datum/tgui_window/proc/close(can_be_suspended = TRUE)
	if(!client)
		return
	if(can_be_suspended && can_be_suspended())
		log_tgui(client,
			context = "[id]/close (suspending)",
			window = src)
		visible = FALSE
		status = TGUI_WINDOW_READY
		send_message("suspend")
		return
	log_tgui(client,
		context = "[id]/close",
		window = src)
	release_lock()
	visible = FALSE
	status = TGUI_WINDOW_CLOSED
	message_queue = null
	// Do not close the window to give user some time
	// to read the error message.
	if(!fatally_errored)
		client << browse(null, "window=[id]")

/**
 * Sends a message to the window.
 *
 * Arguments:
 * * `type`—The incoming message type
 * * `payload`—Associative list of parameters
 * * `force`—Sends regardless of the window being ready
 */
/datum/tgui_window/proc/send_message(type, payload, force)
	if(!client)
		return
	var/message = TGUI_CREATE_MESSAGE(type, payload)
	// Place into queue if window is still loading
	if(!force && status != TGUI_WINDOW_READY)
		if(!message_queue)
			message_queue = list()
		message_queue += list(message)
		return
	client << output(message, is_browser \
		? "[id]:update" \
		: "[id].browser:update")

/**
 * Sends a raw payload to the window.
 *
 * Arguments:
 * * `message`—JSON + URL encoded blob to send
 * * `force`—Sends regardless of the window being ready
 */
/datum/tgui_window/proc/send_raw_message(message, force)
	if(!client)
		return
	// Place into queue if window is still loading
	if(!force && status != TGUI_WINDOW_READY)
		if(!message_queue)
			message_queue = list()
		message_queue += list(message)
		return
	client << output(message, is_browser \
		? "[id]:update" \
		: "[id].browser:update")

/**
 * Makes an asset available to use in the window.
 *
 * Returns TRUE if the asset was successfully sent.
 *
 * Arguments:
 * * `asset`—The asset datum to send
 */
/datum/tgui_window/proc/send_asset(datum/asset/asset)
	if(!client || !asset)
		return
	sent_assets |= list(asset)
	. = asset.send(client)
	if(istype(asset, /datum/asset/spritesheet))
		var/datum/asset/spritesheet/spritesheet = asset
		send_message("asset/stylesheet", spritesheet.css_filename())
	else if(istype(asset, /datum/asset/spritesheet_batched))
		var/datum/asset/spritesheet_batched/spritesheet = asset
		send_message("asset/stylesheet", spritesheet.css_filename())
	send_raw_message(asset.get_serialized_url_mappings())

/// Sends queued messages if the queue wasn't empty
/datum/tgui_window/proc/flush_message_queue()
	if(!client || !message_queue)
		return
	for(var/message in message_queue)
		client << output(message, is_browser \
			? "[id]:update" \
			: "[id].browser:update")
	message_queue = null

/**
 * Replaces the inline HTML content.
 *
 * Arguments:
 * * `inline_html`—HTML to inject
 */
/datum/tgui_window/proc/replace_html(inline_html = "")
	client << output(url_encode(inline_html), is_browser \
		? "[id]:replaceHtml" \
		: "[id].browser:replaceHtml")

/**
 * Callback for handling incoming messages.
 *
 * Arguments:
 * * `type`—The incoming message type
 * * `payload`—Associative list of parameters
 * * `href_list`—The raw HREF list from BYOND
 */
/datum/tgui_window/proc/on_message(type, list/payload, list/href_list)
	// Status can be READY if user has refreshed the window.
	if(type == "ready" && status == TGUI_WINDOW_READY)
		// Resend the assets
		for(var/asset in sent_assets)
			send_asset(asset)
	// Mark this window as fatally errored which prevents it from
	// being suspended.
	if(type == "log" && href_list["fatal"])
		fatally_errored = TRUE
	// Mark window as ready since we received this message from somewhere
	if(status != TGUI_WINDOW_READY)
		status = TGUI_WINDOW_READY
		flush_message_queue()
	// Pass message to UI that requested the lock
	if(locked && locked_by)
		var/prevent_default = locked_by.on_message(type, payload, href_list)
		if(prevent_default)
			return
	// Pass message to the subscriber
	else if(subscriber_object)
		var/prevent_default = call(
			subscriber_object,
			subscriber_delegate)(type, payload, href_list)
		if(prevent_default)
			return
	// If not locked, handle these message types
	switch(type)
		if("ping")
			send_message("ping/reply", payload)
		if("visible")
			visible = TRUE
			SEND_SIGNAL(src, COMSIG_TGUI_WINDOW_VISIBLE, client)
		if("suspend")
			close(can_be_suspended = TRUE)
		if("close")
			close(can_be_suspended = FALSE)
		if("openLink")
			client << link(href_list["url"])
		if("cacheReloaded")
			reinitialize()
		if("chat/resend")
			SSchat.handle_resend(client, payload)
		if("oversizedPayloadRequest")
			var/payload_id = payload["id"]
			var/chunk_count = payload["chunkCount"]
			var/permit_payload = chunk_count <= CONFIG_GET(number/tgui_max_chunk_count)
			if(permit_payload)
				create_oversized_payload(payload_id, payload["type"], chunk_count)
			send_message("oversizePayloadResponse", list("allow" = permit_payload, "id" = payload_id))
		if("payloadChunk")
			var/payload_id = payload["id"]
			append_payload_chunk(payload_id, payload["chunk"])
			send_message("acknowledgePayloadChunk", list("id" = payload_id))

/datum/tgui_window/vv_edit_var(var_name, var_value)
	if(var_name == NAMEOF(src, id))
		return FALSE
	return ..()

/datum/tgui_window/proc/create_oversized_payload(payload_id, message_type, chunk_count)
	if(oversized_payloads[payload_id])
		stack_trace("Attempted to create oversized tgui payload with duplicate ID.")
		return
	oversized_payloads[payload_id] = list(
		"type" = message_type,
		"count" = chunk_count,
		"chunks" = list(),
		"timeout" = addtimer(CALLBACK(src, PROC_REF(remove_oversized_payload), payload_id), 1 SECONDS, TIMER_UNIQUE|TIMER_OVERRIDE|TIMER_STOPPABLE),
	)

/datum/tgui_window/proc/append_payload_chunk(payload_id, chunk)
	var/list/payload = oversized_payloads[payload_id]
	if(!payload)
		return
	var/list/chunks = payload["chunks"]
	chunks += chunk
	if(length(chunks) >= payload["count"])
		deltimer(payload["timeout"])
		var/message_type = payload["type"]
		var/final_payload = chunks.Join()
		remove_oversized_payload(payload_id)
		on_message(message_type, json_decode(final_payload), list("type" = message_type, "payload" = final_payload, "tgui" = TRUE, "window_id" = id))
	else
		payload["timeout"] = addtimer(CALLBACK(src, PROC_REF(remove_oversized_payload), payload_id), 1 SECONDS, TIMER_UNIQUE|TIMER_OVERRIDE|TIMER_STOPPABLE)

/datum/tgui_window/proc/remove_oversized_payload(payload_id)
	oversized_payloads -= payload_id
