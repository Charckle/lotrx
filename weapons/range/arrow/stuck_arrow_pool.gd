extends MultiMeshInstance2D

const MAX_STUCK_ARROWS := 1000
var arrow_count := 0


func _ready():
	var arrow_texture = load("uid://dqigqhd7rx2p4") as Texture2D
	var tex_size = arrow_texture.get_size()

	var quad = QuadMesh.new()
	quad.size = tex_size

	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.instance_count = MAX_STUCK_ARROWS
	mm.visible_instance_count = 0
	mm.mesh = quad

	multimesh = mm
	texture = arrow_texture


func add_arrow(arrow_position: Vector2, arrow_rotation: float):
	var idx = arrow_count % MAX_STUCK_ARROWS
	multimesh.set_instance_transform_2d(idx, Transform2D(arrow_rotation, arrow_position))
	if arrow_count < MAX_STUCK_ARROWS:
		arrow_count += 1
		multimesh.visible_instance_count = arrow_count
