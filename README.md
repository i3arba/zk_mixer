# ZK Mixer Project

- Deposit: users can deposit ETH into the mixer to break the connection between depositor and withdrawer.
- Withdraw: users will withdraw using a ZK proof (Noir - generated off-chain) of knowledge of their deposit.
- We will only allow users to deposit a fixed amount of ETH (0.001 ETH)

## Proof
- Calculate the commitment using the secret and nullifier
- Need to check that the commitment is present in the Merkle Tree
    - proposed root
    - merkle proof
- Check the nullifier matches the public nullifier hash 

### Private Inputs
- Secret
- Nullifier
- Merkle Proof (intermediate nodes required to reconstruct the tree)
- Boolean to say whether the node has an even index

### Public Inputs
- proposed root
- nullifier hash