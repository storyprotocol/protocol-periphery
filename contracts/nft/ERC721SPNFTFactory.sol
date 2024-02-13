// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { Clones } from '@openzeppelin/contracts/proxy/Clones.sol';
import { ERC721SPNFT } from "./ERC721SPNFT.sol";
import { ERC721 } from "../lib/ERC721.sol";

/// @title Story Protocol ERC-721 NFT Factory Contract
/// @notice In Story Protocol, all IP must first be materialized as an NFT. This
///         factory contract allows creators to create ERC-721 collections whose 
///         NFTs represent any IP not yet instantiated on the blockchain.
contract ERC721SPNFTFactory {

    /// @notice The address of the SP NFT implementation contract.
    address public immutable SP_NFT_IMPL;

    /// @notice Initializes the ERC-721 SP NFT Factory.
    constructor(address spNFTImpl) {
        SP_NFT_IMPL = spNFTImpl;
    }

    /// @dev Creates a new SP NFT collection.
    /// @param settings Settings that apply to the ERC721 collection as a whole.
    function _createSPNFTCollection(
        ERC721.CollectionSettings memory settings
    ) internal returns (address spNFT) {
        spNFT = Clones.clone(SP_NFT_IMPL);
        ERC721SPNFT(spNFT).initialize(
            msg.sender,
            address(this),
            settings.metadataProvider,
            settings.metadata,
            settings.name,
            settings.symbol,
            settings.maxSupply
        );
    }
}
