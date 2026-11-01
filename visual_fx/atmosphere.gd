extends CanvasLayer
# Purely visual overlay: no collision, input, or gameplay state.
var canvas: Node2D

func _ready() -> void:
    layer = 100
    canvas = Node2D.new()
    canvas.set_script(load("res://visual_fx/atmosphere_canvas.gd"))
    add_child(canvas)
    set_process(true)

func _process(_delta: float) -> void:
    if is_instance_valid(canvas):
        canvas.queue_redraw()
