// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IModule } from "@storyprotocol/contracts/interfaces/modules/base/IModule.sol";
import { BaseModule } from "@storyprotocol/contracts/modules/BaseModule.sol";
import { IPAssetRegistry } from "@storyprotocol/contracts/registries/IPAssetRegistry.sol";
import { ILicensingModule } from "@storyprotocol/contracts/interfaces/modules/licensing/ILicensingModule.sol";
import { IP } from "@storyprotocol/contracts/lib/IP.sol";
import { IPResolver } from "@storyprotocol/contracts/resolvers/IPResolver.sol";

import { SPG } from "./lib/SPG.sol";
import { Metadata } from "./lib/Metadata.sol";
import { IStoryProtocolGateway } from "./interfaces/IStoryProtocolGateway.sol";
import { IStoryProtocolToken } from "./interfaces/IStoryProtocolToken.sol";
import { ERC721SPNFTFactory }  from "./nft/ERC721SPNFTFactory.sol";
import { Errors } from "./lib/Errors.sol";
import { SPG } from "./lib/SPG.sol";

/// @title Story Protocol Gateway
/// @notice The Story Protocol Gateway serves as the main entrypoint to secure
///         IP interactions in Story Protocol. Users should call this contract 
///         directly when registering NFTs or new IPs into the protocol.
/// TODOs:
///  - Add signature and merkle-proof based minting alternatives. Currently the SPG 
///    only supports public mints using SP NFTs for mint-and-register functions.
///  - Add support for minting and IP registration fees based on the collection.
contract StoryProtocolGateway is BaseModule, ERC721SPNFTFactory, IStoryProtocolGateway {

    /// @notice The module used for licensing.
    ILicensingModule public immutable LICENSING_MODULE;

    /// @notice The global protocol-wide IP asset registry.
    IPAssetRegistry  public immutable IP_ASSET_REGISTRY;

    /// @notice The current resolver to use for new record registration.
    IPResolver public metadataResolver;

    /// Configured mint settings for every IP collection.
    mapping(address => SPG.MintSettings) internal _mintSettings;

    /// @notice Restricts calls only to be made by an approved NFT owner.
    modifier onlyAuthorized(address tokenContract, uint256 tokenId) {
        address owner = IERC721(tokenContract).ownerOf(tokenId);
        if (msg.sender != owner && !IERC721(tokenContract).isApprovedForAll(owner, msg.sender)) {
            revert Errors.SPG__InvalidOwner();
        }
        _;
    }

    /// @notice Ensures the caller is a SPG-supported ERC-721 collection.
    modifier onlyStoryProtocolToken() {
        if (!IERC165(msg.sender).supportsInterface(type(IStoryProtocolToken).interfaceId)) {
            revert Errors.SPG__CollectionTypeUnsupported();
        }
        _;
    }

    /// @notice Initializes the Story Protocol Gateway contract.
    /// @param ipAssetRegistry The protocol-wide global IP asset registry.
    /// @param licensingModule The IP licensing module.
    /// @param resolver Default resolver to use for setting custom IP metadata.
    constructor(
        address ipAssetRegistry,
        address licensingModule,
        address resolver
    ) {
        IP_ASSET_REGISTRY = IPAssetRegistry(ipAssetRegistry);
        LICENSING_MODULE = ILicensingModule(licensingModule);
        metadataResolver = IPResolver(resolver);
    }

    /// @notice Creates a new Story Protocol NFT collection.
    /// @param collectionType The type of ERC-721 collection to initialize.
    /// @param collectionSettings Settings that apply to the collection as a whole.
    /// @param mintSettings Settings that apply how the NFTs get minted.
    function createIpCollection(
        SPG.CollectionType collectionType,
        SPG.CollectionSettings calldata collectionSettings,
        SPG.MintSettings calldata mintSettings
    ) external returns (address) {
        if (collectionType != SPG.CollectionType.SP_DEFAULT_COLLECTION) {
            // TODO: Support other ERC721 collection types.
            revert Errors.SPG__CollectionTypeUnsupported();
        }
        address ipCollection = _createSPNFTCollection(collectionSettings);
        _mintSettings[ipCollection] = mintSettings;
        // A default value of 0 indicates that minting can start immediately.
        if (mintSettings.start == 0) {
            _mintSettings[ipCollection].start = block.timestamp;
        }
        return ipCollection;
    }


    /// @notice Registers an existing NFT into the protocol as an IP Asset.
    /// @param policyId The policy that will identify the licensing terms of the IP.
    /// @param tokenContract The address of the contract of the NFT being registered.
    /// @param tokenId The id of the NFT being registered.
    /// @param ipMetadata Metadata related to IP attribution.
    function registerIp(
        uint256 policyId,
        address tokenContract,
        uint256 tokenId,
        Metadata.IPMetadata calldata ipMetadata
    ) external onlyAuthorized(tokenContract, tokenId) returns (address) {
        return _registerIp(
            policyId,
            tokenContract,
            tokenId,
            ipMetadata.name,
            ipMetadata.hash,
            ipMetadata.url,
            ipMetadata.customMetadata
        );
    }

    /// @notice Mints a Story Protocol NFT and registers it into the protocol as an IP asset.
    /// @param tokenContract The address of the NFT bound to the root-level IP.
    /// @param tokenMetadata Additional token metadata in bytes to include for minting.
    /// @param ipMetadata Metadata related to IP attribution.
    function mintAndRegisterIp(
        uint256 policyId,
        address tokenContract,
        bytes calldata tokenMetadata,
        Metadata.IPMetadata calldata ipMetadata
    ) external returns (uint256 tokenId, address ipId) {
        tokenId = _mint(tokenContract, tokenMetadata, msg.sender);
        ipId = _registerIp(
            policyId,
            tokenContract,
            tokenId,
            ipMetadata.name,
            ipMetadata.hash,
            ipMetadata.url,
            ipMetadata.customMetadata
        );
    }

    /// @notice Registers an existing NFT into the protocol as an IP asset derivative.
    /// @param licenseIds The licenses to incorporate for the new IP.
    /// @param minRoyalty The minimum royalty % to be collected by the IP asset.
    /// @param tokenContract The address of the NFT bound to the root-level IP.
    /// @param tokenId The token id of the NFT bound to the root-level IP.
    /// @param ipMetadata Metadata related to IP attribution.
    function registerDerivativeIp(
        uint256[] calldata licenseIds,
        uint32 minRoyalty,
        address tokenContract,
        uint256 tokenId,
        Metadata.IPMetadata calldata ipMetadata
    ) external onlyAuthorized(tokenContract, tokenId) returns (address) {
        return _registerDerivativeIp(
            licenseIds,
            minRoyalty,
            tokenContract,
            tokenId,
            ipMetadata.name,
            ipMetadata.hash,
            ipMetadata.url,
            ipMetadata.customMetadata
        );
    }

    /// @notice Mints and registers a Story Protocol NFT into the protocol as an IP asset derivative.
    /// @param licenseIds The licenses to incorporate for the new IP.
    /// @param minRoyalty The minimum royalty % to be collected by the IP asset.
    /// @param tokenContract The address of the NFT bound to the root-level IP.
    /// @param tokenMetadata Token metadata in bytes to include for NFT minting.
    /// @param ipMetadata Metadata related to IP attribution.
    /// @return tokenId The identifier of the minted NFT.
    /// @return ipId The address identifier of the newly registered IP asset.
    function mintAndRegisterDerivativeIp(
        uint256[] calldata licenseIds,
        uint32 minRoyalty,
        address tokenContract,
        bytes calldata tokenMetadata,
        Metadata.IPMetadata calldata ipMetadata
    ) external returns (uint256 tokenId, address ipId) {
        tokenId = _mint(tokenContract, tokenMetadata, msg.sender);
        ipId = _registerDerivativeIp(
            licenseIds,
            minRoyalty,
            tokenContract,
            tokenId,
            ipMetadata.name,
            ipMetadata.hash,
            ipMetadata.url,
            ipMetadata.customMetadata
        );
    }

    /// @notice Configures the minting settings for an IP NFT collection.
    /// @param mintSettings The updated settings to configure for the mint.
    //// TODO: Add functionality for allowing owners to update collection mint settings.
    function configureMintSettings(SPG.MintSettings calldata mintSettings) external onlyStoryProtocolToken {
        if (_mintSettings[msg.sender].start == 0) {
            revert Errors.SPG__CollectionNotInitialized();
        }
        _mintSettings[msg.sender] = mintSettings;
        if (mintSettings.start == 0) {
            _mintSettings[msg.sender].start = block.timestamp;
        }
    }

    /// @notice Gets the minting settings configured for a particular collection.
    /// @param ipCollection The collection whose mint settings are being queried for.
    function getMintSettings(address ipCollection) external view returns (SPG.MintSettings memory) {
        return _mintSettings[ipCollection];
    }

    /// @notice Gets the name of the enrolled frontend as a module.
    function name() external override(IModule) pure returns (string memory) {
        return "SPG";
    }

    /// @dev Registers an NFT into the protocol as a new IP asset.
    /// @param policyId The policy that will identify the licensing terms of the IP.
    /// @param tokenContract The address of the contract of the NFT being registered.
    /// @param tokenId The id of the NFT being registered.
    /// @param ipName The name assigned to the IP on registration.
    /// @param contentHash The content hash assigned to the IP on registration.
    /// @param externalURL An external URI to link to the IP.
    function _registerIp(
        uint256 policyId,
        address tokenContract,
        uint256 tokenId,
        string memory ipName,
        bytes32 contentHash,
        string calldata externalURL,
        Metadata.Attribute[] calldata ipMetadata
    ) internal returns (address ipId) {
        bytes memory canonicalMetadata = abi.encode(
            IP.MetadataV1({
                name: ipName,
                hash: contentHash,
                registrationDate: uint64(block.timestamp),
                registrant: msg.sender,
                uri: externalURL
            })
        );

        ipId = IP_ASSET_REGISTRY.register(
            block.chainid,
            tokenContract,
            tokenId,
            address(metadataResolver),
            true,
            canonicalMetadata
        );

        if (policyId != 0) {
            LICENSING_MODULE.addPolicyToIp(ipId, policyId);
        }
        _setCustomIpMetadata(ipId, ipMetadata);
    }

    /// @dev Registers an existing NFT into the protocol as an IP Asset derivative.
    /// @param licenseIds The parent IP asset licenses used to derive the new IP asset.
    /// @param minRoyalty The minimum royalty to enforce if applicable, else 0.
    /// @param tokenContract The address of the contract of the NFT being registered.
    /// @param tokenId The id of the NFT being registered.
    /// @param ipName The name assigned to the IP on registration.
    /// @param contentHash The content hash assigned to the IP on registration.
    /// @param externalURL An external URI to link to the IP.
    /// @param ipMetadata Additioanl metadata string key-value pairs to assign to the IP.
    function _registerDerivativeIp(
        uint256[] memory licenseIds,
        uint32 minRoyalty,
        address tokenContract,
        uint256 tokenId,
        string memory ipName,
        bytes32 contentHash,
        string calldata externalURL,
        Metadata.Attribute[] calldata ipMetadata
    ) internal returns (address ipId) {
        bytes memory canonicalMetadata = abi.encode(
            IP.MetadataV1({
                name: ipName,
                hash: contentHash,
                registrationDate: uint64(block.timestamp),
                registrant: msg.sender,
                uri: externalURL
            })
        );

        ipId = IP_ASSET_REGISTRY.register(
            licenseIds,
            minRoyalty,
            block.chainid,
            tokenContract,
            tokenId,
            address(metadataResolver),
            true,
            canonicalMetadata
        );
        _setCustomIpMetadata(ipId, ipMetadata);
    }

    /// @dev Sets custom metadata for an IPA using the default resolver contract.
    function  _setCustomIpMetadata(address ipId, Metadata.Attribute[] calldata metadata) internal {
        for (uint256 i = 0; i < metadata.length; i++) {
            metadataResolver.setValue(ipId, metadata[i].key, metadata[i].value);
        }
    }

    /// @dev Mints an SPG-supported token on behalf of the user.
    /// TODO: Add various other programmable minting checks.
    function _mint(address tokenContract, bytes calldata tokenMetadata, address to) internal returns (uint256) {
        SPG.MintSettings memory mintSettings = _mintSettings[tokenContract];
        if (block.timestamp < mintSettings.start) {
            revert Errors.SPG__MintingNotYetStarted();
        }
        if (block.timestamp > mintSettings.end && mintSettings.end != 0) {
            revert Errors.SPG__MintingAlreadyEnded();
        }
        return IStoryProtocolToken(tokenContract).mint(to, tokenMetadata);
    }

}
