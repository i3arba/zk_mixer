///SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { Poseidon2, Field } from "@poseidon/src/Poseidon2.sol";

contract IncrementalMerkleTree {

    ///@notice Immutable variable to store the IMT depth.
    uint8 public immutable i_depth;
    ///@notice immutable variable to store Poseidon instance
    Poseidon2 immutable i_poseidon;

    ///@notice the PRIME value from the Poseidon2::Field::Prime variable after `cast --to-dec`
    uint256 public constant FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    ///@notice the "zero" element is the default value for the Merkle tree, it is used to fill in empty nodes keccak256("cyfrin") % FIELD_SIZE
    bytes32 public constant ZERO_VALUE = bytes32(0x0d823319708ab99ec915efd4f7e03d11ca1790918e8f04cd14100aceca2aa9ff);
    ///@notice constant variable to store the maximum number of historical roots to store
    uint8 public constant MAX_HISTORICAL_ROOTS_SIZE = 30;

    ///@notice storage variable to store the index of the next available leaf
    uint8 public s_nextLeafIndex;
    ///@notice storage variable to keep track of the current root index
    uint8 public s_currentRootIndex;

    ///@notice mapping to store the cached subtrees
    mapping(uint8 leafIndex => bytes32 leafHash) public s_cachedSubtree;
    ///@notice variable to store the current root of the incremental merkle tree
    mapping(uint256 index => bytes32 root)  s_roots;

    ///@notice Error emitted when the i_depth is initialized with an invalid value
    error IncrementalMerkleTree_InvalidDepth();
    ///@notice Error emitted when the input depth is bigger than the allowed maximum
    error IncrementalMerkleTree_IndexOutOfBounds(uint256 invalidIndexSize);
    ///@notice Error emitted when the tree is already completed and is not accepting more leafs
    error IncrementalMerkleTree_CommitmentsAlreadyCompleted(uint32 nextLeafIndex);

    constructor(uint8 _depth, Poseidon2 _poseidon) {
        if(_depth > 32 || _depth == 0) revert IncrementalMerkleTree_InvalidDepth();

        i_depth = _depth;
        i_poseidon = _poseidon;

        // We need to precompute all the zero subtrees
        // store the initial root in a state variable
        s_roots[0] = zeros(_depth); //It will store the ID 0 root as the depth 0, zero tree
    }

    function _insert(bytes32 _commitmentLeaf) internal returns(uint8 nextLeadIndex_){
        // add leaf to incremental merkle tree
        nextLeadIndex_ = s_nextLeafIndex;
        // check if the index of the leaf being added is within the maximum index
        if(nextLeadIndex_ == 2**i_depth) revert IncrementalMerkleTree_CommitmentsAlreadyCompleted(nextLeadIndex_);

        // figure out if the index is even
        bytes32 currentHash = _commitmentLeaf;
        bytes32 left;
        bytes32 right;
        for (uint8 i; i < i_depth; ++i){
            if(nextLeadIndex_ % 2 == 0){
            // If even, we need to put it on the left of the hash and a zero tree on the right
                // Store the result as a cached subtree
                left = currentHash;
                right = zeros(i);
                s_cachedSubtree[i] = currentHash;
            } else {
            // If odd, we need the leaf to be on the right and add a cached subtree on the left.
                left = s_cachedSubtree[i];
                right = currentHash;
            }
            // Do the hash
            currentHash = Field.toBytes32(i_poseidon.hash_2(Field.toField(left), Field.toField(right)));
            // Update the nextLeafIndex
            nextLeadIndex_ = nextLeadIndex_ / 2;
            //  Repeat until the whole tree is completed.
        }
        // Check for the next root index
        uint8 newRootIndex = (s_currentRootIndex + 1) % MAX_HISTORICAL_ROOTS_SIZE;
        // Update the current root index
        s_currentRootIndex = newRootIndex;
        // Store the final root and increment the nextLeafIndex
        s_roots[newRootIndex] = currentHash;

        s_nextLeafIndex = nextLeadIndex_ + 1;
    }

    function zeros(uint256 _depthSize) public pure returns(bytes32 subTree_){
        if(_depthSize == 0) return ZERO_VALUE;
        else if (_depthSize == 1) return bytes32(0x170a9598425eb05eb8dc06986c6afc717811e874326a79576c02d338bdf14f13);
        else if (_depthSize == 2) return bytes32(0x273b1a40397b618dac2fc66ceb71399a3e1a60341e546e053cbfa5995e824caf);
        else if (_depthSize == 3) return bytes32(0x16bf9b1fb2dfa9d88cfb1752d6937a1594d257c2053dff3cb971016bfcffe2a1);
        else if (_depthSize == 4) return bytes32(0x1288271e1f93a29fa6e748b7468a77a9b8fc3db6b216ce5fc2601fc3e9bd6b36);
        else if (_depthSize == 5) return bytes32(0x1d47548adec1068354d163be4ffa348ca89f079b039c9191378584abd79edeca);
        else if (_depthSize == 6) return bytes32(0x0b98a89e6827ef697b8fb2e280a2342d61db1eb5efc229f5f4a77fb333b80bef);
        else if (_depthSize == 7) return bytes32(0x231555e37e6b206f43fdcd4d660c47442d76aab1ef552aef6db45f3f9cf2e955);
        else if (_depthSize == 8) return bytes32(0x03d0dc8c92e2844abcc5fdefe8cb67d93034de0862943990b09c6b8e3fa27a86);
        else if (_depthSize == 9) return bytes32(0x1d51ac275f47f10e592b8e690fd3b28a76106893ac3e60cd7b2a3a443f4e8355);
        else if (_depthSize == 10) return bytes32(0x16b671eb844a8e4e463e820e26560357edee4ecfdbf5d7b0a28799911505088d);
        else if (_depthSize == 11) return bytes32(0x115ea0c2f132c5914d5bb737af6eed04115a3896f0d65e12e761ca560083da15);
        else if (_depthSize == 12) return bytes32(0x139a5b42099806c76efb52da0ec1dde06a836bf6f87ef7ab4bac7d00637e28f0);
        else if (_depthSize == 13) return bytes32(0x0804853482335a6533eb6a4ddfc215a08026db413d247a7695e807e38debea8e);
        else if (_depthSize == 14) return bytes32(0x2f0b264ab5f5630b591af93d93ec2dfed28eef017b251e40905cdf7983689803);
        else if (_depthSize == 15) return bytes32(0x170fc161bf1b9610bf196c173bdae82c4adfd93888dc317f5010822a3ba9ebee);
        else if (_depthSize == 16) return bytes32(0x0b2e7665b17622cc0243b6fa35110aa7dd0ee3cc9409650172aa786ca5971439);
        else if (_depthSize == 17) return bytes32(0x12d5a033cbeff854c5ba0c5628ac4628104be6ab370699a1b2b4209e518b0ac5);
        else if (_depthSize == 18) return bytes32(0x1bc59846eb7eafafc85ba9a99a89562763735322e4255b7c1788a8fe8b90bf5d);
        else if (_depthSize == 19) return bytes32(0x1b9421fbd79f6972a348a3dd4721781ec25a5d8d27342942ae00aba80a3904d4);
        else if (_depthSize == 20) return bytes32(0x087fde1c4c9c27c347f347083139eee8759179d255ec8381c02298d3d6ccd233);
        else if (_depthSize == 21) return bytes32(0x1e26b1884cb500b5e6bbfdeedbdca34b961caf3fa9839ea794bfc7f87d10b3f1);
        else if (_depthSize == 22) return bytes32(0x09fc1a538b88bda55a53253c62c153e67e8289729afd9b8bfd3f46f5eecd5a72);
        else if (_depthSize == 23) return bytes32(0x14cd0edec3423652211db5210475a230ca4771cd1e45315bcd6ea640f14077e2);
        else if (_depthSize == 24) return bytes32(0x1d776a76bc76f4305ef0b0b27a58a9565864fe1b9f2a198e8247b3e599e036ca);
        else if (_depthSize == 25) return bytes32(0x1f93e3103fed2d3bd056c3ac49b4a0728578be33595959788fa25514cdb5d42f);
        else if (_depthSize == 26) return bytes32(0x138b0576ee7346fb3f6cfb632f92ae206395824b9333a183c15470404c977a3b);
        else if (_depthSize == 27) return bytes32(0x0745de8522abfcd24bd50875865592f73a190070b4cb3d8976e3dbff8fdb7f3d);
        else if (_depthSize == 28) return bytes32(0x2ffb8c798b9dd2645e9187858cb92a86c86dcd1138f5d610c33df2696f5f6860);
        else if (_depthSize == 29) return bytes32(0x2612a1395168260c9999287df0e3c3f1b0d8e008e90cd15941e4c2df08a68a5a);
        else if (_depthSize == 30) return bytes32(0x10ebedce66a910039c8edb2cd832d6a9857648ccff5e99b5d08009b44b088edf);
        else if (_depthSize == 31) return bytes32(0x213fb841f9de06958cf4403477bdbff7c59d6249daabfee147f853db7c808082);
        else revert IncrementalMerkleTree_IndexOutOfBounds(_depthSize);
    }
}