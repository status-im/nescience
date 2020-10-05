## A rudimentary Nim to Circuit Compiler

import macros, stint
import circuit, api, types

proc getProcName(procStatement: NimNode): string =
    for statement in procStatement:
        if statement.kind == nnkPostfix:
            return strVal(statement[1])
        elif statement.kind == nnkIdent:
            return strVal(statement)

proc parseProcStatement(procStatement: NimNode, circuit: var Circuit) =
    if getProcName(procStatement) == "main":
        # TODO parse FormalParams
        # for each IdentDefs, call circuit.input(Ident[0], Ident[1]) "x", "Private"
        discard
    
proc generateCircuitFromNim(statements: NimNode) =
    var circuit = newCircuit(Int256)

    for statement in statements:
        case statement.kind:
        of nnkProcDef:
            parseProcStatement(statement, circuit)
        else:
            discard
            


macro circuit*(head, body: untyped): untyped =
    ## Convert Nim into a series of arithmetic operations, which are the basis of our constraints.
    ## Each statement is in the form of: var1 op var2 = out
    ## Where (op) is either +, -, * or /
    ## 
    ## We do this as our first step in converting into our proof medium, the polynomial form.
    ##
    expectKind(head, nnkIdent) # use Ident here so we can return a circuit with this name we can perform operations with
    expectKind(body, nnkStmtList)
    echo treeRepr(body)
    generateCircuitFromNim(body)
    # Generate R1CS