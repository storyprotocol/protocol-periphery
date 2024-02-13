
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { IERC721SPNFT } from "contracts/interfaces/nft/IERC721SPNFT.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { IERC721MetadataProvider } from "contracts/interfaces/nft/IERC721MetadataProvider.sol";
import { ERC721Cloneable } from "contracts/nft/ERC721Cloneable.sol";
import { SPG } from "contracts/lib/SPG.sol";

/// @title Mock ERC721 Cloneable
contract MockERC721SPNFT is IERC721SPNFT, ERC721Cloneable {

    /// @dev Gets the current metadata provider used for new NFTs in the collection.
    IERC721MetadataProvider internal _metadataProvider;

    /// @dev Gets the metadata provider bound for a specific NFT.
    mapping(uint256 => IERC721MetadataProvider) internal _metadataProviders;

    /// @notice Initializes the mock SP NFT contract.
    function initialize(
        address provider,
        bytes memory providerInitData,
        string memory tokenName,
        string memory tokenSymbol
    ) public initializer {
        _metadataProvider = IERC721MetadataProvider(provider);
        _metadataProvider.initialize(address(this), providerInitData);
        __ERC721Cloneable_init(tokenName, tokenSymbol);
    }

    /// @notice Mints a new SP NFT with the provided metadata.
    /// @param to The address that will receive the minted NFT.
    /// @param data Bytes-encoded metadata to use for the IP NFT.
    function mint(address to, bytes memory data) external returns (uint256) {
        uint256 tokenId = totalSupply++;
        _mint(to, tokenId);
        _metadataProviders[tokenId] = _metadataProvider;
        _metadataProvider.setMetadata(tokenId, data);
        return tokenId;
    }

    /// @notice Burns a token owned by the calling address.
    /// @param tokenId The ERC-721 identifier of the token being burned.
    function burn(uint256 tokenId) external {
        _burn(tokenId);
    }

    /// @notice Gets the metadata provider used for new NFT mints.
    function metadataProvider() external view returns (address) {
        return address(_metadataProvider);
    }

    /// @notice Gets the metadata provider used for a specific SP NFT.
    /// @param tokenId The ERC-721 identifier of the token being queried.
    function metadataProvider(uint256 tokenId) external view returns (address) {
        return address(_metadataProviders[tokenId]);
    }

    /// @param tokenId The ERC-721 identifier of the SP NFT being queried.
    function tokenURI(uint256 tokenId) external view override(IERC721Metadata, IERC721SPNFT) returns (string memory) {
        return _metadataProviders[tokenId].tokenURI(tokenId);
    }

    /// @notice Gets the contract URI associated with the SP NFT collection.
    function contractURI() external view returns (string memory) {
        return _metadataProvider.contractURI();
    }

    /// @notice Configures the minting settings for an ongoing Story Protocol mint.
    function configureMint(
        address spg,
        SPG.MintSettings calldata mintSettings
    ) external {}
}
