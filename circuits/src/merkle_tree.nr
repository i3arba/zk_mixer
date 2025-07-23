use dep::poseidon;
pub fn compute_merkle_root(
    leaf: Field,
    merkle_proof: [Field; 20], //20 is the depth of the Merkle tree
    is_even: [bool; 20]
) -> Field { 
    // mutable variable to hold the current node value
    let mut current_hash: Field = leaf;

    // increment through the levels
    for i in 0..20 {
        let (left, right) = if is_even[i] {
            (current_hash, merkle_proof[i])
        } else {
            (merkle_proof[i], current_hash)
        };
        // compute the hash of the current node
        current_hash = poseidon::poseidon2::Poseidon2::hash([left, right], 2);
    }
    // return the computed root
    current_hash
}