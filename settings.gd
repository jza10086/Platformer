## Business-owned setting defaults, constraints and UI hierarchy. No runtime side effects.
extends RefCounted

static func schema() -> Dictionary:
	return {
		"schema_format": 3,
		"settings_version": 1,
		"fields": {
			"duration": {
				"type": "int",
				"default": 180,
				"title": "回合秒数",
				"audience": "room",
				"apply": "next_round",
				"min": 30,
				"max": 600,
				"control": "number"
			},
			"left": {
				"type": "array",
				"default": [
					{
						"kind": "key",
						"code": 65,
						"physical": true
					},
					{
						"kind": "key",
						"code": 4194319,
						"physical": true
					}
				],
				"title": "向左",
				"audience": "local",
				"apply": "immediate",
				"action": "move_left",
				"control": "binding",
				"items": {
					"type": "object",
					"format": "binding"
				},
				"max_items": 2
			},
			"right": {
				"type": "array",
				"default": [
					{
						"kind": "key",
						"code": 68,
						"physical": true
					},
					{
						"kind": "key",
						"code": 4194321,
						"physical": true
					}
				],
				"title": "向右",
				"audience": "local",
				"apply": "immediate",
				"action": "move_right",
				"control": "binding",
				"items": {
					"type": "object",
					"format": "binding"
				},
				"max_items": 2
			},
			"jump": {
				"type": "array",
				"default": [
					{
						"kind": "key",
						"code": 32,
						"physical": true
					},
					{
						"kind": "key",
						"code": 87,
						"physical": true
					}
				],
				"title": "跳跃",
				"audience": "local",
				"apply": "immediate",
				"action": "platform_jump",
				"control": "binding",
				"items": {
					"type": "object",
					"format": "binding"
				},
				"max_items": 2
			},
			"run": {
				"type": "array",
				"default": [
					{
						"kind": "key",
						"code": 4194325,
						"physical": true
					},
					{
						"kind": "key",
						"code": 88,
						"physical": true
					}
				],
				"title": "加速",
				"audience": "local",
				"apply": "immediate",
				"action": "platform_run",
				"control": "binding",
				"items": {
					"type": "object",
					"format": "binding"
				},
				"max_items": 2
			},
			"down": {
				"type": "array",
				"default": [
					{
						"kind": "key",
						"code": 83,
						"physical": true
					},
					{
						"kind": "key",
						"code": 4194322,
						"physical": true
					}
				],
				"title": "进入水管",
				"audience": "local",
				"apply": "immediate",
				"action": "platform_down",
				"control": "binding",
				"items": {
					"type": "object",
					"format": "binding"
				},
				"max_items": 2
			}
		},
		"layout": [
			{
				"id": "room",
				"title": "游戏规则",
				"expanded": true,
				"children": [
					{
						"field": "duration"
					}
				]
			},
			{
				"id": "local",
				"title": "本机偏好",
				"expanded": true,
				"children": [
					{
						"field": "left"
					},
					{
						"field": "right"
					},
					{
						"field": "jump"
					},
					{
						"field": "run"
					},
					{
						"field": "down"
					}
				]
			}
		]
	}
