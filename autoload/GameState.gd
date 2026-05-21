extends Node

enum Mode { SINGLE, PVP_HOST, PVP_CLIENT }

var mode = Mode.SINGLE
var host_ip = "127.0.0.1"

const PORT = 7777
const MAX_PEERS = 1

func is_pvp():
	return mode == Mode.PVP_HOST or mode == Mode.PVP_CLIENT
