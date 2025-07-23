use dep::poseidon;
mod merkle_tree;
fn main(
    //Public Inputs
    root: pub Field,
    nullifier_hash: pub Field,
    recipient: pub Field,

    //Private Inputs
    nullifier: Field,
    secret: Field,
    merkle_proof: [Field; 20], //20 is the depth of the Merkle tree
    is_even: [bool; 20]
) {
    // compute the commitment from the nullifier and secret
    let commitment: Field = poseidon::poseidon2::Poseidon2::hash([nullifier, secret], 2);
    // check that the nullifier hash is matches the nullifier
    let computed_nullifier_hash: Field = poseidon::poseidon2::Poseidon2::hash([nullifier], 1);
    assert(computed_nullifier_hash == nullifier_hash, "Nullifier hash does not match");

    //check that the root matches the Merkle root
    //This `merkle_tree` is a module that we will create to handle Merkle tree operations
    let computed_root: Field = merkle_tree::compute_merkle_root(commitment, merkle_proof, is_even);
    assert(computed_root == root, "Merkle root does not match");

    //This is required to ensure no one can front-run the transaction an steal the funds
    let recipient_binding = recipient * recipient;
}