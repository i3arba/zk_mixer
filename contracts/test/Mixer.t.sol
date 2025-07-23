///SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { Test, console } from "forge-std/Test.sol";

import { IncrementalMerkleTree, Poseidon2 } from "src/IncrementalMerkleTree.sol";
import { Mixer } from "src/Mixer.sol";
import { HonkVerifier } from "src/Verifier.sol";

contract MixerTest is Test {
    Mixer mixer;
    HonkVerifier verifier;
    Poseidon2 poseidon;

    address recipient = makeAddr("recipient");

    function setUp() public {
        poseidon = new Poseidon2();
        verifier = new HonkVerifier();
        mixer = new Mixer(verifier, 20, poseidon);

        vm.label(recipient, "Recipient");
    }

    function test_MakeDeposit() public {
        // create a commitment
        (
            bytes32 commitment,
            bytes32 nullifier,
            bytes32 secret
        ) = _getCommitment();
        // make a deposit
        vm.expectEmit();
        emit Mixer.Mixer_Deposit(commitment, 0, block.timestamp);
        mixer.deposit{value: mixer.DENOMINATION()}(commitment);
    }

    function test_MakeWithdraw() public {
        /// Make a deposit
        (
            bytes32 commitment,
            bytes32 nullifier,
            bytes32 secret
        ) = _getCommitment();

        mixer.deposit{value: mixer.DENOMINATION()}(commitment);

        // create the leaves
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = commitment;

        // create a Proof
        (bytes memory proof, bytes32[] memory publicInputs )= _getProof(
            nullifier,
            secret,
            recipient,
            leaves //This is all the commitments already added to the tree.
        );

        // Ensure the proof is valid
        assertTrue(verifier.verify(proof, publicInputs));

        // Ensure the recipient does not have any funds yet
        assertEq(recipient.balance, 0);
        // Ensure the mixer has the funds
        assertEq(address(mixer).balance, mixer.DENOMINATION());

        // Make a withdraw
        vm.expectEmit();
        emit Mixer.Mixer_Withdraw(recipient, publicInputs[1]); // publicInputs[1] == nullifier

        mixer.withdraw(
            proof,
            publicInputs[0], // root
            publicInputs[1], // nullifierHash
            address(uint160(uint256(publicInputs[2]))) // recipient address converted from bytes32
        );

        // Ensure the recipient has the funds
        assertEq(recipient.balance, mixer.DENOMINATION());
        // Ensure the mixer has no funds left
        assertEq(address(mixer).balance, 0);
    }


    function _getCommitment() internal returns(bytes32 commitment_, bytes32 nullifier_, bytes32 secret_) {
        // inputs for the ffi call
        string[] memory inputs = new string[](3);
        inputs[0] = "npx";
        inputs[1] = "tsx";
        inputs[2] = "ts-scripts/generateCommitment.ts";

        // use ffi to run scripts in the CLI to create the commitment
        bytes memory result = vm.ffi(inputs);

        //abi decode the result
        (commitment_, nullifier_, secret_) = abi.decode(result, (bytes32, bytes32, bytes32));
    }

    function _getProof(
        bytes32 _nullifier,
        bytes32 _secret,
        address _recipient,
        bytes32[] memory _leaves
    ) internal returns(bytes memory proof_, bytes32[] memory publicInputs_) {
        // inputs for the ffi call
        string[] memory inputs = new string[](_leaves.length + 6);
        inputs[0] = "npx";
        inputs[1] = "tsx";
        inputs[2] = "ts-scripts/generateProof.ts";
        /*
            Our circuit require multiple inputs:
            root, nullifier_hash, recipient, nullifier,
            secret, merkle_proof and is_even.
            However, by sending the nullifier, secret, recipient and leaves
            we can calculate the root and nullifier_hash.
            So, we don't need to pass them as inputs.
        */
        inputs[3] = vm.toString(_nullifier);
        inputs[4] = vm.toString(_secret);
        inputs[5] = vm.toString(bytes32(uint256(uint160(_recipient))));
        /*
            In this scenario, we need to send only one leave.
            However, this will increase according to the number of leaves
            that the user has already deposited.
            So, we will use the length of the leaves array to create the inputs
            dynamically.
        */
        for (uint256 i; i < _leaves.length; i++) {
            inputs[6 + i] = vm.toString(_leaves[i]);
        }

        // use ffi to run scripts in the CLI to create the proof
        bytes memory result = vm.ffi(inputs);

        //abi decode the result
        (proof_, publicInputs_)= abi.decode(result, (bytes, bytes32[]));
    }
}