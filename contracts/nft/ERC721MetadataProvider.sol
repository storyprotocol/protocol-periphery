// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";

import { IERC721SPNFT } from "contracts/interfaces/nft/IERC721SPNFT.sol";
import { IERC721MetadataProvider } from "contracts/interfaces/nft/IERC721MetadataProvider.sol";
import { Metadata } from "contracts/lib/Metadata.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title ERC-721 Metadata Provider
/// @notice Contract for storing ERC-721 JSON compliant metadata.
contract ERC721MetadataProvider is IERC721MetadataProvider, Initializable {
    /// @notice Gets the address associated with IP asset metadata rendering.
    // IPAssetRenderer public immutable IP_ASSET_RENDERER;

    /// @dev Tracks the SP token associated with this provider.
    IERC721SPNFT internal _spNFT;

    /// @dev Maps individual SP NFTs to their stored token metadata.
    mapping(uint256 => Metadata.TokenMetadata) internal _tokenMetadata;

    /// @dev Gets the collection-wide metadata.
    Metadata.ContractData internal _contractMetadata;

    /// @notice Initializes the metadata provider for the provided erc-721 token.
    /// @param tokenAddr The address of the ERC-721 metadata is being provided for.
    /// @param data Settings in bytes to configure for the provider.
    function initialize(address tokenAddr, bytes calldata data) external initializer {
        Metadata.ContractData memory decoded = abi.decode(data, (Metadata.ContractData));
        _contractMetadata.description = decoded.description;
        _contractMetadata.image = decoded.image;
        _contractMetadata.uri = decoded.uri;
        _spNFT = IERC721SPNFT(tokenAddr);
    }

    /// @notice Sets the metadata attributes for an ERC-721 token.
    ///         This function MUST revert if set metadata is not valid.
    /// @param tokenId The ERC-721 token identifier whose metadata is being set.
    /// @param data The bytes-encoded metadata to set for the token.
    /// TODO: Add better metadata decoding error handling.
    /// TODO: Allow updates by token owners. Currently, this is only done on mint.
    /// TODO: Add storage optimization and caching.
    function setMetadata(uint256 tokenId, bytes memory data) external virtual {
        if (msg.sender != address(_spNFT)) {
            revert Errors.ERC721MetadataProvider__TokenInvalid();
        }
        Metadata.TokenMetadata storage tokenMetadata = _tokenMetadata[tokenId];
        Metadata.TokenMetadata memory decoded = abi.decode(data, (Metadata.TokenMetadata));

        // TODO: Confirm whether validation on name should be performed.
        // if (bytes(decoded.name).length == 0) {
        //     revert Errors.ERC721MetadataProvider__NameInvalid();
        // }
        tokenMetadata.name = decoded.name;

        // TODO: Confirm whether validation on description should be performed.
        // if (bytes(decoded.description).length == 0) {
        //     revert Errors.ERC721MetadataProvider__DescriptionInvalid();
        // }
        tokenMetadata.description = decoded.description;

        // TODO: Confirm whether validation on external URL should be performed.
        // if (bytes(decoded.externalUrl).length == 0) {
        //     revert Errors.ERC721MetadataProvider__URLInvalid();
        // }
        tokenMetadata.externalUrl = decoded.externalUrl;

        // TODO: Confirm whether validation on image should be performed.
        // if (bytes(decoded.image).length == 0) {
        //     revert Errors.ERC721MetadataProvider__ImageInvalid();
        // }
        tokenMetadata.image = decoded.image;

        Metadata.Attribute[] memory attributes = decoded.attributes;
        for (uint256 i = 0; i < attributes.length; i++) {
            tokenMetadata.attributes.push(attributes[i]);
        }
    }

    /// @notice Generates an ERC721 Metadata JSON compliant URI for the NFT.
    /// @param tokenId The ERC-721 identifier of the NFT being queried.
    /// TODO: Create a JSON utility lib for more efficient encoding / decoding.
    /// TODO: Add storage caching and other low-level optimizations.
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        Metadata.TokenMetadata memory metadata = _tokenMetadata[tokenId];
        string memory baseMetadata = string(
            /* solhint-disable */
            abi.encodePacked(
                '{"description": "',
                metadata.description,
                '", "external_url": "',
                metadata.externalUrl,
                '", "image": "',
                metadata.image,
                '", "name": "',
                metadata.name,
                '", "attributes": ['
            )
            /* solhint-enable */
        );

        // TODO: Do security checks on empty string or quoted attributes.
        string memory attributes = "";
        Metadata.Attribute[] memory attr = metadata.attributes;
        for (uint256 i = 0; i < attr.length; i++) {
            attributes = string.concat(
                attributes,
                bytes(attributes).length == 0 ? "" : ", ",
                /* solhint-disable */
                string(abi.encodePacked('{"trait_type": "', attr[i].key, '", "value": "', attr[i].value, '"}'))
                /* solhint-enable */
            );
        }
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(bytes(string(abi.encodePacked(baseMetadata, attributes, "]}"))))
                )
            );
    }

    /// @notice Gets the ERC-721 contract URI associated with the given NFT.
    function contractURI() external view returns (string memory) {
        Metadata.ContractData memory contractMetadata = _contractMetadata;
        string memory metadata = string(
            /* solhint-disable */
            abi.encodePacked(
                '{"description": "',
                contractMetadata.description,
                '", "external_link": "',
                contractMetadata.uri,
                '", "image": "',
                contractMetadata.image,
                '", "name": "',
                _spNFT.name(),
                '"}'
            )
            /* solhint-enable */
        );
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(metadata))));
    }

    /// @notice Gets the address of the NFT whose metadata is being provided for.
    function token() external view returns (address) {
        return address(_spNFT);
    }
}
