/datum/preferences/proc/load_preferences(client/C)

	var/datum/db_query/query = SSdbcore.NewQuery({"SELECT
					ooccolor,
					UI_style,
					UI_style_color,
					UI_style_alpha,
					be_role,
					default_slot,
					toggles,
					toggles_2,
					sound,
					volume_mixer,
					lastchangelog,
					exp,
					clientfps,
					atklog,
					fuid,
					parallax,
					discord_id,
					discord_name,
					keybindings,
					viewrange,
					ghost_darkness_level,
					toggles_3
					FROM [format_table_name("player")]
					WHERE ckey=:ckey"}, list(
						"ckey" = C.ckey
					))

	if(!query.warn_execute())
		qdel(query)
		return


	//general preferences
	while(query.NextRow())
		ooccolor = query.item[1]
		UI_style = query.item[2]
		UI_style_color = query.item[3]
		UI_style_alpha = text2num(query.item[4])
		be_special = params2list(query.item[5])
		default_slot = text2num(query.item[6])
		toggles = text2num(query.item[7])
		toggles2 = text2num(query.item[8])
		sound = text2num(query.item[9])
		volume_mixer = deserialize_volume_mixer(query.item[10])
		lastchangelog = query.item[11]
		exp = query.item[12]
		clientfps = text2num(query.item[13])
		atklog = text2num(query.item[14])
		fuid = text2num(query.item[15])
		parallax = text2num(query.item[16])
		discord_id = query.item[17]
		discord_name = query.item[18]
		keybindings = init_keybindings(raw = query.item[19])
		viewrange = query.item[20]
		ghost_darkness_level = query.item[21]
		toggles3 = text2num(query.item[22])

	qdel(query)

	//Sanitize
	ooccolor		= sanitize_hexcolor(ooccolor, initial(ooccolor))
	UI_style		= sanitize_inlist(UI_style, list("White", "Midnight", "Plasmafire", "Retro", "Slimecore", "Operative"), initial(UI_style))
	default_slot	= sanitize_integer(default_slot, 1, max_save_slots, initial(default_slot))
	toggles			= sanitize_integer(toggles, 0, TOGGLES_TOTAL, initial(toggles))
	toggles2		= sanitize_integer(toggles2, 0, TOGGLES_2_TOTAL, initial(toggles2))
	toggles3		= sanitize_integer(toggles3, 0, TOGGLES_3_TOTAL, initial(toggles3))
	sound			= sanitize_integer(sound, 0, 65535, initial(sound))
	UI_style_color	= sanitize_hexcolor(UI_style_color, initial(UI_style_color))
	UI_style_alpha	= sanitize_integer(UI_style_alpha, 0, 255, initial(UI_style_alpha))
	lastchangelog	= sanitize_text(lastchangelog, initial(lastchangelog))
	exp	= sanitize_text(exp, initial(exp))
	clientfps = sanitize_integer(clientfps, -1, 1000, initial(clientfps))
	atklog = sanitize_integer(atklog, 0, 100, initial(atklog))
	fuid = sanitize_integer(fuid, 0, 10000000, initial(fuid))
	parallax = sanitize_integer(parallax, 0, 16, initial(parallax))
	discord_id			= sanitize_text(discord_id, initial(discord_id))
	discord_name		= sanitize_text(discord_name, initial(discord_name))
	return TRUE

/datum/preferences/proc/save_preferences(client/C)

	// Might as well scrub out any malformed be_special list entries while we're here
	for(var/role in be_special)
		if(!(role in GLOB.special_roles))
			log_runtime(EXCEPTION("[C.key] had a malformed role entry: '[role]'. Removing!"), src)
			be_special -= role

	// We're saving volume_mixer here as well, so no point in keeping the timer running
	if(volume_mixer_saving)
		deltimer(volume_mixer_saving)
		volume_mixer_saving = null

	var/datum/db_query/query = SSdbcore.NewQuery({"UPDATE [format_table_name("player")]
				SET
					ooccolor=:ooccolour,
					UI_style=:ui_style,
					UI_style_color=:ui_colour,
					UI_style_alpha=:ui_alpha,
					be_role=:berole,
					default_slot=:defaultslot,
					toggles=:toggles,
					toggles_2=:toggles2,
					atklog=:atklog,
					sound=:sound,
					volume_mixer=:volume_mixer,
					lastchangelog=:lastchangelog,
					clientfps=:clientfps,
					parallax=:parallax,
					keybindings=:keybindings,
					viewrange=:viewrange,
					ghost_darkness_level=:ghost_darkness_level,
					toggles_3=:toggles3
					WHERE ckey=:ckey"}, list(
						// OH GOD THE PARAMETERS
						"ooccolour" = ooccolor,
						"ui_style" = UI_style,
						"ui_colour" = UI_style_color,
						"ui_alpha" = UI_style_alpha,
						"berole" = list2params(be_special),
						"defaultslot" = default_slot,
						// Even though its a number in the DB, you have to use num2text here, otherwise byond adds scientific notation to the number
						"toggles" = num2text(toggles, CEILING(log(10, (TOGGLES_TOTAL)), 1)),
						"toggles2" = num2text(toggles2, CEILING(log(10, (TOGGLES_2_TOTAL)), 1)),
						"atklog" = atklog,
						"sound" = sound,
						"volume_mixer" = serialize_volume_mixer(volume_mixer),
						"lastchangelog" = lastchangelog,
						"clientfps" = clientfps,
						"parallax" = parallax,
						"keybindings" = json_encode(keybindings_overrides),
						"viewrange" = viewrange,
						"ghost_darkness_level" = ghost_darkness_level,
						"ckey" = C.ckey,
						"toggles3" = num2text(toggles3, CEILING(log(10, (TOGGLES_3_TOTAL)), 1)),
					)
					)

	if(!query.warn_execute())
		qdel(query)
		return

	qdel(query)
	return 1

/datum/preferences/proc/load_character(client/C, slot)
	saved = FALSE

	if(!slot)
		slot = default_slot
	slot = sanitize_integer(slot, 1, max_save_slots, initial(default_slot))
	if(slot != default_slot)
		default_slot = slot
		var/datum/db_query/firstquery = SSdbcore.NewQuery("UPDATE [format_table_name("player")] SET default_slot=:slot WHERE ckey=:ckey", list(
			"slot" = slot,
			"ckey" = C.ckey
		))
		if(!firstquery.warn_execute(async = FALSE)) // Dont make this async. It makes roundstart slow.
			qdel(firstquery)
			return
		qdel(firstquery)

	if(!C) // If the client disconnected during the query, try again later.
		return TRUE

	// Let's not have this explode if you sneeze on the DB
	var/datum/db_query/query = SSdbcore.NewQuery({"SELECT
					OOC_Notes,
					real_name,
					name_is_always_random,
					gender,
					age,
					species,
					language,
					hair_colour,
					secondary_hair_colour,
					facial_hair_colour,
					secondary_facial_hair_colour,
					skin_tone,
					skin_colour,
					marking_colours,
					head_accessory_colour,
					hair_style_name,
					facial_style_name,
					marking_styles,
					head_accessory_style_name,
					alt_head_name,
					eye_colour,
					underwear,
					underwear_color,
					undershirt,
					undershirt_color,
					backbag,
					b_type,
					alternate_option,
					job_support_high,
					job_support_med,
					job_support_low,
					job_medsci_high,
					job_medsci_med,
					job_medsci_low,
					job_engsec_high,
					job_engsec_med,
					job_engsec_low,
					job_karma_high,
					job_karma_med,
					job_karma_low,
					flavor_text,
					med_record,
					sec_record,
					gen_record,
					exploit_record,
					disabilities,
					player_alt_titles,
					organ_data,
					rlimb_data,
					nanotrasen_relation,
					speciesprefs,
					socks,
					body_accessory,
					gear,
					autohiss,
					uplink_pref,
					tts_seed,
					custom_emotes,
					hair_gradient,
					hair_gradient_offset,
					hair_gradient_colour,
					hair_gradient_alpha
				 	FROM [format_table_name("characters")] WHERE ckey=:ckey AND slot=:slot"}, list(
						 "ckey" = C.ckey,
						 "slot" = slot
					 ))
	if(!query.warn_execute(async = FALSE)) // Dont make this async. It makes roundstart slow.
		qdel(query)
		return

	while(query.NextRow())
		//Character
		metadata = query.item[1]
		real_name = query.item[2]
		be_random_name = text2num(query.item[3])
		gender = query.item[4]
		age = text2num(query.item[5])
		species = query.item[6]
		language = query.item[7]

		h_colour = query.item[8]
		h_sec_colour = query.item[9]
		f_colour = query.item[10]
		f_sec_colour = query.item[11]
		s_tone = text2num(query.item[12])
		s_colour = query.item[13]
		m_colours = params2list(query.item[14])
		hacc_colour = query.item[15]
		h_style = query.item[16]
		f_style = query.item[17]
		m_styles = params2list(query.item[18])
		ha_style = query.item[19]
		alt_head = query.item[20]
		e_colour = query.item[21]
		underwear = query.item[22]
		underwear_color = query.item[23]
		undershirt = query.item[24]
		undershirt_color = query.item[25]
		backbag = query.item[26]
		b_type = query.item[27]


		//Jobs
		alternate_option = text2num(query.item[28])
		job_support_high = text2num(query.item[29])
		job_support_med = text2num(query.item[30])
		job_support_low = text2num(query.item[31])
		job_medsci_high = text2num(query.item[32])
		job_medsci_med = text2num(query.item[33])
		job_medsci_low = text2num(query.item[34])
		job_engsec_high = text2num(query.item[35])
		job_engsec_med = text2num(query.item[36])
		job_engsec_low = text2num(query.item[37])
		job_karma_high = text2num(query.item[38])
		job_karma_med = text2num(query.item[39])
		job_karma_low = text2num(query.item[40])

		//Miscellaneous
		flavor_text = query.item[41]
		med_record = query.item[42]
		sec_record = query.item[43]
		gen_record = query.item[44]
		exploit_record = null_longtextfix(query.item[45])
		// Apparently, the preceding vars weren't always encoded properly...
		if(findtext(flavor_text, "<")) // ... so let's clumsily check for tags!
			flavor_text = html_encode(flavor_text)
		if(findtext(med_record, "<"))
			med_record = html_encode(med_record)
		if(findtext(sec_record, "<"))
			sec_record = html_encode(sec_record)
		if(findtext(gen_record, "<"))
			gen_record = html_encode(gen_record)
		if(findtext(exploit_record, "<"))
			exploit_record = html_encode(exploit_record)
		disabilities = text2num(query.item[46])
		player_alt_titles = params2list(query.item[47])
		organ_data = params2list(query.item[48])
		rlimb_data = params2list(query.item[49])
		nanotrasen_relation = query.item[50]
		speciesprefs = text2num(query.item[51])

		//socks
		socks = query.item[52]
		body_accessory = query.item[53]
		loadout_gear.Cut()
		var/list/unformated_loadout_gear = params2list(query.item[54])
		for(var/gear in unformated_loadout_gear)
			loadout_gear[gear] = params2list(unformated_loadout_gear[gear])
		form_choosen_gears()
		autohiss_mode = text2num(query.item[55])
		uplink_pref = query.item[56]

		// TTS
		tts_seed = query.item[57]

		//Emotes
		custom_emotes_tmp = query.item[58]

		// Gradient
		h_grad_style = query.item[59]
		h_grad_offset_x = query.item[60] // parsed down below
		h_grad_colour = query.item[61]
		h_grad_alpha = query.item[62]

		saved = TRUE

	qdel(query)
	//Sanitize
	var/datum/species/SP = GLOB.all_species[species]
	metadata		= sanitize_text(metadata, initial(metadata))
	real_name		= reject_bad_name(real_name, 1)
	if(isnull(species)) species = SPECIES_HUMAN
	if(isnull(language)) language = "None"
	if(isnull(nanotrasen_relation)) nanotrasen_relation = initial(nanotrasen_relation)
	if(isnull(speciesprefs)) speciesprefs = initial(speciesprefs)
	if(!real_name) real_name = random_name(gender,species)
	be_random_name	= sanitize_integer(be_random_name, 0, 1, initial(be_random_name))
	gender			= sanitize_gender(gender, FALSE, !SP?.has_gender)
	var/age_limits = get_age_limits(SP, list(SPECIES_AGE_MIN, SPECIES_AGE_MAX, JOB_MIN_AGE_COMMAND))
	age				= sanitize_integer(age, age_limits[SPECIES_AGE_MIN], age_limits[SPECIES_AGE_MAX], age_limits[JOB_MIN_AGE_COMMAND])
	h_colour		= sanitize_hexcolor(h_colour)
	h_sec_colour	= sanitize_hexcolor(h_sec_colour)
	f_colour		= sanitize_hexcolor(f_colour)
	f_sec_colour	= sanitize_hexcolor(f_sec_colour)
	s_tone			= sanitize_integer(s_tone, -185, 34, initial(s_tone))
	s_colour		= sanitize_hexcolor(s_colour)
	for(var/marking_location in m_colours)
		m_colours[marking_location] = sanitize_hexcolor(m_colours[marking_location], DEFAULT_MARKING_COLOURS[marking_location])
	hacc_colour		= sanitize_hexcolor(hacc_colour)
	h_style			= sanitize_inlist(h_style, GLOB.hair_styles_public_list, initial(h_style))
	f_style			= sanitize_inlist(f_style, GLOB.facial_hair_styles_list, initial(f_style))
	for(var/marking_location in m_styles)
		m_styles[marking_location] = sanitize_inlist(m_styles[marking_location], GLOB.marking_styles_list, DEFAULT_MARKING_STYLES[marking_location])
	ha_style		= sanitize_inlist(ha_style, GLOB.head_accessory_styles_list, initial(ha_style))
	alt_head		= sanitize_inlist(alt_head, GLOB.alt_heads_list, initial(alt_head))
	e_colour		= sanitize_hexcolor(e_colour)
	underwear		= sanitize_text(underwear, initial(underwear))
	underwear_color	= sanitize_hexcolor(underwear_color)
	undershirt		= sanitize_text(undershirt, initial(undershirt))
	undershirt_color= sanitize_hexcolor(undershirt_color)
	backbag			= sanitize_text(backbag, initial(backbag))
	b_type			= sanitize_text(b_type, initial(b_type))
	autohiss_mode	= sanitize_integer(autohiss_mode, 0, 2, initial(autohiss_mode))
	uplink_pref     = sanitize_text(uplink_pref, initial(uplink_pref))
	tts_seed		= sanitize_inlist(tts_seed, SStts.tts_seeds, initial(tts_seed))
	custom_emotes_tmp = sanitize_json(custom_emotes_tmp)
	custom_emotes = init_custom_emotes(custom_emotes_tmp)

	alternate_option = sanitize_integer(alternate_option, 0, 2, initial(alternate_option))
	job_support_high = sanitize_integer(job_support_high, 0, 65535, initial(job_support_high))
	job_support_med = sanitize_integer(job_support_med, 0, 65535, initial(job_support_med))
	job_support_low = sanitize_integer(job_support_low, 0, 65535, initial(job_support_low))
	job_medsci_high = sanitize_integer(job_medsci_high, 0, 65535, initial(job_medsci_high))
	job_medsci_med = sanitize_integer(job_medsci_med, 0, 65535, initial(job_medsci_med))
	job_medsci_low = sanitize_integer(job_medsci_low, 0, 65535, initial(job_medsci_low))
	job_engsec_high = sanitize_integer(job_engsec_high, 0, 65535, initial(job_engsec_high))
	job_engsec_med = sanitize_integer(job_engsec_med, 0, 65535, initial(job_engsec_med))
	job_engsec_low = sanitize_integer(job_engsec_low, 0, 65535, initial(job_engsec_low))
	job_karma_high = sanitize_integer(job_karma_high, 0, 65535, initial(job_karma_high))
	job_karma_med = sanitize_integer(job_karma_med, 0, 65535, initial(job_karma_med))
	job_karma_low = sanitize_integer(job_karma_low, 0, 65535, initial(job_karma_low))
	disabilities = sanitize_integer(disabilities, 0, 65535, initial(disabilities))

	socks			= sanitize_text(socks, initial(socks))
	body_accessory	= sanitize_text(body_accessory, initial(body_accessory))
	h_grad_style = sanitize_text(length(h_grad_style) ? h_grad_style : null, "None")
	var/list/expl = splittext(h_grad_offset_x, ",")
	if(length(expl) == 2)
		h_grad_offset_x = text2num(expl[1]) || 0
		h_grad_offset_y = text2num(expl[2]) || 0
	h_grad_colour = sanitize_hexcolor(h_grad_colour)
	h_grad_alpha = sanitize_integer(h_grad_alpha, 0, 200, initial(h_grad_alpha))

//	if(isnull(disabilities)) disabilities = 0
	if(!player_alt_titles) player_alt_titles = new()
	if(!organ_data) src.organ_data = list()
	if(!rlimb_data) src.rlimb_data = list()
	if(!loadout_gear) loadout_gear = list()

	// Check if the current body accessory exists
	if(!GLOB.body_accessory_by_name[body_accessory])
		body_accessory = null

	return 1

/datum/preferences/proc/form_choosen_gears()
	choosen_gears.Cut()
	for(var/gear in loadout_gear)
		var/datum/gear/geartype = GLOB.gear_datums[gear]
		if(!istype(geartype))
			loadout_gear -= gear // Delete wrong/outdated data
			continue
		if(!geartype.can_select(cl = parent, species_name = species, silent = TRUE)) // all other checks, no jobs in prefs, be quiet
			loadout_gear -= gear
			continue
		var/datum/gear/new_gear = new geartype.type
		for(var/tweak in loadout_gear[gear])
			for(var/datum/gear_tweak/gear_tweak in new_gear.gear_tweaks)
				if(istype(gear_tweak, text2path(tweak)))
					set_tweak_metadata(new_gear, gear_tweak, loadout_gear[gear][tweak])
		choosen_gears[gear] = new_gear

/datum/preferences/proc/save_character(client/C)

	for(var/title in player_alt_titles)
		var/datum/job/job = SSjobs.GetJob(title)
		if(job && !(player_alt_titles[title] in job.alt_titles))
			log_runtime(EXCEPTION("[C.key] had a malformed job title entry: '[title]:[player_alt_titles[title]]'. Removing!"), src)
			player_alt_titles -= title

	var/organlist
	var/rlimblist
	var/playertitlelist
	var/gearlist

	var/markingcolourslist = list2params(m_colours)
	var/markingstyleslist = list2params(m_styles)
	if(!isemptylist(organ_data))
		organlist = list2params(organ_data)
	if(!isemptylist(rlimb_data))
		rlimblist = list2params(rlimb_data)
	if(!isemptylist(player_alt_titles))
		playertitlelist = list2params(player_alt_titles)
	if(!isemptylist(loadout_gear))
		var/list/savelist = list()
		for(var/gear in loadout_gear)
			savelist[gear] = list2params(loadout_gear[gear])
		gearlist = list2params(savelist)

	var/datum/db_query/firstquery = SSdbcore.NewQuery("SELECT slot FROM [format_table_name("characters")] WHERE ckey=:ckey ORDER BY slot", list(
		"ckey" = C.ckey
	))
	if(!firstquery.warn_execute())
		qdel(firstquery)
		return
	while(firstquery.NextRow())
		if(text2num(firstquery.item[1]) == default_slot)
			var/datum/db_query/query = SSdbcore.NewQuery({"UPDATE [format_table_name("characters")]
											SET
												OOC_Notes=:metadata,
												real_name=:real_name,
												name_is_always_random=:be_random_name,
												gender=:gender,
												age=:age,
												species=:species,
												language=:language,
												hair_colour=:h_colour,
												secondary_hair_colour=:h_sec_colour,
												facial_hair_colour=:f_colour,
												secondary_facial_hair_colour=:f_sec_colour,
												skin_tone=:s_tone,
												skin_colour=:s_colour,
												marking_colours=:markingcolourslist,
												head_accessory_colour=:hacc_colour,
												hair_style_name=:h_style,
												facial_style_name=:f_style,
												marking_styles=:markingstyleslist,
												head_accessory_style_name=:ha_style,
												alt_head_name=:alt_head,
												eye_colour=:e_colour,
												underwear=:underwear,
												underwear_color=:underwear_color,
												undershirt=:undershirt,
												undershirt_color=:undershirt_color,
												backbag=:backbag,
												b_type=:b_type,
												alternate_option=:alternate_option,
												job_support_high=:job_support_high,
												job_support_med=:job_support_med,
												job_support_low=:job_support_low,
												job_medsci_high=:job_medsci_high,
												job_medsci_med=:job_medsci_med,
												job_medsci_low=:job_medsci_low,
												job_engsec_high=:job_engsec_high,
												job_engsec_med=:job_engsec_med,
												job_engsec_low=:job_engsec_low,
												job_karma_high=:job_karma_high,
												job_karma_med=:job_karma_med,
												job_karma_low=:job_karma_low,
												flavor_text=:flavor_text,
												med_record=:med_record,
												sec_record=:sec_record,
												gen_record=:gen_record,
												exploit_record=:exploit_record,
												player_alt_titles=:playertitlelist,
												disabilities=:disabilities,
												organ_data=:organlist,
												rlimb_data=:rlimblist,
												nanotrasen_relation=:nanotrasen_relation,
												speciesprefs=:speciesprefs,
												socks=:socks,
												body_accessory=:body_accessory,
												gear=:gearlist,
												autohiss=:autohiss_mode,
												hair_gradient=:h_grad_style,
												hair_gradient_offset=:h_grad_offset,
												hair_gradient_colour=:h_grad_colour,
												hair_gradient_alpha=:h_grad_alpha,
												uplink_pref=:uplink_pref,
												tts_seed=:tts_seed,
												custom_emotes=:custom_emotes
												WHERE ckey=:ckey
												AND slot=:slot"}, list(
													// OH GOD SO MANY PARAMETERS
													"metadata" = metadata,
													"real_name" = real_name,
													"be_random_name" = be_random_name,
													"gender" = gender,
													"age" = age,
													"species" = species,
													"language" = language,
													"h_colour" = h_colour,
													"h_sec_colour" = h_sec_colour,
													"f_colour" = f_colour,
													"f_sec_colour" = f_sec_colour,
													"s_tone" = s_tone,
													"s_colour" = s_colour,
													"markingcolourslist" = markingcolourslist,
													"hacc_colour" = hacc_colour,
													"h_style" = h_style,
													"f_style" = f_style,
													"markingstyleslist" = markingstyleslist,
													"ha_style" = ha_style,
													"alt_head" = alt_head || "",
													"e_colour" = e_colour,
													"underwear" = underwear,
													"underwear_color" = underwear_color,
													"undershirt" = undershirt,
													"undershirt_color" = undershirt_color,
													"backbag" = backbag,
													"b_type" = b_type,
													"alternate_option" = alternate_option,
													"job_support_high" = job_support_high,
													"job_support_med" = job_support_med,
													"job_support_low" = job_support_low,
													"job_medsci_high" = job_medsci_high,
													"job_medsci_med" = job_medsci_med,
													"job_medsci_low" = job_medsci_low,
													"job_engsec_high" = job_engsec_high,
													"job_engsec_med" = job_engsec_med,
													"job_engsec_low" = job_engsec_low,
													"job_karma_high" = job_karma_high,
													"job_karma_med" = job_karma_med,
													"job_karma_low" = job_karma_low,
													"flavor_text" = flavor_text,
													"med_record" = med_record,
													"sec_record" = sec_record,
													"gen_record" = gen_record,
													"exploit_record" = exploit_record,
													"playertitlelist" = (playertitlelist ? playertitlelist : ""), // This it intentnional. It wont work without it!
													"disabilities" = disabilities,
													"organlist" = (organlist ? organlist : ""),
													"rlimblist" = (rlimblist ? rlimblist : ""),
													"nanotrasen_relation" = nanotrasen_relation,
													"speciesprefs" = speciesprefs,
													"socks" = socks,
													"body_accessory" = (body_accessory ? body_accessory : ""),
													"gearlist" = (gearlist ? gearlist : ""),
													"autohiss_mode" = isnull(autohiss_mode) ? initial(autohiss_mode) : autohiss_mode,
													"h_grad_style" = h_grad_style,
													"h_grad_offset" = "[h_grad_offset_x],[h_grad_offset_y]",
													"h_grad_colour" = h_grad_colour,
													"h_grad_alpha" = h_grad_alpha,
													"uplink_pref" = uplink_pref,
													"tts_seed" = tts_seed,
													"custom_emotes" = json_encode(custom_emotes),
													"ckey" = C.ckey,
													"slot" = default_slot
												)
												)

			if(!query.warn_execute())
				qdel(firstquery)
				qdel(query)
				return
			qdel(firstquery)
			qdel(query)
			return 1

	qdel(firstquery)

	var/datum/db_query/query = SSdbcore.NewQuery({"
					INSERT INTO [format_table_name("characters")] (ckey, slot, OOC_Notes, real_name, name_is_always_random, gender,
											age, species, language,
											hair_colour, secondary_hair_colour,
											facial_hair_colour, secondary_facial_hair_colour,
											skin_tone, skin_colour,
											marking_colours,
											head_accessory_colour,
											hair_style_name,
											facial_style_name,
											marking_styles,
											head_accessory_style_name,
											alt_head_name,
											eye_colour,
											underwear, underwear_color, undershirt, undershirt_color,
											backbag, b_type, alternate_option,
											job_support_high, job_support_med, job_support_low,
											job_medsci_high, job_medsci_med, job_medsci_low,
											job_engsec_high, job_engsec_med, job_engsec_low,
											job_karma_high, job_karma_med, job_karma_low,
											flavor_text,
											med_record,
											sec_record,
											gen_record,
											exploit_record,
											player_alt_titles,
											disabilities, organ_data, rlimb_data, nanotrasen_relation, speciesprefs,
											socks, body_accessory, gear, autohiss, hair_gradient, hair_gradient_offset, hair_gradient_colour, hair_gradient_alpha, uplink_pref, tts_seed, custom_emotes)

					VALUES
											(:ckey, :slot, :metadata, :name, :be_random_name, :gender,
											:age, :species, :language,
											:h_colour, :h_sec_colour,
											:f_colour, :f_sec_colour,
											:s_tone, :s_colour,
											:markingcolourslist,
											:hacc_colour,
											:h_style,
											:f_style,
											:markingstyleslist,
											:ha_style,
											:alt_head,
											:e_colour,
											:underwear, :underwear_color, :undershirt, :undershirt_color,
											:backbag, :b_type, :alternate_option,
											:job_support_high, :job_support_med, :job_support_low,
											:job_medsci_high, :job_medsci_med, :job_medsci_low,
											:job_engsec_high, :job_engsec_med, :job_engsec_low,
											:job_karma_high, :job_karma_med, :job_karma_low,
											:flavor_text,
											:med_record,
											:sec_record,
											:gen_record,
											:exploit_record,
											:playertitlelist,
											:disabilities, :organlist, :rlimblist, :nanotrasen_relation, :speciesprefs,
											:socks, :body_accessory, :gearlist, :autohiss_mode, :h_grad_style, :h_grad_offset, :h_grad_colour, :h_grad_alpha, :uplink_pref, :tts_seed, :custom_emotes)

	"}, list(
		// This has too many params for anyone to look at this without going insae
		"ckey" = C.ckey,
		"slot" = default_slot,
		"metadata" = metadata,
		"name" = real_name,
		"be_random_name" = be_random_name,
		"gender" = gender,
		"age" = age,
		"species" = species,
		"language" = language,
		"h_colour" = h_colour,
		"h_sec_colour" = h_sec_colour,
		"f_colour" = f_colour,
		"f_sec_colour" = f_sec_colour,
		"s_tone" = s_tone,
		"s_colour" = s_colour,
		"markingcolourslist" = markingcolourslist,
		"hacc_colour" = hacc_colour,
		"h_style" = h_style,
		"f_style" = f_style,
		"markingstyleslist" = markingstyleslist,
		"ha_style" = ha_style,
		"alt_head" = alt_head,
		"e_colour" = e_colour,
		"underwear" = underwear,
		"underwear_color" = underwear_color,
		"undershirt" = undershirt,
		"undershirt_color" = undershirt_color,
		"backbag" = backbag,
		"b_type" = b_type,
		"alternate_option" = alternate_option,
		"job_support_high" = job_support_high,
		"job_support_med" = job_support_med,
		"job_support_low" = job_support_low,
		"job_medsci_high" = job_medsci_high,
		"job_medsci_med" = job_medsci_med,
		"job_medsci_low" = job_medsci_low,
		"job_engsec_high" = job_engsec_high,
		"job_engsec_med" = job_engsec_med,
		"job_engsec_low" = job_engsec_low,
		"job_karma_high" = job_karma_high,
		"job_karma_med" = job_karma_med,
		"job_karma_low" = job_karma_low,
		"flavor_text" = flavor_text,
		"med_record" = med_record,
		"sec_record" = sec_record,
		"gen_record" = gen_record,
		"exploit_record" = exploit_record,
		"playertitlelist" = (playertitlelist ? playertitlelist : ""), // This it intentnional. It wont work without it!
		"disabilities" = disabilities,
		"organlist" = (organlist ? organlist : ""),
		"rlimblist" = (rlimblist ? rlimblist : ""),
		"nanotrasen_relation" = nanotrasen_relation,
		"speciesprefs" = speciesprefs,
		"socks" = socks,
		"body_accessory" = (body_accessory ? body_accessory : ""),
		"gearlist" = (gearlist ? gearlist : ""),
		"autohiss_mode" = autohiss_mode,
		"h_grad_style" = h_grad_style,
		"h_grad_offset" = "[h_grad_offset_x],[h_grad_offset_y]",
		"h_grad_colour" = h_grad_colour,
		"h_grad_alpha" = h_grad_alpha,
		"uplink_pref" = uplink_pref,
		"tts_seed" = tts_seed,
		"custom_emotes" = json_encode(custom_emotes)
	))

	if(!query.warn_execute())
		qdel(query)
		return

	qdel(query)
	saved = TRUE
	return 1

/datum/preferences/proc/load_random_character_slot(client/C)
	var/datum/db_query/query = SSdbcore.NewQuery("SELECT slot FROM [format_table_name("characters")] WHERE ckey=:ckey ORDER BY slot", list(
		"ckey" = C.ckey
	))
	var/list/saves = list()

	if(!query.warn_execute(async = FALSE)) // Dont async this. Youll make roundstart slow.
		qdel(query)
		return

	while(query.NextRow())
		saves += text2num(query.item[1])
	qdel(query)

	if(!saves.len)
		load_character(C)
		return 0
	load_character(C,pick(saves))
	return 1

/datum/preferences/proc/clear_character_slot(client/C)
	. = FALSE
	// Is there a character in that slot?
	var/datum/db_query/query = SSdbcore.NewQuery("SELECT slot FROM [format_table_name("characters")] WHERE ckey=:ckey AND slot=:slot", list(
		"ckey" = C.ckey,
		"slot" = default_slot
	))

	if(!query.warn_execute())
		qdel(query)
		return

	if(!query.NextRow())
		qdel(query)
		return

	qdel(query)

	var/datum/db_query/delete_query = SSdbcore.NewQuery("DELETE FROM [format_table_name("characters")] WHERE ckey=:ckey AND slot=:slot", list(
		"ckey" = C.ckey,
		"slot" = default_slot
	))

	if(!delete_query.warn_execute())
		qdel(delete_query)
		return

	qdel(delete_query)

	saved = FALSE
	return TRUE

/**
  * Saves [/datum/preferences/proc/volume_mixer] for the current client.
  */
/datum/preferences/proc/save_volume_mixer()
	volume_mixer_saving = null
	//save_volume_mixer is called with a timer, the client may no longer be there.
	if(isnull(parent))
		return

	var/datum/db_query/update_query = SSdbcore.NewQuery(
		"UPDATE [format_table_name("player")] SET volume_mixer=:volume_mixer WHERE ckey=:ckey",
		list(
			"volume_mixer" = serialize_volume_mixer(volume_mixer),
			"ckey" = parent.ckey
		)
	)

	if(!update_query.warn_execute())
		qdel(update_query)
		return FALSE

	qdel(update_query)
	return TRUE

/datum/preferences/proc/init_custom_emotes(overrides)

	custom_emotes = overrides

	for(var/datum/keybinding/custom/custom_emote in GLOB.keybindings)
		var/emote_text = overrides && overrides[custom_emote.name]
		if(!emote_text)
			continue //we set anything without an override back to default, in case it isn't that
		custom_emotes[custom_emote.name] = emote_text

	return custom_emotes
