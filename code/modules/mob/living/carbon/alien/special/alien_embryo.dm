// This is to replace the previous datum/disease/alien_embryo for slightly improved handling and maintainability
// It functions almost identically (see code/datums/diseases/alien_embryo.dm)
/obj/item/organ/internal/body_egg/alien_embryo
	name = "alien embryo"
	icon = 'icons/mob/nonhuman-player/alien.dmi'
	icon_state = "larva0_dead"
	food_reagents = list(/datum/reagent/consumable/nutriment = 5, /datum/reagent/toxin/acid = 10)
	///What stage of growth the embryo is at. Developed embryos give the host symptoms suggesting that an embryo is inside them.
	var/stage = 0
	/// Are we bursting out of the poor sucker who's the xeno mom?
	var/bursting = FALSE
	/// How long does it take to advance one stage? Growth time * 5 = how long till we make a Larva!
	var/growth_time = 60 SECONDS

/obj/item/organ/internal/body_egg/alien_embryo/Initialize(mapload)
	. = ..()
	advance_embryo_stage()

/obj/item/organ/internal/body_egg/alien_embryo/on_find(mob/living/finder)
	..()
	if(stage < 5)
		to_chat(finder, span_notice("It's small and weak, barely the size of a foetus."))
	else
		to_chat(finder, span_notice("It's grown quite large, and writhes slightly as you look at it."))
		if(prob(10))
			attempt_grow(permadeath = FALSE)

/obj/item/organ/internal/body_egg/alien_embryo/on_life(seconds_per_tick, times_fired)
	. = ..()
	if(QDELETED(src) || QDELETED(owner))
		return

	switch(stage)
		if(3, 4)
			if(SPT_PROB(1, seconds_per_tick))
				owner.emote("sneeze")
			if(SPT_PROB(1, seconds_per_tick))
				owner.emote("cough")
			if(SPT_PROB(1, seconds_per_tick))
				to_chat(owner, span_danger("Your throat feels sore."))
			if(SPT_PROB(1, seconds_per_tick))
				to_chat(owner, span_danger("Mucous runs down the back of your throat."))
		if(5)
			if(SPT_PROB(1, seconds_per_tick))
				owner.emote("sneeze")
			if(SPT_PROB(1, seconds_per_tick))
				owner.emote("cough")
			if(SPT_PROB(2, seconds_per_tick))
				to_chat(owner, span_danger("Your muscles ache."))
				if(prob(20))
					owner.take_bodypart_damage(1)
			if(SPT_PROB(2, seconds_per_tick))
				to_chat(owner, span_danger("Your chest hurts."))
				if(prob(20))
					owner.adjustToxLoss(6)
					owner.emote("gasp")
					owner.visible_message(span_warning("[owner] starts shaking uncontrollably!"), span_userdanger("You start shaking uncontrollably!"))
					owner.Unconscious(12 SECONDS)
					owner.set_jitter_if_lower(12 SECONDS)
				if(prob(44))
					to_chat(owner, span_danger("Your heart thrashes wildly."))
					owner.set_jitter_if_lower(6 SECONDS)
		if(6)
			to_chat(owner, span_boldwarning(pick("It's in your insides!", "It's gnawing you!", "Make it stop!", "You're going to die!", "It's tearing you apart!")))
			owner.adjustToxLoss(1 * seconds_per_tick) // Why is this [TOX]?

/// Controls Xenomorph Embryo growth. If embryo is fully grown (or overgrown), stop the proc. If not, increase the stage by one and if it's not fully grown (stage 6), add a timer to do this proc again after however long the growth time variable is.
/obj/item/organ/internal/body_egg/alien_embryo/proc/advance_embryo_stage()
	if(stage >= 6)
		return
	stage++
	if(stage < 6)
		INVOKE_ASYNC(src, PROC_REF(RefreshInfectionImage))
		var/slowdown = 1
		if(!isnull(owner)) // it gestates out of bodies.
			if(HAS_TRAIT(owner, TRAIT_VIRUS_RESISTANCE))
				slowdown *= 2 // spaceacillin doubles the time it takes to grow
			if(owner.has_status_effect(/datum/status_effect/nest_sustenance))
				slowdown *= 0.80 //egg gestates 20% faster if you're trapped in a nest

		addtimer(CALLBACK(src, PROC_REF(advance_embryo_stage)), growth_time*slowdown)

/obj/item/organ/internal/body_egg/alien_embryo/egg_process()
	if(stage == 6 && prob(50))
		for(var/datum/surgery/operations as anything in owner.surgeries)
			if(operations.location != BODY_ZONE_CHEST)
				continue
			if(!istype(operations.get_surgery_step(), /datum/surgery_step/manipulate_organs/internal))
				continue
			attempt_grow(permadeath = FALSE)
			return
		attempt_grow()

/// Attempt to burst an alien outside of the host, getting a ghost to play as the xeno.
/obj/item/organ/internal/body_egg/alien_embryo/proc/attempt_grow(permadeath = TRUE)
	if(QDELETED(owner) || bursting)
		return

	bursting = TRUE
	var/mob/chosen_one = SSpolling.poll_ghosts_for_target(
		question = "An [span_notice("alien")] is bursting out of [span_danger(owner.real_name)]!",
		role = ROLE_ALIEN,
		check_jobban = ROLE_ALIEN,
		poll_time = 20 SECONDS,
		checked_target = src,
		ignore_category = POLL_IGNORE_ALIEN_LARVA,
		alert_pic = owner,
		role_name_text = "alien larva",
		chat_text_border_icon = /mob/living/carbon/alien/larva,
	)
	on_poll_concluded(permadeath, chosen_one)

/// Poll has concluded with a suitor
/obj/item/organ/internal/body_egg/alien_embryo/proc/on_poll_concluded(permadeath, mob/dead/observer/ghost)
	if(QDELETED(owner))
		return

	if(isnull(ghost))
		bursting = FALSE
		stage = 5 // If no ghosts sign up for the Larva, let's regress our growth by one minute, we will try again!
		owner.set_jitter(3 SECONDS)
		addtimer(CALLBACK(src, PROC_REF(advance_embryo_stage)), growth_time)
		return

	owner.chestburst = CARBON_IS_CHEST_BURSTING
	owner.update_burst()
	owner.visible_message(span_warning("[owner] starts shaking uncontrollably!"), span_userdanger("You start shaking uncontrollably!"))
	owner.emote("burstscream")
	owner.Unconscious(180 SECONDS)
	owner.set_jitter_if_lower(250 SECONDS)

	var/atom/xeno_loc = get_turf(owner)
	var/mob/living/carbon/alien/larva/new_xeno = new(xeno_loc)
	new_xeno.key = ghost.key
	SEND_SOUND(new_xeno, sound('sound/voice/hiss5.ogg',0,0,0,100)) //To get the player's attention
	new_xeno.add_traits(list(TRAIT_HANDS_BLOCKED, TRAIT_IMMOBILIZED, TRAIT_NO_TRANSFORM), type) //so we don't move during the bursting animation
	new_xeno.SetInvisibility(INVISIBILITY_MAXIMUM, id=type)

	sleep(4 SECONDS)

	if(QDELETED(src) || QDELETED(owner))
		qdel(new_xeno)
		CRASH("AttemptGrow failed due to the early qdeletion of source or owner.")

	if(!isnull(new_xeno))
		new_xeno.remove_traits(list(TRAIT_HANDS_BLOCKED, TRAIT_IMMOBILIZED, TRAIT_NO_TRANSFORM), type)
		new_xeno.RemoveInvisibility(type)

	owner.apply_damage(80, BRUTE, BODY_ZONE_CHEST)
	if(permadeath)
		// to keep things simple, bursting without permadeath will not even apply the chestburst overlay
		// chestburst var is also used for preventing bursters from revival, so...
		owner.chestburst = CARBON_CHEST_BURSTED
		owner.update_burst()
	else
		owner.chestburst = CARBON_NO_CHEST_BURST
		owner.update_burst()
	playsound(src, 'sound/effects/wounds/pierce3.ogg', 40, TRUE)
	owner.death()
	new_xeno.visible_message(span_danger("[permadeath ? "[new_xeno] bursts out of [owner]'s chest in a shower of gore!" : "[new_xeno] awkwardly slips out of [owner]'s chest!"]"), span_userdanger("You exit [owner], your previous host."), span_hear("You hear organic matter ripping and tearing!"))
	qdel(src)


/*----------------------------------------
Proc: AddInfectionImages(C)
Des: Adds the infection image to all aliens for this embryo
----------------------------------------*/
/obj/item/organ/internal/body_egg/alien_embryo/AddInfectionImages()
	for(var/mob/living/carbon/alien/alien in GLOB.player_list)
		var/I = image('icons/mob/nonhuman-player/alien.dmi', loc = owner, icon_state = "infected[stage]")
		alien.client?.images += I

/*----------------------------------------
Proc: RemoveInfectionImage(C)
Des: Removes all images from the mob infected by this embryo
----------------------------------------*/
/obj/item/organ/internal/body_egg/alien_embryo/RemoveInfectionImages()
	for(var/mob/living/carbon/alien/alien in GLOB.player_list)
		for(var/image/I in alien.client?.images)
			var/searchfor = "infected"
			if(I.loc == owner && findtext(I.icon_state, searchfor, 1, length(searchfor) + 1))
				qdel(I)
