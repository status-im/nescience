## A rudimentary DSL

import macros, strutils, strformat, sets

const UINT = "uint"

# TODO this is hacky
# var importedProcDefs
var procDefs {.compileTime, global.} = toHashSet(["input", "toConstraint", "add", "sub", "mul", "div", "pow", "equal", "inverse", "constrainBoolean", "xor", "toBinary", "fromBinary", "select", "lookup"])
# var localProcDefs {.compileTime.} = initHashSet[string]()
var hasMain {.compileTime.} = false

proc getProcName(procStatement: NimNode): string =
    for statement in procStatement:
        if statement.kind == nnkPostfix:
            return strVal(statement[1])
        elif statement.kind == nnkIdent:
            return strVal(statement)

proc getInputs(parameters:NimNode): seq[NimNode] =
    assert parameters.kind == nnkFormalParams,
        "parameters.kind is not nnkFormalParams"
    result = newSeq[NimNode]()
    for identDef in parameters:
        case identDef.kind:
        of nnkIdentDefs:
            var inputs = newSeq[string]()
            for child in identDef:
                if child.kind == nnkIdent:
                    inputs.add(strVal(child))
                elif child.kind == nnkBracketExpr:
                    let inputType = strVal(child[0])
                    if inputType == "Private" or inputType == "Public":
                        for input in inputs:
                            result.add(parseStmt(&"var {input} = circuit.input(\"{input}\", {inputType})"))
        else:
            discard

proc expandStmtList(statement: NimNode, local:bool): NimNode =
    assert statement.kind == nnkProcDef or statement.kind == nnkFuncDef,
        "statement.kind is not nnkProcDef or nnkFuncDef"
    result = copyNimTree(statement)
    expectKind(statement[6], nnkStmtList)
    var stmtlist = copyNimTree(statement[6])

    # TODO traverse the stmtlist, looking for Call, match ident with imported and local proc defs and insert circuit as parameter
    proc traverse(node:NimNode): NimNode =
        var node = copyNimTree(node)
        case node.kind:
        of nnkCall:
            # Check if ident is in procDefs, and insert circuit param
            if node[0].kind == nnkIdent:
                let procName = strVal(node[0])
                if procDefs.contains(procName):
                    node.insert(1, newIdentNode("circuit"))
            elif node[0].kind == nnkDotExpr:
                # TODO this is cheating
                let procName = strVal(node[0][node[0].len-1])
                node.insert(1, newIdentNode("circuit"))
        of nnkCommand:
            if strVal(node[0]) == "assert":
                # TODO only overwrite assert if both params are constraints
                expectKind(node[1], nnkInfix)
                if strVal(node[1][0]) == "==":
                    # TODO tried getType here but returned "node has no type", so fuck it override the assert regardless of type
                    node = parseStmt(&"circuit.equal({node[1][1]}, {node[1][2]})")
            discard
        else:
            for i in 0..<node.len:
                node[i] = traverse(node[i])
        return node
    stmtlist = traverse(stmtlist)

    if getProcName(statement) == "main":
        # strip params from main and insert them as inputs
        var inputs = getInputs(statement[3])

        while inputs.len > 0:
            stmtlist.insert(0, inputs.pop())

        result[3] = nnkFormalParams.newTree(
            newEmptyNode(),
            nnkIdentDefs.newTree(
                newIdentNode("circuit"),
                nnkVarTy.newTree(
                    nnkBracketExpr.newTree(
                            newIdentNode("Circuit"), newIdentNode("T"))),
                newEmptyNode()
            ))
    
    result[6] = stmtlist

proc expandProcDef(statement: NimNode, local: bool): NimNode =
    assert statement.kind == nnkProcDef or statement.kind == nnkFuncDef,
        "statement.kind is not nnkProcDef or nnkFuncDef"
    result = copyNimTree(statement)

    if statement[2].kind == nnkEmpty:
        # insert [T]
        result[2] = nnkGenericParams.newTree(
            nnkIdentDefs.newTree(newIdentNode("T"), newEmptyNode(), newEmptyNode()))
    else:
        error("Supporting generics in circuit macro is not yet supported")

    let parameters = statement[3]
    if parameters.kind == nnkFormalParams:
        # Replace uint return type with Constraint[T]
        if parameters[0].kind == nnkIdent and strVal(parameters[0]) == UINT:
            result[3][0] = nnkBracketExpr.newTree(newIdentNode("Constraint"), newIdentNode("T"))

        # Replace uint in parameter types with Constraint[T] | Constant
        for i, identDef in parameters:
            if identDef.kind == nnkIdentDefs:
                for j, ident in identDef:
                    if ident.kind == nnkIdent and strVal(ident) == UINT:
                        result[3][i][j] = nnkVarTy.newTree(nnkInfix.newTree(
                            newIdentNode("|"),
                            nnkBracketExpr.newTree(
                                newIdentNode("Constraint"), newIdentNode("T")),
                            newIdentNode("Constant")
                        ))
        # Insert circuit: Circuit as first param into proc
        var insertCircuit = true
        if parameters.len > 1:
            if parameters[1].kind == nnkIdentDefs:
                expectKind(parameters[1][0], nnkIdent)
                if strVal(parameters[1][0]) == "circuit":
                    insertCircuit = false
        if insertCircuit:
            result[3].insert(1, nnkIdentDefs.newTree(
                newIdentNode("circuit"),
                nnkVarTy.newTree(
                    nnkBracketExpr.newTree(
                            newIdentNode("Circuit"), newIdentNode("T"))),
                newEmptyNode()
            ))
    
    # Insert proc ident for replacement in proc stmtlist
    let procName = getProcName(statement)
    if procName != "main":
        procDefs.incl(procName)
    elif not hasMain and local:
        hasMain = true # We don't modify main here because the parameters turn into proc call statements
    else:
        error("main already defined in circuit macro")

proc parseMacroBody(body: NimNode, local:bool) : NimNode =
    # First Pass, collect proc names, expand definitions
    result = copyNimTree(body)
    for i, statement in body:
        case statement.kind:
        of nnkProcDef, nnkFuncDef:
            result[i] = expandProcDef(statement, local)
        else:
            discard
    # Second Pass, expand proc statement list
    for i, statement in result:
        case statement.kind:
        of nnkProcDef, nnkFuncDef:
            result[i] = expandStmtList(statement, local)
        else:
            discard

proc parseMacroHead(head: NimNode): (string, NimNode) =
    var
        circuitIdent:string
        typeIdent = "Int256"
    case head.kind:
    of nnkIdent:
        circuitIdent = strVal(head)
    of nnkBracketExpr:
        circuitIdent = strVal(head[0])
        typeIdent = strVal(head[1])
    of nnkInfix:
        # allow but ignore *
        circuitIdent = strVal(head[1])
        typeIdent = strVal(head[2][0])
    else:
        error("invalid circuit macro header description")
    (circuitIdent, parseStmt(&"var {circuitIdent} = newCircuit({typeIdent})"))

macro circuit*(head, body: untyped = nil): untyped =
    ## Some sugar to flatten Nim code execution via Nescience API calls
    ## returns an instance of Circuit[T]
    ##
    result = newStmtList()
    hasMain = false
    var
        local = false # TODO hack for context, was going to differentiate procDefs
        stmts: NimNode
        circuitLabel: string

    if head == nil:
        error("circuit macro has no head or body")
    elif body == nil and head.kind == nnkStmtList:
        # Then we are only transforming the proc definitions
        stmts = head
        local = false
    else:
        let (label, headStmt) = parseMacroHead(head)
        result.add(headStmt)
        stmts = body
        local = true
        circuitLabel = label
    result.add(parseMacroBody(stmts, local))


    if not hasMain and local:
        error("circuit macro has no main defined")
    elif hasMain and local and not circuitLabel.isEmptyOrWhitespace():
        echo repr(result)
        result.add(
            nnkCall.newTree(
                newIdentNode("main"),
                newIdentNode(circuitLabel)
            )
        )