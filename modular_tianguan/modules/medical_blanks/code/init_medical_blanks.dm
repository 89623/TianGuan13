#define TIAN_GUAN_BLANKS_FILE "config/tianguan/blanks.json"

/// Loaded at global init, merged into GLOB.paper_blanks on first photocopier init.
GLOBAL_LIST_INIT(tianguan_paper_blanks, load_tianguan_blanks())

/proc/load_tianguan_blanks()
	if(!fexists(TIAN_GUAN_BLANKS_FILE))
		return null
	var/list/blanks_json = json_decode(file2text(TIAN_GUAN_BLANKS_FILE))
	if(!length(blanks_json))
		return null

	var/list/parsed_blanks = list()
	for(var/paper_blank in blanks_json)
		parsed_blanks += list("[paper_blank["code"]]" = paper_blank)

	return parsed_blanks

/// Inject Tianguan blanks into the global paper_blanks list.
/// Called once from the first photocopier to Initialize.
/proc/inject_tianguan_blanks()
	if(!GLOB.paper_blanks || !GLOB.tianguan_paper_blanks)
		return
	var/injected = 0
	for(var/blank_id in GLOB.tianguan_paper_blanks)
		if(!(blank_id in GLOB.paper_blanks))
			GLOB.paper_blanks[blank_id] = GLOB.tianguan_paper_blanks[blank_id]
			injected++
	return injected

GLOBAL_VAR_INIT(tianguan_blanks_injected, FALSE)

/obj/machinery/photocopier/Initialize(mapload)
	. = ..()
	if(!GLOB.tianguan_blanks_injected)
		GLOB.tianguan_blanks_injected = TRUE
		inject_tianguan_blanks()

#undef TIAN_GUAN_BLANKS_FILE
