# Nescience

A Zero Knowledge Toolkit aims to support circuit generation (API & DSL), multiple curves and proving systems.

To Run:

`make update`
`make test`

The ambitions are as follows:

## Circuit Generation
Provable Programs
- [x] API
- [ ] DSL
- [x] R1CS

## Proving Systems
- [ ] [groth16](https://eprint.iacr.org/2016/260.pdf)
- [ ] [gm17](https://eprint.iacr.org/2017/540.pdf)
- [ ] [PLONK](https://eprint.iacr.org/2019/953.pdf)
- [ ] [Halo](https://eprint.iacr.org/2019/1021.pdf)
- [ ] [zk-STARKs](https://eprint.iacr.org/2018/046) ? 

## Curve Support
- [ ] BN128
- [ ] BN254
- [ ] BN256
- [ ] BLS12-381
- [ ] BLS12-377 (Zexe inner curve)
- [ ] SW6 (Zexe outer curve)
- [ ] [BW6-761](https://eprint.iacr.org/2020/351.pdf) (More efficient Zexe outer curve)
- [ ] JubJub ?

## Gadgets
Standard Library for Circuits
- [ ] Comparators
- [ ] Binary Add/Sub
- [ ] Blake2s
- [ ] sha256
- [ ] [Poseidon](https://eprint.iacr.org/2019/458.pdf)
- [ ] MIMC
- [ ] [Sparse Merkle Tree](https://docs.iden3.io/publications/pdfs/Merkle-Tree.pdf)
- [ ] [Baby Jubjub](https://iden3-docs.readthedocs.io/en/latest/_downloads/33717d75ab84e11313cc0d8a090b636f/Baby-Jubjub.pdf)
- [ ] [Pederson Hash](https://docs.iden3.io/publications/pdfs/Pedersen-Hash.pdf)
- [ ] [EdDSA](https://github.com/iden3/iden3-docs/blob/master/source/iden3_repos/research/publications/zkproof-standards-workshop-2/ed-dsa/ed-dsa.rst)

## MPC
Structured Reference String (SRS) generation for Setup
- [ ] ["Powers of Tau"](https://eprint.iacr.org/2017/1050) protocol for groth16

## Special Thanks

Check out these great project which have been the inspiration and reference for Nescience.

- [Circom](https://github.com/iden3/circom) / [SnarkJS](https://github.com/iden3/snarkjs) (Javascript)
- [libsnark](https://github.com/scipr-lab/libsnark) (C++)
- [Gnark](https://github.com/ConsenSys/gnark) (Go)
- [Bellman](https://github.com/zkcrypto/bellman/) (Rust)