# res://CODE/combat/Layers.gd
extends Node
class_name Layers

const LAYER_PLAYER_HURTBOX := 12   # bit 12 → value 2048
const LAYER_ENEMY_HURTBOX  := 13   # bit 13 → value 4096

enum Faction { PLAYER, ENEMY }
