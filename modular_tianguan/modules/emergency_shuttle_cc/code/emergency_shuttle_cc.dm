#define TIANGUAN_EMERGENCY_AWAY_DOCK "emergency_away"
#define TIANGUAN_CC_RECOVERY_WING_DOCK_DIR EAST

/datum/controller/subsystem/shuttle/proc/tianguan_get_cc_emergency_away_dock()
	for(var/obj/docking_port/stationary/dock as anything in stationary_docking_ports)
		if(dock.port_destinations != TIANGUAN_EMERGENCY_AWAY_DOCK)
			continue
		if(dock.area_type != /area/space)
			continue
		if(dock.dir != TIANGUAN_CC_RECOVERY_WING_DOCK_DIR)
			continue
		if(dock.width != 50 || dock.height != 50 || dock.dwidth != 25)
			continue
		return dock

/obj/docking_port/mobile/emergency/dock_id(id)
	if(id != TIANGUAN_EMERGENCY_AWAY_DOCK)
		return ..()

	var/obj/docking_port/stationary/selected_dock = SSshuttle.tianguan_get_cc_emergency_away_dock()
	if(selected_dock)
		log_shuttle("Tianguan emergency shuttle docking at updated CentCom dock [selected_dock] ([selected_dock.x], [selected_dock.y], [selected_dock.z]).")
		return initiate_docking(selected_dock)

	return ..()

#undef TIANGUAN_CC_RECOVERY_WING_DOCK_DIR
#undef TIANGUAN_EMERGENCY_AWAY_DOCK
