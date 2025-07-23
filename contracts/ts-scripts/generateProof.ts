import { Barretenberg, Fr, UltraHonkBackend } from "@aztec/bb.js";
import { ethers, keccak256 } from "ethers";
import { Noir }  from "@noir-lang/noir_js";
import fs from "fs";
import path from "path";
import { merkleTree } from "./MerkleTree.js";

// Load the global path to the circuit JSON file
const circuit = JSON.parse(fs.readFileSync(path.resolve(__dirname, "../../circuits/target/circuits.json"), "utf8"));

export default async function generatePoof() {
    // Initialize Barretenberg
    const bb = await Barretenberg.new();

    // Remove the path and script from the received args
    const inputs = process.argv.slice(2);
    
    // Extract the inputs to have a more verbose code
    const nullifier = Fr.fromString(inputs[0]);
    const secret = Fr.fromString(inputs[1]);
    const recipient = inputs[2];

    // Generate the nullifier hash
    // It is generate as a Field type, so we need to convert it
    const nullifier_hash = await bb.poseidon2Hash([nullifier]);
    
    // Generate the commitment from the nullifier and secret
    const commitment = await bb.poseidon2Hash([nullifier, secret]);

    // Slice the above inputs from the args to work with the leaves
    const leaves = inputs.slice(3);

    // Create a function to generate the Merkle Tree
    // This function will reconstruct the entire Merkle Tree
    const tree = await merkleTree(leaves);

    // Get the proof for a specific leaf
    const merkle_proof = tree.proof(tree.getIndex(commitment.toString()));

    try{
        // Initialize Noir using the circuit
        const noir = new Noir(circuit);
        // Initialize the UltraHonk backend
        const honk = new UltraHonkBackend(circuit.bytecode, {threads: 1});
        
        // Prepare the inputs to generate the witness
        const input = {
            //Public inputs
            root: merkle_proof.root,
            nullifier_hash: nullifier_hash.toString(),
            recipient: recipient,

            //Private inputs
            nullifier: nullifier.toString(),
            secret: secret.toString(),
            merkle_proof: merkle_proof.pathElements.map(i => i.toString()), // Convert Fr to string
            is_even: merkle_proof.pathIndices.map(i => i % 2 === 0), //Check if the index is even, set to false if odd
        };

        const { witness } = await noir.execute(input);

        //Silence the Logs
        const originalConsoleLog = console.log;
        //Suppress Noir's outputs
        console.log = () => {};

        // Generate the proof using the witness
        // The keccak option is set to true to use the keccak hash function
        // This is necessary for the Noir circuits that use keccak
        // If you are using a different hash function, set this option to false
        const { proof, publicInputs } = await honk.generateProof(witness, {keccak: true});
        
        // Restore the original console.log
        console.log = originalConsoleLog;

        // Abi encode the proof to return it
        // if it's not bytes, we may need to use toBuffer() or toString()
        const result = ethers.AbiCoder.defaultAbiCoder().encode(
            ["bytes", "bytes32[]"],
            [proof, publicInputs]
        );

        return result;

    } catch (error) {
        console.log(error);
        throw error;
    }
}

( async () => {
    generatePoof()
        .then((result) => {
            process.stdout.write(result);
            process.exit(0);
    })
    .catch((error) => {
                console.error(error);
                process.exit(1);
            });
})();