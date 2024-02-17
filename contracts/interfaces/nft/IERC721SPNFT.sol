// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { IStoryProtocolToken } from "../IStoryProtocolToken.sol";

/// @title ERC-721 Story Protocol NFT Interface
/// @notice This ERC-721 contract interface allows every token to specify its own
///         set of custom metadata that conforms to the ERC-721 JSON standards.
interface IERC721SPNFT is IStoryProtocolToken {
    /// @notice Mints a new SP NFT with the provided metadata.
    /// @param to The address that will receive the minted NFT.
    /// @param data Bytes-encoded metadata to use for the IP NFT.
    function mint(address to, bytes memory data) external override returns (uint256);

    /// @notice Gets the metadata provider used for new NFT mints.
    function metadataProvider() external view returns (address);

    /// @notice Gets the metadata provider used for a specific SP NFT.
    /// @param tokenId The ERC-721 identifier of the token being queried.
    function metadataProvider(uint256 tokenId) external view returns (address);

    /// @notice Gets the ERC-721 token URI associated with the given NFT.
    /// @param tokenId The ERC-721 identifier of the SP NFT being queried.
    function tokenURI(uint256 tokenId) external view returns (string memory);

    /// @notice Gets the ERC-721 contract URI associated with the SP collection.
    function contractURI() external view returns (string memory);
}
