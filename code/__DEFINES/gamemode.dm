//antag paradise gamemode type defines
#define ANTAG_SINGLE	"antag_single"
#define ANTAG_DOUBLE	"antag_double"
#define ANTAG_TRIPPLE	"antag_tripple"
#define ANTAG_RANDOM	"antag_random"

//objective defines
#define TARGET_INVALID_IS_OWNER		1
#define TARGET_INVALID_NOT_HUMAN	2
#define TARGET_INVALID_DEAD			3
#define TARGET_INVALID_NOCKEY		4
#define TARGET_INVALID_UNREACHABLE	5
#define TARGET_INVALID_GOLEM		6
#define TARGET_INVALID_EVENT		7
#define TARGET_INVALID_IS_TARGET	8
#define TARGET_INVALID_BLACKLISTED	9
#define TARGET_INVALID_CHANGELING	10

//gamemode istype helpers
#define GAMEMODE_IS_BLOB		(SSticker && istype(SSticker.mode, /datum/game_mode/blob))
#define GAMEMODE_IS_CULT		(SSticker && istype(SSticker.mode, /datum/game_mode/cult))
#define GAMEMODE_IS_HEIST		(SSticker && istype(SSticker.mode, /datum/game_mode/heist))
#define GAMEMODE_IS_NUCLEAR		(SSticker && istype(SSticker.mode, /datum/game_mode/nuclear))
#define GAMEMODE_IS_REVOLUTION	(SSticker && istype(SSticker.mode, /datum/game_mode/revolution))
#define GAMEMODE_IS_WIZARD		(SSticker && istype(SSticker.mode, /datum/game_mode/wizard))
#define GAMEMODE_IS_RAGIN_MAGES (SSticker && istype(SSticker.mode, /datum/game_mode/wizard/raginmages))
#define GAMEMODE_IS_METEOR      (SSticker && istype(SSticker.mode, /datum/game_mode/meteor))

// special roles
// Distinct from the ROLE_X defines because some antags have multiple special roles but only one ban type
#define SPECIAL_ROLE_ABDUCTOR_AGENT         "Abductor Agent"
#define SPECIAL_ROLE_ABDUCTOR_SCIENTIST     "Abductor Scientist"
#define SPECIAL_ROLE_BLOB                   "Blob"
#define SPECIAL_ROLE_BLOB_OVERMIND          "Blob Overmind"
#define SPECIAL_ROLE_BLOB_MINION            "Blob Minion"
#define SPECIAL_ROLE_BORER                  "Borer"
#define SPECIAL_ROLE_CARP                   "Space Carp"
#define SPECIAL_ROLE_CHANGELING             "Changeling"
#define SPECIAL_ROLE_CULTIST                "Cultist"
#define SPECIAL_ROLE_CLOCKER                "Clockwork cultist"
#define SPECIAL_ROLE_DEATHSQUAD             "Death Commando"
#define SPECIAL_ROLE_ERT                    "Response Team"
#define SPECIAL_ROLE_FREE_GOLEM             "Free Golem"
#define SPECIAL_ROLE_GOLEM                  "Golem"
#define SPECIAL_ROLE_HEAD_REV               "Head Revolutionary"
#define SPECIAL_ROLE_HEADSLUG               "HeadSlug"
#define SPECIAL_ROLE_HONKSQUAD              "Honksquad"
#define SPECIAL_ROLE_REV                    "Revolutionary"
#define SPECIAL_ROLE_MORPH                  "Morph"
#define SPECIAL_ROLE_MULTIVERSE             "Multiverse Traveller"
#define SPECIAL_ROLE_NUKEOPS                "Syndicate"
#define SPECIAL_ROLE_PYROCLASTIC_SLIME 	    "Pyroclastic Anomaly Slime"
#define SPECIAL_ROLE_RAIDER                 "Vox Raider"
#define SPECIAL_ROLE_REVENANT               "Revenant"
#define SPECIAL_ROLE_SHADOWLING             "Shadowling"
#define SPECIAL_ROLE_SHADOWLING_THRALL      "Shadowling Thrall"
#define SPECIAL_ROLE_DEMON                  "Demon"
#define SPECIAL_ROLE_SUPER                  "Super"
#define SPECIAL_ROLE_SYNDICATE_DEATHSQUAD   "Syndicate Commando"
#define SPECIAL_ROLE_TRAITOR                "Traitor"
#define SPECIAL_ROLE_VAMPIRE                "Vampire"
#define SPECIAL_ROLE_VAMPIRE_THRALL         "Vampire Thrall"
#define SPECIAL_ROLE_WIZARD                 "Wizard"
#define SPECIAL_ROLE_WIZARD_APPRENTICE      "Wizard Apprentice"
#define SPECIAL_ROLE_XENOMORPH              "Xenomorph"
#define SPECIAL_ROLE_XENOMORPH_QUEEN        "Xenomorph Queen"
#define SPECIAL_ROLE_XENOMORPH_HUNTER       "Xenomorph Hunter"
#define SPECIAL_ROLE_XENOMORPH_DRONE        "Xenomorph Drone"
#define SPECIAL_ROLE_XENOMORPH_SENTINEL     "Xenomorph Sentinel"
#define SPECIAL_ROLE_XENOMORPH_LARVA        "Xenomorph Larva"
#define SPECIAL_ROLE_FACEHUGGER				"Facehugger"
#define SPECIAL_ROLE_TERROR_SPIDER 			"Terror Spider"
#define SPECIAL_ROLE_TERROR_QUEEN 			"Terror Queen"
#define SPECIAL_ROLE_TERROR_PRINCE 			"Terror Prince"
#define SPECIAL_ROLE_TERROR_PRINCESS 		"Terror Princess"
#define SPECIAL_ROLE_TERROR_DEFILER 		"Terror Defiler"
#define SPECIAL_ROLE_TERROR_EMPRESS 		"Terror Empress"
#define SPECIAL_ROLE_TERROR_DESTROYER 		"Terror Destroyer"
#define SPECIAL_ROLE_SPACE_NINJA            "Space Ninja"
#define SPECIAL_ROLE_THIEF                  "Thief"
#define SPECIAL_ROLE_SPACE_DRAGON           "Space Dragon"
#define SPECIAL_ROLE_EVENTMISC              "Event Role"
#define SPECIAL_ROLE_MALFAI                 "Malfunctioning AI"
#define SPECIAL_ROLE_SINTOUCHED             "Sintouched"
#define SPECIAL_ROLE_DEVIL_PAWN             "Devil's pawn"
