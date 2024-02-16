// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

import { SPG } from "../lib/SPG.sol";

/// @title Story Protocol NFT Collection Interface
/// @notice This interface must be followed for all NFTs whose mints are to be managed
///         directly using the Story Protocol periphery contracts.
interface IStoryProtocolToken is IERC721Metadata {
    /// @notice Mints a new token, optionally providing additional metadata.
    /// @param to The address that will receive the minted NFT.
    /// @param data Bytes-encoded metadata that may be used for the new NFT.
    function mint(address to, bytes memory data) external returns (uint256);

    /// @notice Configures the minting settings for an ongoing Story Protocol mint.
    /// @param spg The address of an allowed SPG contract given access to mint the token.
    /// @param mintSettings The new settings to configure for the mint.
    function configureMint(address spg, SPG.MintSettings calldata mintSettings) external;
}
