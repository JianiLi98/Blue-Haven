# File: size_probe.gd
extends Node2D

# 把你的真实路径填进来（示例）
const GROUNDS := [
	"res://assets/ground0.png",
	"res://assets/ground1.png",
	"res://assets/ground2.png",
	"res://assets/ground3.png",
]

# -------- 方式 A：用 Image.get_size() 从图片文件读取 --------
func get_image_size(path: String) -> Vector2i:
	var img := Image.new()
	var err := img.load(path)  # Godot 4 直接用 load(path)
	if err != OK:
		push_error("Failed to load: %s (err=%d)" % [path, err])
		return Vector2i.ZERO
	return img.get_size()   # 返回 Vector2i(width, height)

# -------- 方式 B：如果你有 Texture2D 资源，也可以这样 --------
func get_texture_size(path: String) -> Vector2i:
	var tex := load(path) as Texture2D
	if tex == null:
		push_error("Failed to load Texture2D: %s" % path)
		return Vector2i.ZERO
	return tex.get_size()

func _ready() -> void:
	var results := {}  # 存结果：{ path: {size, width, height, center} }

	for p in GROUNDS:
		var size := get_image_size(p)   # 或改成 get_texture_size(p)
		var center := Vector2(size) * 0.5
		results[p] = {
			"size": size,
			"width": size.x,
			"height": size.y,
			"center": center,
		}
		print("%s -> %dx%d  center=(%.1f, %.1f)" % [p, size.x, size.y, center.x, center.y])

	# 如果你还要用来设置碰撞/偏移，可以这样取：
	# var s0: Vector2i = results[GROUNDS[0]].size
	# var c0: Vector2   = results[GROUNDS[0]].center
