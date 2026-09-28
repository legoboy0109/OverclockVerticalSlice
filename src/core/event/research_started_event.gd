## ResearchStartedEvent — a player committed Credits + AP to start a tech (CR-14).
class_name ResearchStartedEvent
extends Event

@export var entity_id: int = -1
@export var owner: int = -1
@export var tech: TechDef
@export var turns_remaining: int = 0
