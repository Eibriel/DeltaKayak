class_name Parser
# Source:
# https://www.youtube.com/playlist?list=PLP29wDx6QmW5yfO1LAgO8kU3aQEj8SIrU

var parse_tree = []
var parse_database = {}

func strng(parserState, parameters):
	if parserState.isError:
		return parserState
		
	parserState = parserState.duplicate()
	var substring = parserState.targetString.substr(parserState["index"])
	
	if substring.length() == 0:
		return updateParserError(parserState, "str: Unexpected end of string")
	
	if substring.begins_with(parameters[0]):
		parserState = updateParserState(
						parserState,
						parserState["index"] + parameters[0].length(),
						parameters[0]
					)
	else:
		parserState = updateParserError(parserState, "str: Error")
	return parserState

## Matches a letter, upper and lowercase
func letters(parserState, parameters):
	if parserState.isError:
		return parserState
	
	parserState = parserState.duplicate()
	var substring = parserState.targetString.substr(parserState["index"])
	
	if substring.length() == 0:
		return updateParserError(parserState, "letters: Unexpected end of string")

	var regex = RegEx.new()
	regex.compile("^[A-Za-z]+")
	var result = regex.search(substring)
	
	if result:
		parserState = updateParserState(
						parserState,
						parserState["index"] + result.get_string().length(),
						result.get_string()
					)
	else:
		parserState = updateParserError(parserState, "letters: Error")
	return parserState

## Matches a digit from 0 to 9
func digits(parserState, parameters):
	if parserState.isError:
		return parserState
	
	parserState = parserState.duplicate()
	var substring = parserState.targetString.substr(parserState["index"])
	
	if substring.length() == 0:
		return updateParserError(parserState, "digits: Unexpected end of string")

	var regex = RegEx.new()
	regex.compile("^[0-9]+")
	var result = regex.search(substring)
	
	if result:
		parserState = updateParserState(
						parserState,
						parserState["index"] + result.get_string().length(),
						result.get_string()
					)
	else:
		parserState = updateParserError(parserState, "digits: Error")
	return parserState


func sequenceOf(parserState, parameters):
	if parserState.isError:
		return parserState
	
	var results = []
	var nextState = parserState.duplicate()
	
	for p in parameters:
		nextState = parse(nextState, p)
		results.append(nextState.result)

	if nextState.isError:
		return nextState

	return updateParserResult(nextState, results)

## Takes an array of parsers, tries to parse one by one
## returns the first successful one
func choice(parserState, parameters):
	if parserState.isError:
		return parserState
	
	for p in parameters:
		var nextState = parse(parserState, p)
		if not nextState.isError:
			return nextState

	return updateParserError(parserState, "choice: Error")

## Matches 0 or more parsers
func many(parserState, parameters):
	if parserState.isError:
		return parserState
	
	var results = []
	var testState = parserState.duplicate()
	var done = false
	while not done:
		testState = parse(testState, parameters[0])
		if testState.isError:
			done = true
		else:
			results.append(testState.result)

	return updateParserState(parserState, testState.index, results)

## Matches 1 or more parsers
func many1(parserState, parameters):
	if parserState.isError:
		return parserState
	
	var results = []
	var testState = parserState.duplicate()
	var done = false
	while not done:
		testState = parse(testState, parameters[0])
		if testState.isError:
			done = true
		else:
			results.append(testState.result)

	if results.size() == 0:
		return updateParserError(parserState, "many1: Unable to match a parser")

	return updateParserState(parserState, testState.index, results)


func between_map(currentState):
	if currentState.isError:
		return currentState
	
	var nextState = currentState.duplicate()
	# return only contentParser
	nextState.result = nextState.result[1]
	return nextState

func between(parserState, parameters):
	if parserState.isError:
		return parserState
	var sequenceOfParser = build_parser(sequenceOf, [
			parameters[0],  # leftParser
			parameters[1],  # contentParser
			parameters[2],  # rightParser
		]
	)
	#sequenceOfParser = add_function(sequenceOfParser, "map", funcref(self, "between_map"))
	sequenceOfParser = add_function(sequenceOfParser, "map", between_map)
	
	return parse(parserState, sequenceOfParser)


func betweenBrackets(parserState, parameters):
	if parserState.isError:
		return parserState
	var betweenParser = build_parser(between, [
							build_parser(strng, ["("]),
							parameters[0],  # contentParser
							build_parser(strng, [")"])
						])
	
	return parse(parserState, betweenParser)


func sepBy(parserState, parameters):
	if parserState.isError:
		return parserState
	var results = []
	var nextState = parserState.duplicate()

	var parser_thing = parameters[0]
	var parser_separator = parameters[1]

	while true:
		var thingState = parse(nextState, parser_thing)
		if thingState.isError:
			break
		
		results.append(thingState.result)
		nextState = thingState
		
		var separatorState = parse(nextState, parser_separator)
		if separatorState.isError:
			break
		
		nextState = separatorState
	
	return updateParserResult(nextState, results)


func updateParserResult(state, result):
	var new_state = state.duplicate()
	new_state["result"] = result
	return new_state


func updateParserState(state, index: int, result):
	var new_state = state.duplicate()
	new_state["index"] = index
	new_state["result"] = result
	return new_state


func updateParserError(state, errorMsg: String):
	var new_state = state.duplicate()
	new_state["isError"] = true
	new_state["error"] = errorMsg
	return new_state


func map(currentState, map: Callable):
	if currentState.isError:
		return currentState
	
	var nextState = map.call(currentState.duplicate())

	return updateParserResult(currentState, nextState.result)


func error_map(currentState, map: Callable):
	if not currentState.isError:
		return currentState
	
	var nextState = map.call(currentState, currentState.index)
	
	return updateParserError(currentState, nextState.error)


func chain(currentState, chainer: Callable):
	if currentState.isError:
		return currentState
	
	#var nextParser = build_parser(parser_name, [currentState.result])
	var nextParser = chainer.call(currentState.duplicate())
	return parse(currentState, nextParser)


func parse(currentState, tree):
	if typeof(tree) == TYPE_STRING:
		# If tree is just the ID to a tree
		tree = parse_database[tree].duplicate()
	if tree.id:
		# If ID is set, store on database
		parse_database[tree.id] = tree.duplicate()
	currentState = tree.parser_name.call(currentState, tree.parameters)
	for function in tree.functions:
		if function.type == "map":
			currentState = map(currentState, function.function)
		if function.type == "chain":
			currentState = chain(currentState, function.function)
		if  function.type == "error_map":
			currentState = error_map(currentState, function.function)
	return currentState


func run (targetString: String):
	var currentState = {
		"targetString": targetString,
		"index": 0,
		"result": null,
		"error": null,
		"isError": false
	}
	
	return parse(currentState, parse_tree)


func build_parser(parser_name: Callable, parameters := [], id = null):
	# map = null, error_map = null, chain = null
	var data = {
		"parser_name": parser_name,
		"parameters": parameters,
		"functions": [],
		"id": id
	}
	return data


func add_function(_parser, function_name: String, function: Callable):
	_parser.functions.append({
		"type": function_name,
		"function": function
	})
	return _parser


func add_parser(parser_data) -> void:
	parse_tree = parser_data
