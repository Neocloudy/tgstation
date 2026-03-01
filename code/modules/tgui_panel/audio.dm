/*!
 * Copyright (c) 2020 Aleksej Komarov
 * SPDX-License-Identifier: MIT
 */

/// Admin music volume, from 0 to 1
/client/var/admin_music_volume = 1

/**
 * Sends music data to the browser.
 *
 * Arguments:
 * * `url`—HTTP URL to the music to play
 * * `extra_data`—Optional settings
 */
/datum/tgui_panel/proc/play_music(url, extra_data)
	if(!is_ready())
		return
	if(!findtext(url, GLOB.is_http_protocol))
		return
	var/list/payload = list()
	if(length(extra_data) > 0)
		for(var/key in extra_data)
			payload[key] = extra_data[key]
	payload["url"] = url
	window.send_message("audio/playMusic", payload)

/// Stops playing music through the browser
/datum/tgui_panel/proc/stop_music()
	if(!is_ready())
		return
	window.send_message("audio/stopMusic")
