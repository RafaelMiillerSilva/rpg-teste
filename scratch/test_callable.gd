extends SceneTree
class TestClass:
	static func test_method():
		print('Metodo estatico chamado!')

func _init():
	var btn = Button.new()
	root.add_child(btn)
	btn.mouse_entered.connect(TestClass.test_method)
	print('Conexao com TestClass.test_method realizada com sucesso!')
	quit(0)
