extends GutTest

var p: Parser

func before_each():
	p = Parser.new()

func after_each():
	#p.free()
	pass

func test_string():
	var parser = p.build_parser(p.strng, ["hello"])
	p.add_parser(parser)
	var result = p.run("hello word")
	var expected_result = {
		"index":5,
		"result":"hello",
		"targetString":"hello word",
		"isError": false,
		"error": null
	}
	assert_eq_deep(result, expected_result)

func test_string_error():
	var parser = p.build_parser(p.strng, ["hello"])
	p.add_parser(parser)
	var result = p.run("")
	var expected_result = {
		"index":0,
		"result":null,
		"targetString":"",
		"isError": true,
		"error": "str: Unexpected end of string"
	}
	assert_eq_deep(result, expected_result)


func test_string_map():
	var parser = p.build_parser(p.strng, ["hello"])
	parser = p.add_function(parser, "map", toUpper)
	p.add_parser(parser)
	var result = p.run("hello world")
	var expected_result = {
		"index":5,
		"result":"HELLO",
		"targetString":"hello world",
		"isError": false,
		"error": null
	}
	assert_eq_deep(result, expected_result)


func test_string_error_map():
	var parser = p.build_parser(p.strng, ["hello"])
	parser = p.add_function(parser, "error_map", errorPlus)
	p.add_parser(parser)
	var result = p.run("")
	var expected_result = {
		"index":0,
		"result":null,
		"targetString":"",
		"isError": true,
		"error": "str: Unexpected end of string 0"
	}
	assert_eq_deep(result, expected_result)


func test_letters():
	var parser = p.build_parser(p.letters)
	p.add_parser(parser)
	var result = p.run("hello123456")
	var expected_result = {
		"index":5,
		"result":"hello",
		"targetString":"hello123456",
		"isError": false,
		"error": null
	}
	assert_eq_deep(result, expected_result)


func test_digits():
	var parser = p.build_parser(p.digits)
	p.add_parser(parser)
	var result = p.run("123456hello")
	var expected_result = {
		"index":6,
		"result":"123456",
		"targetString":"123456hello",
		"isError": false,
		"error": null
	}
	assert_eq_deep(result, expected_result)


func test_sequenceOf():
	var parser = p.build_parser(p.sequenceOf, [
		p.build_parser(p.strng, ["hello"]),
		p.build_parser(p.strng, ["goodbay"]) 
	])
	p.add_parser(parser)
	var result = p.run("hellogoodbay")
	var expected_result = {
		"index":12,
		"result":["hello","goodbay"],
		"targetString":"hellogoodbay",
		"isError": false,
		"error": null
	}
	assert_eq_deep(result, expected_result)


func test_choice():
	var parser = p.build_parser(p.choice, [
		p.build_parser(p.strng, ["hello"]),
		p.build_parser(p.strng, ["goodbay"]) 
	])
	p.add_parser(parser)
	var result = p.run("goodbay")
	var expected_result = {
		"index":7,
		"result":"goodbay",
		"targetString":"goodbay",
		"isError": false,
		"error": null
	}
	assert_eq_deep(result, expected_result)


func test_many():
	var parser = p.build_parser(
					p.many,
					[p.build_parser(p.strng, ["hello"])]
				)
	p.add_parser(parser)
	var result = p.run("hellohellohello")
	var expected_result = {
		"index":15,
		"result":["hello", "hello", "hello"],
		"targetString":"hellohellohello",
		"isError": false,
		"error": null
	}
	assert_eq_deep(result, expected_result)


func test_many1():
	var parser = p.build_parser(
					p.many1,
					[p.build_parser(p.strng, ["hello"])]
				)
	p.add_parser(parser)
	var result = p.run("hellohellohello")
	var expected_result = {
		"index":15,
		"result":["hello", "hello", "hello"],
		"targetString":"hellohellohello",
		"isError": false,
		"error": null
	}
	assert_eq_deep(result, expected_result)
	result = p.run("hel")
	expected_result = {
		"index":0,
		"result":null,
		"targetString":"hel",
		"isError": true,
		"error": "many1: Unable to match a parser"
	}
	assert_eq_deep(result, expected_result)

func test_between():
	var parser = p.build_parser(
					p.between,
					[
						p.build_parser(p.strng, ["("]),
						p.build_parser(p.strng, ["hello"]),
						p.build_parser(p.strng, [")"]),
					]
				)
	p.add_parser(parser)
	var result = p.run("(hello)")
	var expected_result = {
		"index":7,
		"result":"hello",
		"targetString":"(hello)",
		"isError": false,
		"error": null
	}
	assert_eq_deep(result, expected_result)


func test_betweenBrackets():
	var parser = p.build_parser(
					p.betweenBrackets,
					[p.build_parser(p.strng, ["hello"])]
				)
	p.add_parser(parser)
	var result = p.run("(hello)")
	var expected_result = {
		"index":7,
		"result":"hello",
		"targetString":"(hello)",
		"isError": false,
		"error": null
	}
	assert_eq_deep(result, expected_result)


func test_chain():
	var mapn = func(currentState):
		var nextState = currentState.duplicate()
		nextState.result = {
			"type": "number",
			"value": int(nextState.result[0])
		}
		return nextState
		
	var numberParser = p.build_parser(
		p.sequenceOf,
		[p.build_parser(p.digits, [])])
	numberParser = p.add_function(numberParser, "map", mapn)
	
	var parser = p.build_parser(p.sequenceOf, [
		p.build_parser(p.letters, []),
		p.build_parser(p.strng, [":"]) 
	])
	
	var mapf = func(currentState):
		var nextState = currentState.duplicate()
		nextState.result = currentState.result[0]
		return nextState
	var chainf = func(currentState):
		var nextState = currentState.duplicate()
		if nextState.result == "number":
			return numberParser
		return nextState
	parser = p.add_function(parser, "map", mapf)
	parser = p.add_function(parser, "chain", chainf)
	p.add_parser(parser)
	var result = p.run("number:1234")
	var expected_result = {
		"targetString": "number:1234",
		"index": 11,
		"result": { "type": "number", "value": 1234 },
		"error": null,
		"isError": false
	}
	assert_eq_deep(result, expected_result)


func test_sepBy():
	var parser = p.build_parser(
					p.sepBy,
					[
						p.build_parser(p.digits),
						p.build_parser(p.strng, [","])
					]
				)

	p.add_parser(parser)
	var result = p.run("1,2,3,4,5")
	var expected_result = {
		"index":9,
		"result":["1","2","3","4","5"],
		"targetString":"1,2,3,4,5",
		"isError": false,
		"error": null
	}
	assert_eq_deep(result, expected_result)


func test_recursion():
	var digitsParser = p.build_parser(p.digits)
	var commaParser = p.build_parser(p.strng, [","])
	var choiceParser = p.build_parser(p.choice, [digitsParser, "recursive_array"])
	var sepByCommaParser = p.build_parser(p.sepBy, [choiceParser, commaParser])

	var parser = p.build_parser(
					p.betweenBrackets,
					[sepByCommaParser],
					"recursive_array"
				)
	
	p.add_parser(parser)
	print(p.parse_tree)
	var result = p.run("(1,(2,(3),4),5)")
	var expected_result = {
		"index":15,
		"result":["1",["2",["3"],"4"],"5"],
		"targetString":"(1,(2,(3),4),5)",
		"isError": false,
		"error": null
	}
	assert_eq_deep(result, expected_result)
	
func test_addition():
	var digitsParser = p.build_parser(p.digits)
	var plusSignParser = p.build_parser(p.strng, ["+"])
	var parser = p.build_parser(p.sepBy, [digitsParser, plusSignParser])
	parser = p.add_function(parser, "map", addFunc)
	p.add_parser(parser)
	var result = p.run("2+2")
	var expected_result = {
		"index":3,
		"result":4,
		"targetString":"2+2",
		"isError": false,
		"error": null
	}
	print(result)
	assert_eq_deep(result, expected_result)

###

func toUpper(currentState):
	var nextState = currentState.duplicate()
	nextState.result = currentState.result.to_upper()
	return nextState

func errorPlus(currentState, index: int):
	var nextState = currentState.duplicate()
	nextState.error = "%s %d" % [currentState.error, index]
	return nextState

func addFunc(currentState):
	var nextState = currentState.duplicate()
	var r := 0
	for n in currentState.result:
		r += int(n)
	nextState.result = r #currentState.result.to_upper()
	return nextState
