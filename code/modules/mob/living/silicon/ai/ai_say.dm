/*
 * AI Saycode
 */


/mob/living/silicon/ai/handle_track(message, verb = "says", mob/speaker = null, speaker_name, atom/follow_target, hard_to_hear)
	if(hard_to_hear)
		return

	var/jobname // the mob's "job"
	var/mob/living/carbon/human/impersonating //The crewmember being impersonated, if any.
	var/changed_voice = FALSE

	if(ishuman(speaker))
		var/mob/living/carbon/human/H = speaker

		var/obj/item/card/id/id = H.wear_id
		if((istype(id) && id.is_untrackable()) && H.HasVoiceChanger())
			changed_voice = TRUE
			var/mob/living/carbon/human/I = locate(speaker_name)
			if(I)
				impersonating = I
				jobname = impersonating.get_assignment()
			else
				jobname = "Unknown"
		else
			jobname = H.get_assignment()

	else if(iscarbon(speaker)) // Nonhuman carbon mob
		jobname = "No ID"
	else if(isAI(speaker))
		jobname = JOB_TITLE_AI
	else if(iscogscarab(speaker))
		jobname = "Unknown"
	else if(isrobot(speaker))
		var/mob/living/silicon/robot/R = speaker
		jobname = R.mind.role_alt_title ? R.mind.role_alt_title : JOB_TITLE_CYBORG
	else if(ispAI(speaker))
		jobname = "Personal AI"
	else if(isAutoAnnouncer(speaker))
		var/mob/living/automatedannouncer/AA = speaker
		jobname = AA.role
	else
		jobname = "Unknown"

	var/track = ""
	var/mob/mob_to_track = null
	if(changed_voice)
		if(impersonating)
			mob_to_track = impersonating
		else
			track = "[speaker_name] ([jobname])"
	else
		if(isbot(follow_target))
			track = "<a href='byond://?src=[UID()];trackbot=\ref[follow_target]'>[speaker_name] ([jobname])</a>"
		else
			mob_to_track = speaker

	if(mob_to_track)
		track = "<a href='byond://?src=[UID()];track=\ref[mob_to_track]'>[speaker_name] ([jobname])</a>"
		track += "&nbsp;<a href='byond://?src=[UID()];open=\ref[mob_to_track]'>\[Open\]</a>"

	return track


/*
 * AI VOX Announcements
 */

GLOBAL_VAR_INIT(announcing_vox, 0) // Stores the time of the last announcement
#define VOX_DELAY 100
#define VOX_PATH "sound/vox_fem/"

/mob/living/silicon/ai/verb/announcement_help()
	set name = "Announcement Help"
	set desc = "Display a list of vocal words to announce to the crew."
	set category = "AI Commands"

	var/list/dat = list()

	dat += "Here is a list of words you can type into the 'Announcement' button to create sentences to vocally announce to everyone on the same level at you.<br> \
	<ul><li>You can also click on the word to preview it.</li>\
	<li>You can only say 30 words for every announcement.</li>\
	<li>Do not use punctuation as you would normally, if you want a pause you can use the full stop and comma characters by separating them with spaces, like so: 'Alpha . Test , Bravo'.</li></ul>\
	<font class='bad'>WARNING:</font><br>Misuse of the announcement system will get you job banned.<hr>"

	// Show alert and voice sounds separately
	var/vox_words = GLOB.vox_sounds - GLOB.vox_alerts
	dat += help_format(GLOB.vox_alerts)
	dat += "<hr>"
	dat += help_format(vox_words)

	var/string_dat = dat.Join("")

	var/datum/browser/popup = new(src, "announce_help", "Announcement Help", 500, 400)
	popup.set_content(string_dat)
	popup.open()


/mob/living/silicon/ai/proc/help_format(word_list)
	var/list/localdat = list()
	var/uid_cache = UID() // Saves proc jumping
	for(var/word in word_list)
		localdat += "<a href='byond://?src=[uid_cache];say_word=[word]'>[word]</a>"
	return localdat.Join(" / ")


/mob/living/silicon/ai/proc/ai_announcement()
	if(check_unable(AI_CHECK_WIRELESS | AI_CHECK_RADIO))
		return

	if(GLOB.announcing_vox > world.time)
		to_chat(src, "<span class='warning'>Please wait [round((GLOB.announcing_vox - world.time) / 10)] seconds.</span>")
		return

	var/message = tgui_input_text(src, "WARNING: Misuse of this verb can result in you being job banned. More help is available in 'Announcement Help'", "Announcement", last_announcement)

	last_announcement = message

	if(check_unable(AI_CHECK_WIRELESS | AI_CHECK_RADIO))
		return

	if(!message || GLOB.announcing_vox > world.time)
		return

	var/list/words = splittext(trim(message), " ")
	var/list/incorrect_words = list()

	if(words.len > 30)
		words.len = 30

	for(var/word in words)
		word = lowertext(trim(word))
		if(!word)
			words -= word
			continue
		if(!GLOB.vox_sounds[word])
			incorrect_words += word

	if(incorrect_words.len)
		to_chat(src, "<span class='warning'>These words are not available on the announcement system: [english_list(incorrect_words)].</span>")
		return

	GLOB.announcing_vox = world.time + VOX_DELAY

	add_game_logs("[key_name_log(src)] made a vocal announcement: [message].", src)
	message_admins("[key_name_admin(src)] made a vocal announcement: [message].")

	var/i = 0
	for(var/word in words)
		addtimer(CALLBACK(GLOBAL_PROC, /proc/play_vox_word, word, src.z, null), i, TIMER_CLIENT_TIME)
		i++

	ai_voice_announcement_to_text(words)


/mob/living/silicon/ai/proc/ai_voice_announcement_to_text(words)
	var/words_string = jointext(words, " ")
	var/formatted_message = "<h1 class='alert'>A.I. Announcement</h1>"
	formatted_message += "<br><span class='alert'>[words_string]</span>"
	formatted_message += "<br><span class='alert'> -[src]</span>"

	for(var/player in GLOB.player_list)
		var/mob/M = player
		if(M.client && !(M.client.prefs.sound & SOUND_AI_VOICE))
			var/turf/T = get_turf(M)
			if(T && T.z == z && M.can_hear())
				SEND_SOUND(M, 'sound/misc/announce_dig.ogg')
				to_chat(M, formatted_message)


/proc/play_vox_word(word, z_level, mob/only_listener)

	word = lowertext(word)

	if(GLOB.vox_sounds[word])

		var/sound_file = GLOB.vox_sounds[word]
		var/sound/voice = sound(sound_file, wait = 1, channel = CHANNEL_VOX)
		voice.status = SOUND_STREAM

		// If there is no single listener, broadcast to everyone in the same z level
		if(!only_listener)
			// Play voice for all mobs in the z level
			for(var/mob/M in GLOB.player_list)
				if(M.client && M.client.prefs.sound & SOUND_AI_VOICE)
					var/turf/T = get_turf(M)
					if(T && T.z == z_level && M.can_hear())
						voice.volume = 100 * M.client.prefs.get_channel_volume(CHANNEL_VOX)
						M << voice
		else
			only_listener << voice
		return TRUE
	return FALSE

