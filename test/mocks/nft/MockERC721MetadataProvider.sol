// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { IERC721MetadataProvider } from "contracts/interfaces/nft/IERC721MetadataProvider.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { Errors } from "contracts/lib/Errors.sol";

/// @title Mock ERC-721 Metadata Provider
contract MockERC721MetadataProvider is IERC721MetadataProvider, Initializable {

    /// @dev Sample metadata schema that the provider requires for tokens.
    struct TokenMetadata {
        string url;
    }

    /// @dev Sample metadata schema that the provider requires for the collection.
    struct ContractMetadata {
        string url;
        uint256 x;
    }

    /// @dev Tracks metadata set for each ERC-721 token.
    mapping(uint256 => bytes) internal _metadata;

    /// @dev Tracks the token associated with the metadata provider.
    address _token;
    
    /// @dev Tracks the contract URL.
    string _contractURL;

    /// @notice Initializes the metadata provider for the provided erc-721 token.
    /// @param tokenAddr The address of the ERC-721 metadata is being provided for.
    /// @param data Settings in bytes to configure for the provider.
    function initialize(address tokenAddr, bytes calldata data) external initializer {
        ContractMetadata memory decoded = abi.decode(data, (ContractMetadata));
        _token = tokenAddr;
        _contractURL = decoded.url;
    }

    /// @notice Sets the metadata attributes for an ERC-721 token.
    ///         This function MUST revert if set metadata is not valid.
    /// @param tokenId The ERC-721 token identifier whose metadata is being set.
    /// @param data The bytes-encoded metadata to set for the token.
    function setMetadata(uint256 tokenId, bytes calldata data) external {
        abi.decode(data, (TokenMetadata));
        _metadata[tokenId] = data;
    }

    /// @notice Gets the ERC-721 token URI associated with the given NFT.
    /// @param tokenId The ERC-721 identifier of the NFT being queried.
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        TokenMetadata memory decoded = abi.decode(_metadata[tokenId], (TokenMetadata));
        return decoded.url;
    }

    /// @notice Gets the ERC-721 contract URI associated with the given NFT.
    function contractURI() external view returns (string memory) {
        return _contractURL;
    }

    /// @notice Gets the address of the NFT whose metadata is being provided for.
    function token() external view returns (address) {
        return _token;
    }
}
