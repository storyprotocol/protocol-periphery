// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

import { IStoryProtocolDrop } from "contracts/interfaces/IStoryProtocolDrop.sol";
import { SPG } from "contracts/lib/SPG.sol";
import { ERC721SPNFTFactory } from "contracts/nft/ERC721SPNFTFactory.sol";

/// @title Mock Story Protocol Drop Contract
contract MockStoryProtocolDrop is ERC721SPNFTFactory, IStoryProtocolDrop {

    /// @notice Keeps track of all created mints.
    mapping(address => SPG.MintSettings) public publicMints;

    /// @notice Creates a new Story Protocol NFT collection.
    function createIpCollection(
        SPG.CollectionType,
        SPG.CollectionSettings calldata collectionSettings,
        SPG.MintSettings calldata
    ) external returns (address) {
        return _createSPNFTCollection(collectionSettings);
    }

    /// @notice Configures the minting settings for an IP NFT collection.
    /// @param mintSettings The updated settings to configure for the mint.
    //// TODO: Add functionality for allowing owners to update collection mint settings.
    function configureMintSettings(SPG.MintSettings calldata mintSettings) public {
        publicMints[msg.sender] = mintSettings;
    }

    /// @notice Gets the publicly configured mint settings for a collection.
    function getMintSettings(address ipCollection) public view returns (SPG.MintSettings memory) {
        return publicMints[ipCollection];
    }

}
