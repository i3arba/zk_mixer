import { Barretenberg, Fr } from '@aztec/bb.js';
import { ethers }  from 'ethers';

export default async function generateCommitment() : Promise<string> {
    // Initialize BB
    const bb = await Barretenberg.new();

    // Generate random nullifier and secret
    // Note: In a real application, these should be securely generated and managed
    const nullifier = Fr.random();
    const secret = Fr.random();

    // Generate the commitment using Poseidon hash
    const commitment: Fr = await bb.poseidon2Hash([nullifier, secret]);

    // Abi encode the commitment
    // Note: The commitment is a Fr type, which needs to be converted to bytes32 using the toBuffer method or toString method
    const result = ethers.AbiCoder.defaultAbiCoder().encode(
        ["bytes32", "bytes32", "bytes32"],
        [commitment.toBuffer(), nullifier.toBuffer(), secret.toBuffer()]
    )

    // Return the abi encoded commitment
    return result;
}

( async () => {
    generateCommitment()
        .then((result) => {
            process.stdout.write(result);
            process.exit(0);
}).catch((error) => {
            console.error(error);
            process.exit(1);
        });
})();