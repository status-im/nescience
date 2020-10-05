## Implements Rank-1 Constraint System

import stint, stew/endians2
import os, streams, endians, strformat, system, tables
# import ../algebra/fields

type
    Section = object of RootObj
        sectionType: uint32
        sectionSize: uint64

    R1CSHeaderSection = ref object of Section
        fieldSize*: uint32 # Variable size for field elements allows us to shrink the size of the file and to work with any field.
        prime*: UInt256
        numberOfWires*: uint32
        numberOfPublicOutputs*: uint32
        numberOfPublicInputs*: uint32
        numberOfPrivateInputs*: uint32
        numberOfLabels*: uint64 # Signals?
        numberOfConstraints*: uint32

    R1CSConstraint* = array[3, Table[uint32, UInt256]]

    R1CSConstraintsSection* = ref object of Section
        constraints*: seq[R1CSConstraint]

    R1CSMapSection* = ref object of Section
        map*: seq[uint64]

    R1CS = object
        magic: array[4, char]
        version: uint32
        numberOfSections: uint32
        headerSection*: R1CSHeaderSection
        constraintSection*: R1CSConstraintsSection
        mapSection*: R1CSMapSection


const MAX_VERSION = 1

proc readUInt32LE(stream: Stream): uint32 {.inline.} =
  var raw_bytes = stream.readUInt32
  littleEndian32(addr result, addr raw_bytes)

proc readUInt64LE(stream: Stream): uint64 {.inline.} =
  var raw_bytes = stream.readUInt64
  littleEndian64(addr result, addr raw_bytes)

proc readBigInt(stream: Stream, length: uint32): UInt256 {.inline.} =
    doAssert length == 32,
        &"readBigInt() with length {length} is not implemented, only supports UInt256"
    var buffer: array[128, byte]
    discard stream.readData(buffer.addr, length.int)
    return fromBytesLE(UInt256,  buffer)


proc readHeader(stream: Stream): R1CSHeaderSection =
    let sectionType = stream.readUInt32LE
    doAssert sectionType == 1,
        "Invalid Header Section"
    let sectionSize = stream.readUInt64LE
    let fieldSize = stream.readUInt32LE
    return R1CSHeaderSection(
        sectionType: sectionType,
        sectionSize: sectionSize,
        fieldSize: fieldSize,
        prime: readBigInt(stream, fieldSize),
        numberOfWires: stream.readUInt32LE,
        numberOfPublicOutputs: stream.readUInt32LE,
        numberOfPublicInputs: stream.readUInt32LE,
        numberOfPrivateInputs: stream.readUInt32LE,
        numberOfLabels: stream.readUInt64LE, # Labels.. or Signals ?
        numberOfConstraints: stream.readUInt32LE
    )


proc readLinearCombination(stream: Stream, fieldSize: uint32): Table[uint32, UInt256] =
    ## A Linear Combination has the form
    ## $$ a_{j,0}w_0 + a_{j,1}w_1 + ... + a_{j,n}w_{n} $$
    ## 
    var linearCombination = initTable[uint32, UInt256]()
    let numberOfNonZeroFactors = stream.readUInt32LE
    for i in 0..<numberOfNonZeroFactors:
        let factorIndex = stream.readUInt32LE # WireId
        let factorValue = readBigInt(stream, fieldSize) # WARN snarkjs wraps this in res.Fr.e( ?
        linearCombination[factorIndex] = factorValue
    return linearCombination


proc readConstraint(stream: Stream, fieldSize: uint32): R1CSConstraint =
    ## Each constraint contains 3 linear combinations - A, B, C.
    ## The constraint is defined as: A*B-C = 0
    ## 
    let A = readLinearCombination(stream, fieldSize)
    let B = readLinearCombination(stream, fieldSize)
    let C = readLinearCombination(stream, fieldSize)
    return [A, B, C]


proc readConstraintSection(stream: Stream, numberOfConstraints, fieldSize: uint32): R1CSConstraintsSection =
    let sectionType = stream.readUInt32LE
    doAssert sectionType == 2,
        "Invalid Constraints Section"
    let sectionSize = stream.readUInt64LE
    var constraints: seq[R1CSConstraint] = @[]
    for i in 0..<numberOfConstraints:
        constraints.add(readConstraint(stream, fieldSize))
    return R1CSConstraintsSection(
        sectionType: sectionType,
        sectionSize: sectionSize,
        constraints: constraints
    )


proc readMapSection(stream: Stream, numberOfWires: uint32): R1CSMapSection =
    ## 
    let sectionType = stream.readUInt32LE
    doAssert sectionType == 3,
        "Invalid Map Section"
    let sectionSize = stream.readUInt64LE
    var map: seq[uint64] = @[]
    for i in 0..<numberOfWires:
        map.add(stream.readUInt64LE)
    return R1CSMapSection(
        sectionType: sectionType,
        sectionSize: sectionSize,
        map: map
    )


proc load*(filePath: string): R1CS =
    ## Loads a binary *.r1cs file, compatible with Circom's R1CS Binary Format as defined here
    ## https://github.com/iden3/r1csfile/blob/master/doc/r1cs_bin_format.md
    ##
    if unlikely(not existsFile(filePath)):
        raise newException(IOError, &"\"{filePath}\" does not exist")

    let stream = newFileStream(filePath, mode=fmRead)
    defer: stream.close()

    var magicString: array[4, char]
    discard stream.readData(magicString.addr, 4)

    assert magicString == ['r', '1', 'c', 's'],
        &"\"{filePath}\" is not a valid r1cs binary"

    let version = stream.readUInt32LE
    assert MAX_VERSION >= version,
        &"Version {version} not supported"

    let numberOfSections = stream.readUInt32LE
    let headerSection = readHeader(stream)
    let constraintSection = readConstraintSection(stream, headerSection.numberOfConstraints, headerSection.fieldSize)
    let mapSection = readMapSection(stream, headerSection.numberOfWires)

    return R1CS(
        magic: magicString,
        version: version,
        numberOfSections: numberOfSections,
        headerSection: headerSection,
        constraintSection: constraintSection,
        mapSection: mapSection
    )


proc save*(r1cs: R1CS) =
    ## Saves a binary *.r1cs file
    assert(false, "Not Implemented")
