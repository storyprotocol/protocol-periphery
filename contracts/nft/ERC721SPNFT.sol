// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import { IERC721MetadataProvider } from "..//interfaces/nft/IERC721MetadataProvider.sol";
import { ERC721Cloneable } from "./ERC721Cloneable.sol";
import { Errors } from "../lib/Errors.sol";
import { SPG } from "../lib/SPG.sol";
import { IStoryProtocolGateway } from "../interfaces/IStoryProtocolGateway.sol";
import { IERC721SPNFT } from "../interfaces/nft/IERC721SPNFT.sol";
import { IStoryProtocolToken } from "../interfaces/IStoryProtocolToken.sol";

/// @title Story Protocol ERC-721 NFT.
/// @notice Default NFT contract used for representing new IP on Story Protocol.
contract ERC721SPNFT is ERC721Cloneable, Ownable2StepUpgradeable, ReentrancyGuardUpgradeable {
    /// @notice The Story Protocol NFT factory contract address.
    address public immutable FACTORY;

    /// @notice Checks whether an address is a registered minter for the collection.
    mapping(address => bool) public isMinter;

    /// @notice Tracks the max supply allowed for the collection.
    uint256 public maxSupply;

    /// @dev Gets the current metadata provider used for new NFTs in the collection.
    IERC721MetadataProvider internal _metadataProvider;

    /// @dev Gets the metadata provider bound for a specific NFT.
    mapping(uint256 => IERC721MetadataProvider) internal _metadataProviders;

    /// @notice Creates the ERC-721 SP NFT implementation contract.
    /// @param factoryAddr The address of the SP NFT factory.
    constructor(address factoryAddr) {
        FACTORY = factoryAddr;
    }

    /// @notice Initializes the Story Protocol ERC-721 token contract.
    /// @param owner The owner of the ERC-721 token contract.
    /// @param spg The Story Protocol Gateway address, with initial minting rights.
    /// @param provider The address used for custom token metadata attribution.
    /// @param providerInitData Initial data to set for the metadata provider.
    /// @param tokenName The name for the collection-wide NFT contract.
    /// @param tokenSymbol The symbol for the collection-wide NFT contract.
    /// @param maxSupplyLimit The max supply allowed for the collection.
    function initialize(
        address owner,
        address spg,
        address provider,
        bytes memory providerInitData,
        string memory tokenName,
        string memory tokenSymbol,
        uint256 maxSupplyLimit
    ) external initializer {
        if (msg.sender != FACTORY) {
            revert Errors.ERC721SPNFT__FactoryInvalid();
        }
        maxSupply = maxSupplyLimit;
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
    function mint(address to, bytes memory data) external nonReentrant returns (uint256 tokenId) {
        if (!isMinter[msg.sender]) {
            revert Errors.ERC721SPNFT__MinterInvalid();
        }
        if (totalSupply == maxSupply) {
            revert Errors.ERC721__MaxSupplyReached();
        }
        tokenId = totalSupply;
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

    /// @notice Configures the minting settings for an ongoing Story Protocol mint.
    /// @param spg The address of an allowed SPG contract given access to mint the token.
    /// @param settings The new settings to configure for the mint.
    function configureMintSettings(address spg, SPG.MintSettings calldata settings) external onlyOwner {
        IStoryProtocolGateway(spg).configureMintSettings(settings);
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

    /// @notice Checks if interface of identifier `id` is supported.
    /// @param id The ERC-165 interface identifier.
    /// @return True if interface id `id` is supported, false otherwise.
    function supportsInterface(bytes4 id) public view virtual override(ERC721Cloneable) returns (bool) {
        return
            id == type(IStoryProtocolToken).interfaceId ||
            id == type(IERC721SPNFT).interfaceId ||
            super.supportsInterface(id);
    }
}
