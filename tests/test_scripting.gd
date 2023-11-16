extends GutTest

var s: Scripting

func before_each():
	s = Scripting.new()

func after_each():
	#p.free()
	pass

func test_numbers():
	var result = s.eval("6;")
	assert_eq(result, 6)
	result = s.eval("20;")
	assert_eq(result, 20)
	result = s.eval("3.5;")
	assert_eq(result, 3.5)
	result = s.eval("4.50;")
	assert_eq(result, 4.5)
	result = s.eval("3.145;")
	assert_eq(result, 3.145)

func test_negative_numbers():
	var result = s.eval("-6;")
	assert_eq(result, -6)
	result = s.eval("-20;")
	assert_eq(result, -20)
	result = s.eval("-3.5;")
	assert_eq(result, -3.5)
	result = s.eval("-4.50;")
	assert_eq(result, -4.5)
	result = s.eval("-3.145;")
	assert_eq(result, -3.145)

func test_addition():
	var result = s.eval("sum(2,2);")
	assert_eq(result, 4)
	result = s.eval("sum(sum(2,2),sum(2,2));")
	assert_eq(result, 8)
	result = s.eval("sum(20,30);")
	assert_eq(result, 50)
	result = s.eval("sum(2.3,3.0);")
	assert_eq(result, 5.3)

func test_vector():
	var result = s.eval("v2(1,2);")
	assert_eq(result, Vector2(1,2))
	result = s.eval("sum(v2(1,2), v2(3,4));")
	assert_eq(result, Vector2(4,6))

func test_substraction():
	var result = s.eval("sub(2,2);")
	assert_eq(result, 0)
	result = s.eval("sub(sub(sub(2,2),2),2);")
	assert_eq(result, -4)
	result = s.eval("sub(20,30);")
	assert_eq(result, -10)
	result = s.eval("sub(2.5,3.0);")
	assert_eq(result, -0.5)

func test_operator_order():
	var result = s.eval("mult(sum(2,2),2);")
	assert_eq(result, 8)
	result = s.eval("mult(sum(2.1,2.1),2.2);")
	assert_almost_eq(result, 9.24, 0.001)

func test_assignation():
	var result = s.eval("$speed:2.6;")
	assert_almost_eq(s.variables["speed"], 2.6, 0.001)
	assert_almost_eq(result, 2.6, 0.001)
	result = s.eval("$speedb:$speed;")
	assert_almost_eq(s.variables["speedb"], 2.6, 0.001)
	result = s.eval("$speedb:mult($speed,2);")
	assert_almost_eq(s.variables["speedb"], 5.2, 0.001)

func test_multiline():
	var result = s.eval("2;4;")
	assert_almost_eq(result, 4.0, 0.001)
	result = s.eval("$speed:2;$health:mult($speed,2);")
	assert_almost_eq(s.variables["health"], 4.0, 0.001)

func test_spaces():
	var result = s.eval("2; 4;")
	assert_almost_eq(result, 4.0, 0.001)
	result = s.eval("$speed: 2;\n$health: mult($speed, 2);")
	assert_almost_eq(s.variables["health"], 4.0, 0.001)
