// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { SPG } from "../lib/SPG.sol";

/// @title Story Protocol Drop Interface
/// @notice Interface for the Story Protocol Drops contract, which is used for
///         management of IP collection mints, including pricing and metadata.
interface IStoryProtocolDrop {
    /// @notice Creates a new Story Protocol NFT collection.
    /// @param collectionType The type of ERC-721 collection to initialize.
    /// @param collectionSettings Settings that apply to the collection as a whole.
    /// @param mintSettings Settings that apply specifically to how the collection is minted.
    /// @return The address of the newly deployed IP NFT collection.
    function createIpCollection(
        SPG.CollectionType collectionType,
        SPG.CollectionSettings calldata collectionSettings,
        SPG.MintSettings calldata mintSettings
    ) external returns (address);

    /// @notice Configures the minting settings for an IP NFT collection.
    /// @param mintSettings The updated settings to configure for the mint.
    function configureMintSettings(SPG.MintSettings calldata mintSettings) external;

    /// @notice Gets the minting settings configured for a particular collection.
    /// @param ipCollection The IP collection being queried for.
    function getMintSettings(address ipCollection) external view returns (SPG.MintSettings memory mintSettings);
}
