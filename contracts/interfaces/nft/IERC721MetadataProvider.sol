// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

/// @title ERC-721 Metadata Provider Interface
/// @notice Interace for supporting ERC-721 token metadata provisioning.
interface IERC721MetadataProvider {
    /// @notice Initializes the metadata provider for the provided erc-721 token.
    /// @param token The address of the ERC-721 metadata is being provided for.
    /// @param data Settings in bytes to configure for the provider.
    function initialize(address token, bytes calldata data) external;

    /// @notice Sets the metadata attributes for an ERC-721 token.
    ///         This function MUST revert if set metadata is not valid.
    /// @param tokenId The ERC-721 token identifier whose metadata is being set.
    /// @param data The bytes-encoded metadata to set for the token.
    function setMetadata(uint256 tokenId, bytes calldata data) external;

    /// @notice Gets the ERC-721 token URI associated with the given NFT.
    /// @param tokenId The ERC-721 identifier of the NFT being queried.
    function tokenURI(uint256 tokenId) external view returns (string memory);

    /// @notice Gets the ERC-721 contract URI associated with the given NFT.
    function contractURI() external view returns (string memory);

    /// @notice Gets the address of the NFT whose metadata is being provided for.
    function token() external view returns (address);
}
