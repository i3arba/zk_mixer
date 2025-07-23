//SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { IncrementalMerkleTree, Poseidon2 } from "src/IncrementalMerkleTree.sol";

import { IVerifier } from "src/Verifier.sol";

contract Mixer is IncrementalMerkleTree {

    /*/////////////////////////////////////////////////
                    State Variables
    /////////////////////////////////////////////////*/
    ///@notice Immutable variable to store the verifier contract address
    IVerifier immutable i_verifier;
    ///@notice constant variable to store the ether amount users are allowed to send
    uint256 public constant DENOMINATION = 0.001 ether;

    ///@notice mapping to store the commitment used overtime and avoid collision
    mapping(bytes32 commitment => bool isUsed) s_commitments;
    ///@notice mapping to store the nullifier hashes used to prevent double spending
    mapping(bytes32 nullifierHash => bool isUsed) s_nullifierHash;

    /*/////////////////////////////////////////////////
                            Events
    /////////////////////////////////////////////////*/
    ///@notice event emitted when a user deposits funds into the mixer
    event Mixer_Deposit(bytes32 commitment, uint8 insertedIndex, uint256 timestamp);
    ///@notice event emitted when a user withdraws funds from the mixer
    event Mixer_Withdraw(address recipient, bytes32 nullifierHash);

    /*/////////////////////////////////////////////////
                            Errors
    /////////////////////////////////////////////////*/
    ///@notice error emitted when a user tries to use an already used commitment
    error Mixer_CommitmentAlreadyUsed(bytes32 commitment);
    ///@notice error emitted when a user send an invalid amount of ether (!= DENOMINATION)
    error Mixer_AmountSentIsNotEqualTheDENOMINATION(uint256 amountSent, uint256 denomination);
    ///@notice error emitted when the root used in the proof does not match the on-chain root
    error Mixer_RootMismatch(bytes32 root);
    ///@notice error emitted when the nullifier hash has already been used
    error Mixer_NullifierAlreadyUsed(bytes32 nullifierHash);
    ///@notice error emitted when the proof is invalid
    error Mixer_InvalidProof();

    constructor(IVerifier _verifier, uint8 _merkleTreeDepth, Poseidon2 _poseidon) IncrementalMerkleTree(_merkleTreeDepth, _poseidon) {
        i_verifier = _verifier;
    }

    /*/////////////////////////////////////////////////
                    External Functions
    /////////////////////////////////////////////////*/
    /**
        @notice Deposit funds into the mixer
        @param _commitment the poseidon commitment of the nullifier and secret (generated off-chain)
    */
    function deposit(bytes32 _commitment) external payable {
        //Check if the commitment has already been used
        if(s_commitments[_commitment]) revert Mixer_CommitmentAlreadyUsed(_commitment);
        // allow user to send ETH and make sure it is of the correct fixed amount (denomination)
        if(msg.value != DENOMINATION) revert Mixer_AmountSentIsNotEqualTheDENOMINATION(msg.value, DENOMINATION);
        // add the commitment to the on-chain incremental merkle tree
        uint8 insertedIndex = _insert(_commitment);
        s_commitments[_commitment] = true;

        emit Mixer_Deposit(_commitment, insertedIndex, block.timestamp);
    }

    /**
        @notice Withdraw funds from the mixer in a private way
        @param _proof the proof that the user has the right to withdraw (they know a valid commitment)
    */
    function withdraw(bytes memory _proof, bytes32 _root, bytes32 _nullifierHash, address _recipient) external {
        //check that the root that was used in the proof matches the root on-chain.
        if(!_isKnownRoot(_root)) revert Mixer_RootMismatch(_root);

        //check that the nullifier has not yet been used to prevent double spending
        if(s_nullifierHash[_nullifierHash]) revert Mixer_NullifierAlreadyUsed(_nullifierHash);

        // Create the public inputs for the verifier contract
        bytes32[] memory publicInputs = new bytes32[](3);
        publicInputs[0] = _root; // the root of the merkle tree
        publicInputs[1] = _nullifierHash; // the nullifier hash
        publicInputs[2] = bytes32(uint256(uint160(_recipient))); // convert the recipient address to bytes32

        //Check the proof is valid by calling the verifier contract
        if(!i_verifier.verify(_proof, publicInputs)) revert Mixer_InvalidProof();

        // the proof is valid, we can now mark the nullifier as used
        s_nullifierHash[_nullifierHash] = true;

        emit Mixer_Withdraw(_recipient, _nullifierHash);

        //send them the funds
        payable(_recipient).transfer(DENOMINATION);
    }

    /*/////////////////////////////////////////////////
                    Pure & View Functions
    /////////////////////////////////////////////////*/
    function _isKnownRoot(bytes32 _root) internal view returns (bool) {
        if(_root == bytes32(0)) return false; // zero root is not a valid root

        // Check if the root is one of the historical roots
        uint8 currentIndex = s_currentRootIndex;
        uint8 i = currentIndex;

        do {
            if(_root == s_roots[i]) {
                return true;
            }
            if(i == 0) {
                i = MAX_HISTORICAL_ROOTS_SIZE;
            }
            --i;
        } while(i != currentIndex);

        return false;
    }
}