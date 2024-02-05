// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721MetadataProvider } from "contracts/interfaces/nft/IERC721MetadataProvider.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { ERC721Cloneable } from "contracts/nft/ERC721Cloneable.sol";
import { Errors } from "contracts/lib/Errors.sol";

/// @title Story Protocol ERC-721 NFT.
/// @notice Default NFT contract used for representing new IP on Story Protocol.
contract ERC721SPNFT is ERC721Cloneable, Ownable2StepUpgradeable, ReentrancyGuardUpgradeable {

    /// @notice The Story Protocol NFT factory contract address.
    address public immutable factory;

    /// @notice Checks whether an address is a registered minter for the collection.
    mapping(address => bool) public isMinter;

    /// @dev Gets the current metadata provider used for new NFTs in the collection.
    IERC721MetadataProvider internal _metadataProvider;

    /// @dev Gets the metadata provider bound for a specific NFT.
    mapping(uint256 => IERC721MetadataProvider) internal _metadataProviders;

    /// @notice Creates the ERC-721 SP NFT implementation contract.
    /// @param factoryAddr The address of the SP NFT factory.
    constructor(address factoryAddr) {
        factory = factoryAddr;
    }

    /// @notice Initializes the Story Protocol ERC-721 token contract.
    /// @param owner The owner of the ERC-721 token contract.
    /// @param spg The Story Protocol Gateway address, with initial minting rights.
    /// @param provider The address used for custom token metadata attribution.
    /// @param providerInitData Initial data to set for the metadata provider.
    /// @param tokenName The name for the collection-wide NFT contract.
    /// @param tokenSymbol The symbol for the collection-wide NFT contract.
    function initialize(
        address owner,
        address spg,
        address provider,
        bytes memory providerInitData,
        string memory tokenName,
        string memory tokenSymbol
    ) external initializer {
        if (msg.sender != factory) {
            revert Errors.ERC721SPNFT__FactoryInvalid();
        }
        _metadataProvider = IERC721MetadataProvider(provider);
        isMinter[spg] = true;
        __Ownable_init(owner);
        __ReentrancyGuard_init();
        __ERC721Cloneable_init(tokenName, tokenSymbol);
        _metadataProvider.initialize(address(this), providerInitData);
    }

    /// @notice Mints a new SP NFT with the provided metadata.
    /// @param to The address that will receive the minted NFT.
    /// @param data Bytes-encoded metadata to use for the IP NFT.
    function mint(address to, bytes memory data) external nonReentrant {
        if (!isMinter[msg.sender]) {
            revert Errors.ERC721SPNFT__MinterInvalid();
        }
        uint256 tokenId = totalSupply;
        _mint(to, tokenId);
        _metadataProviders[tokenId] = _metadataProvider;
        _metadataProvider.setMetadata(tokenId, data);
    }

    /// @notice Burns a token owned by the calling address.
    /// @param tokenId The ERC-721 identifier of the token being burned.
    function burn(uint256 tokenId) external {
        if (msg.sender != ownerOf[tokenId]) {
            revert Errors.ERC721__OwnerInvalid();
        }
        _burn(tokenId);
    }

    /// @notice Sets whether a minter may be granted minting permissions.
    function setMinter(address minter, bool approved) external onlyOwner {
        isMinter[minter] = approved;
    }

    /// @notice Sets a new metadata provider for the collection.
    /// @param newMetadataProvider The address of the new metadata provider.
    /// @param initData Initialization data for initializing the new provider.
    /// TODO: Add more stringent compatibility and upgradability checks.
    ///       Do this once discussion around metadata immutability is finalized.
    function setMetadataProvider(address newMetadataProvider, bytes memory initData) external onlyOwner {
        _metadataProvider = IERC721MetadataProvider(newMetadataProvider);
        _metadataProvider.initialize(address(this), initData);
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

    /// @notice Gets the token URI associated with the SP NFT collection.
    /// @param tokenId The ERC-721 identifier of the SP NFT being queried.
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        return _metadataProviders[tokenId].tokenURI(tokenId);
    }

    /// @notice Gets the contract URI associated with the SP NFT collection.
    function contractURI() external view returns (string memory) {
        return _metadataProvider.contractURI();
    }
}
