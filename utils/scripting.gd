class_name Scripting

var p:Parser
var variables := {}

var parsed := false
var parsed_tree

func _init():
	init()

func init():
	p = Parser.new()
	
	var numberMap = func(currentState):
		var nextState = currentState.duplicate()
		var num := 0.0
		var negative := false
		if typeof(nextState.result[0]) == TYPE_STRING and nextState.result[0] == "-":
			nextState.result.pop_front()
			negative = true
		if nextState.result.size() == 1:
			if negative:
				num = float(nextState.result[0][0])
			else:
				num = float(nextState.result[0])
		else:
			num = float("%s.%s" % [nextState.result[0][0], nextState.result[2][0]])
		if negative:
			num *= -1.0
		nextState.result = {
			"type": "number",
			"value": num
		}
		return nextState
		
	var numberParser = p.build_parser(
		p.choice, [
			p.build_parser(p.sequenceOf,[
				p.build_parser(p.sequenceOf,[p.build_parser(p.digits,[])]),
				p.build_parser(p.strng, ["."]),
				p.build_parser(p.sequenceOf,[p.build_parser(p.digits,[])])
			]),
			p.build_parser(p.sequenceOf,[
				p.build_parser(p.strng, ["-"]),
				p.build_parser(p.sequenceOf,[p.build_parser(p.digits,[])]),
				p.build_parser(p.strng, ["."]),
				p.build_parser(p.sequenceOf,[p.build_parser(p.digits,[])])
			]),
			p.build_parser(p.sequenceOf,[
				p.build_parser(p.strng, ["-"]),
				p.build_parser(p.sequenceOf,[p.build_parser(p.digits,[])])
			]),
			p.build_parser(p.sequenceOf,[p.build_parser(p.digits,[])])
		])
	numberParser = p.add_function(numberParser, "map", numberMap)
	
	var stringParser = p.build_parser(p.sequenceOf,[p.build_parser(p.letters,[])])
	
	var varnameMap = func(currentState):
		var nextState = currentState.duplicate()
		nextState.result = {
			"type": "variable",
			"varname": nextState.result[1][0]
		}
		return nextState
	var varnameParser = p.build_parser(p.sequenceOf,[
		p.build_parser(p.strng,["$"]),
		stringParser
	])
	varnameParser = p.add_function(varnameParser, "map", varnameMap)
	
	var vectorMap = func(currentState):
		var nextState = currentState.duplicate()
		nextState.result = {
			"type": "vector",
			"x": nextState.result[1],
			"y": nextState.result[3]
		}
		return nextState
	var vectorParser = p.build_parser(p.sequenceOf,[
		p.build_parser(p.strng,["v2("]),
		"expression",
		p.build_parser(p.strng,[","]),
		"expression",
		p.build_parser(p.strng,[")"]),
	])
	vectorParser = p.add_function(vectorParser, "map", vectorMap)
	
	var operatorMap = func(currentState):
		var nextState = currentState.duplicate()
		nextState.result = {
			"type": "operation",
			"op": nextState.result[0],
			"a": nextState.result[2],
			"b": nextState.result[4]
		}
		return nextState
	var operationParser = p.build_parser(p.sequenceOf, [
		p.build_parser(p.choice,[
			p.build_parser(p.strng, ["sum"]),
			p.build_parser(p.strng, ["sub"]),
			p.build_parser(p.strng, ["mult"]),
			p.build_parser(p.strng, ["div"]),
		]),
		p.build_parser(p.strng, ["("]),
		#p.build_parser(p.choice,[
		#	numberParser,
		#	varnameParser,
		#	vectorParser,
		#	"operation"
		#]),
		"expression",
		p.build_parser(p.strng, [","]),
		#p.build_parser(p.choice,[
		#	numberParser,
		#	varnameParser,
		#	vectorParser,
		#	"operation"
		#]),
		"expression",
		p.build_parser(p.strng, [")"])
	], "operation")
	var chainf = func(currentState):
		var nextState = currentState.duplicate()
		if nextState.result == "number":
			return numberParser
		return nextState
	operationParser = p.add_function(operationParser, "map", operatorMap)
	#operationParser = p.add_function(operationParser, "chain", chainf)
	
	var expressionParser = p.build_parser(p.choice,[
		operationParser,
		numberParser,
		varnameParser,
		vectorParser
	], "expression")
	
	var assignationMap = func(currentState):
		var nextState = currentState.duplicate()
		nextState.result = {
			"type": "assignation",
			"varname": nextState.result[0].varname,
			"value": nextState.result[2],
		}
		return nextState
	var assignationParser = p.build_parser(p.sequenceOf, [
		varnameParser,
		p.build_parser(p.strng, [":"]),
		expressionParser
	])
	assignationParser = p.add_function(assignationParser, "map", assignationMap)
	
	var endlineParser = p.build_parser(p.strng, [";"])
	
	var lineMap = func(currentState):
		var nextState = currentState.duplicate()
		nextState.result = nextState.result[0]
		return nextState
	var lineParser = p.build_parser(p.sequenceOf, [
		p.build_parser(p.choice, [
			assignationParser,
			expressionParser,
		]),
		endlineParser
	])
	lineParser = p.add_function(lineParser, "map", lineMap)
	
	var multilineParser = p.build_parser(p.many1, [lineParser])
	
	p.add_parser(multilineParser)


func eval(str: String):
	if not parsed:
		str = str.replace(" ", "")
		str = str.strip_escapes()
		parsed_tree = p.run(str)
		parsed = true
	var result = null
	for line in parsed_tree.result:
		result = interpret(line)
	return result

func interpret(parse_tree: Dictionary):
	if parse_tree.type == "number":
		return parse_tree.value
	if parse_tree.type == "vector":
		return Vector2(interpret(parse_tree.x), interpret(parse_tree.y))
	if parse_tree.type == "operation":
		match parse_tree.op:
			"sum":
				return interpret(parse_tree.a) + interpret(parse_tree.b)
			"sub":
				return interpret(parse_tree.a) - interpret(parse_tree.b)
			"mult":
				return interpret(parse_tree.a) * interpret(parse_tree.b)
			"div":
				return interpret(parse_tree.a) / interpret(parse_tree.b)
	if parse_tree.type == "assignation":
		var val = interpret(parse_tree.value)
		variables[parse_tree.varname] = interpret(parse_tree.value)
		return val
	if parse_tree.type == "variable":
		return variables[parse_tree.varname]


