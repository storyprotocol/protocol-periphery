// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { PILPolicy, PILPolicyFrameworkManager, RegisterPILPolicyParams } from "@storyprotocol/contracts/modules/licensing/PILPolicyFrameworkManager.sol";
import { BaseModule } from "@storyprotocol/contracts/modules/BaseModule.sol";
import { IPAssetRegistry } from "@storyprotocol/contracts/registries/IPAssetRegistry.sol";
import { ILicensingModule } from "@storyprotocol/contracts/interfaces/modules/licensing/ILicensingModule.sol";
import { IP } from "@storyprotocol/contracts/lib/IP.sol";
import { IPResolver } from "@storyprotocol/contracts/resolvers/IPResolver.sol";
import { IIPAccount } from "@storyprotocol/contracts/interfaces/IIPAccount.sol";
import { AccessPermission } from "@storyprotocol/contracts/lib/AccessPermission.sol";
import { IAccessController } from "@storyprotocol/contracts/interfaces/IAccessController.sol";

import { SPG } from "./lib/SPG.sol";
import { Metadata } from "./lib/Metadata.sol";
import { IStoryProtocolGateway } from "./interfaces/IStoryProtocolGateway.sol";
import { IStoryProtocolToken } from "./interfaces/IStoryProtocolToken.sol";
import { ERC721SPNFTFactory } from "./nft/ERC721SPNFTFactory.sol";
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
    string public constant override name = "SPG";

    /// @notice The protocol access controller.
    IAccessController public immutable ACCESS_CONTROLLER;

    /// @notice The module used for licensing.
    ILicensingModule public immutable LICENSING_MODULE;

    /// @notice The global protocol-wide IP asset registry.
    IPAssetRegistry public immutable IP_ASSET_REGISTRY;

    /// @notice The canonical PIL Policy Framework Manager.
    PILPolicyFrameworkManager public immutable PIL_POLICY_FRAMEWORK_MANAGER;

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
    /// @param accessController The protocol access controller.
    /// @param ipAssetRegistry The protocol-wide global IP asset registry.
    /// @param licensingModule The IP licensing module.
    /// @param pilPolicyFrameworkManager The canonical PIL Policy Framework Manager.
    /// @param resolver Default resolver to use for setting custom IP metadata.
    constructor(
        address accessController,
        address ipAssetRegistry,
        address licensingModule,
        address pilPolicyFrameworkManager,
        address resolver
    ) {
        ACCESS_CONTROLLER = IAccessController(accessController);
        IP_ASSET_REGISTRY = IPAssetRegistry(ipAssetRegistry);
        LICENSING_MODULE = ILicensingModule(licensingModule);
        PIL_POLICY_FRAMEWORK_MANAGER = PILPolicyFrameworkManager(pilPolicyFrameworkManager);
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
    ) external onlyAuthorized(tokenContract, tokenId) returns (address ipId) {
        ipId = _registerIp(tokenContract, tokenId, ipMetadata.name, ipMetadata.hash, ipMetadata.url);

        if (policyId != 0) {
            LICENSING_MODULE.addPolicyToIp(ipId, policyId);
        }

        _setCustomIpMetadata(ipId, ipMetadata.customMetadata);
    }

    /// @notice Registers an existing NFT into the protocol as an IP Asset with user signature.
    /// @dev This function allows the user to set the permission for the SPG with a
    /// signature to allow SPG call other modules like licensing module on behalf of the user.
    /// @param policyId The policy that will identify the licensing terms of the IP.
    /// @param tokenContract The address of the contract of the NFT being registered.
    /// @param tokenId The id of the NFT being registered.
    /// @param ipMetadata Metadata related to IP attribution.
    /// @param signature The signature to set the permission for the IP.
    function registerIpWithSig(
        uint256 policyId,
        address tokenContract,
        uint256 tokenId,
        Metadata.IPMetadata calldata ipMetadata,
        SPG.Signature calldata signature
    ) external onlyAuthorized(tokenContract, tokenId) returns (address ipId) {
        ipId = _registerIp(tokenContract, tokenId, ipMetadata.name, ipMetadata.hash, ipMetadata.url);

        _setPermissionWithSig(ipId, signature.signer, signature.deadline, signature.signature);

        if (policyId != 0) {
            LICENSING_MODULE.addPolicyToIp(ipId, policyId);
        }
        _setCustomIpMetadata(ipId, ipMetadata.customMetadata);
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
        ipId = _registerIp(tokenContract, tokenId, ipMetadata.name, ipMetadata.hash, ipMetadata.url);

        if (policyId != 0) {
            LICENSING_MODULE.addPolicyToIp(ipId, policyId);
        }
        _setCustomIpMetadata(ipId, ipMetadata.customMetadata);
    }

    /// @notice Mints a Story Protocol NFT and registers it into the protocol as an IP asset with user signature.
    /// @dev This function allows the user to set the permission for the SPG with a
    /// signature to allow SPG call other modules like licensing module on behalf of the user.
    /// @param tokenContract The address of the NFT bound to the root-level IP.
    /// @param tokenMetadata Additional token metadata in bytes to include for minting.
    /// @param ipMetadata Metadata related to IP attribution.
    /// @param signature The signature to set the permission for the IP.
    function mintAndRegisterIpWithSig(
        uint256 policyId,
        address tokenContract,
        bytes calldata tokenMetadata,
        Metadata.IPMetadata calldata ipMetadata,
        SPG.Signature calldata signature
    ) external returns (uint256 tokenId, address ipId) {
        tokenId = _mint(tokenContract, tokenMetadata, msg.sender);
        ipId = _registerIp(tokenContract, tokenId, ipMetadata.name, ipMetadata.hash, ipMetadata.url);

        _setPermissionWithSig(ipId, signature.signer, signature.deadline, signature.signature);

        if (policyId != 0) {
            LICENSING_MODULE.addPolicyToIp(ipId, policyId);
        }
        _setCustomIpMetadata(ipId, ipMetadata.customMetadata);
    }

    /// @notice Registers an existing NFT into the protocol as an IP asset derivative.
    /// @param licenseIds The licenses to incorporate for the new IP.
    /// @param royaltyContext The bytes-encoded context for royalty policy to process.
    /// @param tokenContract The address of the NFT bound to the root-level IP.
    /// @param tokenId The token id of the NFT bound to the root-level IP.
    /// @param ipMetadata Metadata related to IP attribution.
    function registerDerivativeIp(
        uint256[] calldata licenseIds,
        bytes calldata royaltyContext,
        address tokenContract,
        uint256 tokenId,
        Metadata.IPMetadata calldata ipMetadata
    ) external onlyAuthorized(tokenContract, tokenId) returns (address ipId) {
        ipId = _registerDerivativeIp(
            licenseIds,
            royaltyContext,
            tokenContract,
            tokenId,
            ipMetadata.name,
            ipMetadata.hash,
            ipMetadata.url
        );
        _setCustomIpMetadata(ipId, ipMetadata.customMetadata);
    }

    /// @notice Registers an existing NFT into the protocol as an IP asset derivative with signature.
    /// @dev This function allows the user to set the permission for the SPG with a
    /// signature to allow SPG call other modules like licensing module on behalf of the user.
    /// @param licenseIds The licenses to incorporate for the new IP.
    /// @param royaltyContext The bytes-encoded context for royalty policy to process.
    /// @param tokenContract The address of the NFT bound to the root-level IP.
    /// @param tokenId The token id of the NFT bound to the root-level IP.
    /// @param ipMetadata Metadata related to IP attribution.
    /// @param signature The signature to set the permission for the IP.
    function registerDerivativeIpWithSig(
        uint256[] calldata licenseIds,
        bytes calldata royaltyContext,
        address tokenContract,
        uint256 tokenId,
        Metadata.IPMetadata calldata ipMetadata,
        SPG.Signature calldata signature
    ) external onlyAuthorized(tokenContract, tokenId) returns (address ipId) {
        ipId = _registerDerivativeIp(
            licenseIds,
            royaltyContext,
            tokenContract,
            tokenId,
            ipMetadata.name,
            ipMetadata.hash,
            ipMetadata.url
        );
        _setPermissionWithSig(ipId, signature.signer, signature.deadline, signature.signature);
        _setCustomIpMetadata(ipId, ipMetadata.customMetadata);
    }

    /// @notice Mints and registers a Story Protocol NFT into the protocol as an IP asset derivative.
    /// @param licenseIds The licenses to incorporate for the new IP.
    /// @param royaltyContext The bytes-encoded context for royalty policy to process.
    /// @param tokenContract The address of the NFT bound to the root-level IP.
    /// @param tokenMetadata Token metadata in bytes to include for NFT minting.
    /// @param ipMetadata Metadata related to IP attribution.
    /// @return tokenId The identifier of the minted NFT.
    /// @return ipId The address identifier of the newly registered IP asset.
    function mintAndRegisterDerivativeIp(
        uint256[] calldata licenseIds,
        bytes calldata royaltyContext,
        address tokenContract,
        bytes calldata tokenMetadata,
        Metadata.IPMetadata calldata ipMetadata
    ) external returns (uint256 tokenId, address ipId) {
        tokenId = _mint(tokenContract, tokenMetadata, msg.sender);
        ipId = _registerDerivativeIp(
            licenseIds,
            royaltyContext,
            tokenContract,
            tokenId,
            ipMetadata.name,
            ipMetadata.hash,
            ipMetadata.url
        );
        _setCustomIpMetadata(ipId, ipMetadata.customMetadata);
    }

    /// @notice Mints and registers a Story Protocol NFT into the protocol as an IP asset derivative with Signature.
    /// @dev This function allows the user to set the permission for the SPG with a
    /// signature to allow SPG call other modules like licensing module on behalf of the user.
    /// @param licenseIds The licenses to incorporate for the new IP.
    /// @param royaltyContext The bytes-encoded context for royalty policy to process.
    /// @param tokenContract The address of the NFT bound to the root-level IP.
    /// @param tokenMetadata Token metadata in bytes to include for NFT minting.
    /// @param ipMetadata Metadata related to IP attribution.
    /// @param signature The signature to set the permission for the IP.
    /// @return tokenId The identifier of the minted NFT.
    /// @return ipId The address identifier of the newly registered IP asset.
    function mintAndRegisterDerivativeIpWithSig(
        uint256[] calldata licenseIds,
        bytes calldata royaltyContext,
        address tokenContract,
        bytes calldata tokenMetadata,
        Metadata.IPMetadata calldata ipMetadata,
        SPG.Signature calldata signature
    ) external returns (uint256 tokenId, address ipId) {
        tokenId = _mint(tokenContract, tokenMetadata, msg.sender);
        ipId = _registerDerivativeIp(
            licenseIds,
            royaltyContext,
            tokenContract,
            tokenId,
            ipMetadata.name,
            ipMetadata.hash,
            ipMetadata.url
        );
        _setPermissionWithSig(ipId, signature.signer, signature.deadline, signature.signature);
        _setCustomIpMetadata(ipId, ipMetadata.customMetadata);
    }

    // TODO: Implement the function once `IPolicyFrameworkManager` has `registerPolicy` function exposed.
    // function createPolicy(address policyFrameworkManager, bytes memory policyData) external returns (uint256 policyId) {
    //     policyId = IPolicyFrameworkManager(policyFrameworkManager).registerPolicy(policyData);
    // }

    /// @notice Create a new policy to Licensing Module via the PIL Policy Framework Manager.
    /// @param pilPolicy The PIL policy to add to the Licensing Module.
    /// @param transferable Whether or not the license is transferable.
    /// @param royaltyPolicy Address of a royalty policy contract (e.g. RoyaltyPolicyLAP) that will handle royalty payments.
    /// @param mintingFee Fee to be paid when minting a license.
    /// @param mintingFeeToken Token to be used to pay the minting fee.
    /// @return policyId The ID of the newly registered policy.
    function createPolicyPIL(
        PILPolicy memory pilPolicy,
        bool transferable,
        address royaltyPolicy,
        uint256 mintingFee,
        address mintingFeeToken
    ) external returns (uint256 policyId) {
        policyId = PIL_POLICY_FRAMEWORK_MANAGER.registerPolicy(
            RegisterPILPolicyParams({
                transferable: transferable,
                royaltyPolicy: royaltyPolicy,
                mintingFee: mintingFee,
                mintingFeeToken: mintingFeeToken,
                policy: pilPolicy
            })
        );
    }

    /// @notice Add a PIL policy to an IPAsset. Create a new PIL policy if it doesn't exist.
    /// @param pilPolicy The PIL policy to add to the Licensing Module.
    /// @param transferable Whether or not the license is transferable.
    /// @param royaltyPolicy Address of a royalty policy contract (e.g. RoyaltyPolicyLAP) that will handle royalty payments.
    /// @param mintingFee Fee to be paid when minting a license.
    /// @param mintingFeeToken Token to be used to pay the minting fee.
    /// @param ipId The address of the IP asset to add the policy to.
    /// @return policyGlobalId The ID of the newly (or existing) registered policy.
    /// @return policyIndexOnIpId The index of the policy on the IP asset.
    function addPILPolicyToIp(
        PILPolicy memory pilPolicy,
        bool transferable,
        address royaltyPolicy,
        uint256 mintingFee,
        address mintingFeeToken,
        address ipId
    ) external returns (uint256 policyGlobalId, uint256 policyIndexOnIpId) {
        policyGlobalId = PIL_POLICY_FRAMEWORK_MANAGER.registerPolicy(
            RegisterPILPolicyParams({
                transferable: transferable,
                royaltyPolicy: royaltyPolicy,
                mintingFee: mintingFee,
                mintingFeeToken: mintingFeeToken,
                policy: pilPolicy
            })
        );
        policyIndexOnIpId = LICENSING_MODULE.addPolicyToIp(ipId, policyGlobalId);
    }

    /// @notice Mint a license for an IP asset.
    /// @param policyId The ID of the policy that will identify the licensing terms of the IP.
    /// @param licensorIpId The address of the IP asset being licensed.
    /// @param amount The amount of licenses to mint.
    /// @param royaltyContext The bytes-encoded context for royalty policy to process.
    /// @return licenseId The ID of the minted license NFT.
    function mintLicense(
        uint256 policyId,
        address licensorIpId,
        uint256 amount,
        bytes memory royaltyContext
    ) external returns (uint256 licenseId) {
        licenseId = LICENSING_MODULE.mintLicense(policyId, licensorIpId, amount, msg.sender, royaltyContext);
    }

    /// @notice Mint a license for an IP asset.
    /// @param policyId The ID of the policy that will identify the licensing terms of the IP.
    /// @param licensorTokenContract The address of the contract of the NFT being licensed.
    /// @param licensorTokenId The id of the NFT being licensed.
    /// @param amount The amount of licenses to mint.
    /// @param royaltyContext The bytes-encoded context for royalty policy to process.
    /// @return licenseId The ID of the minted license NFT.
    function mintLicense(
        uint256 policyId,
        address licensorTokenContract,
        uint256 licensorTokenId,
        uint256 amount,
        bytes memory royaltyContext
    ) external returns (uint256 licenseId) {
        licenseId = _mintLicense(policyId, licensorTokenContract, licensorTokenId, amount, royaltyContext);
    }

    /// @notice Mint a license for an IP asset using the PIL Policy Framework Manager.
    /// @param pilPolicy The PIL policy to use or add to the Licensing Module.
    /// @param licensorIpId The address of the IP asset being licensed.
    /// @param amount The amount of licenses to mint.
    /// @param royaltyContext The bytes-encoded context for royalty policy to process.
    /// @param transferable Whether or not the license is transferable.
    /// @param royaltyPolicy Address of a royalty policy contract (e.g. RoyaltyPolicyLAP) that will handle royalty payments.
    /// @param mintingFee Fee to be paid when minting a license.
    /// @param mintingFeeToken Token to be used to pay the minting fee.
    /// @return licenseId The ID of the minted license NFT.
    function mintLicensePIL(
        PILPolicy memory pilPolicy,
        address licensorIpId,
        uint256 amount,
        bytes memory royaltyContext,
        bool transferable,
        address royaltyPolicy,
        uint256 mintingFee,
        address mintingFeeToken
    ) external returns (uint256 licenseId) {
        uint256 policyId = PIL_POLICY_FRAMEWORK_MANAGER.registerPolicy(
            RegisterPILPolicyParams({
                transferable: transferable,
                royaltyPolicy: royaltyPolicy,
                mintingFee: mintingFee,
                mintingFeeToken: mintingFeeToken,
                policy: pilPolicy
            })
        );
        licenseId = LICENSING_MODULE.mintLicense(policyId, licensorIpId, amount, msg.sender, royaltyContext);
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

    /// @dev Registers an NFT into the protocol as a new IP asset.
    /// @param tokenContract The address of the contract of the NFT being registered.
    /// @param tokenId The id of the NFT being registered.
    /// @param ipName The name assigned to the IP on registration.
    /// @param contentHash The content hash assigned to the IP on registration.
    /// @param externalURL An external URI to link to the IP.
    function _registerIp(
        address tokenContract,
        uint256 tokenId,
        string memory ipName,
        bytes32 contentHash,
        string calldata externalURL
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
    }

    /// @dev Sets permission to allow SPG call other modules on behalf of user with user's signature.
    /// @param ipId The address of the IP asset to set the permission for.
    /// @param signer The address of the signer to set the permission for.
    /// @param deadline The deadline for the signature to be valid.
    /// @param signature The signature to set the permission for the IP.
    function _setPermissionWithSig(address ipId, address signer, uint256 deadline, bytes calldata signature) internal {
        AccessPermission.Permission[] memory permissionList = new AccessPermission.Permission[](2);
        permissionList[0] = AccessPermission.Permission({
            ipAccount: ipId,
            signer: address(this),
            to: address(LICENSING_MODULE),
            func: bytes4(0),
            permission: AccessPermission.ALLOW
        });
        permissionList[1] = AccessPermission.Permission({
            ipAccount: ipId,
            signer: address(this),
            to: address(metadataResolver),
            func: bytes4(0),
            permission: AccessPermission.ALLOW
        });

        IIPAccount(payable(ipId)).executeWithSig(
            address(ACCESS_CONTROLLER),
            0,
            abi.encodeWithSignature("setBatchPermissions((address,address,address,bytes4,uint8)[])", permissionList),
            signer,
            deadline,
            signature
        );
    }

    /// @dev Registers an existing NFT into the protocol as an IP Asset derivative.
    /// @param licenseIds The parent IP asset licenses used to derive the new IP asset.
    /// @param royaltyContext The bytes-encoded context for royalty policy to process.
    /// @param tokenContract The address of the contract of the NFT being registered.
    /// @param tokenId The id of the NFT being registered.
    /// @param ipName The name assigned to the IP on registration.
    /// @param contentHash The content hash assigned to the IP on registration.
    /// @param externalURL An external URI to link to the IP.
    function _registerDerivativeIp(
        uint256[] memory licenseIds,
        bytes memory royaltyContext,
        address tokenContract,
        uint256 tokenId,
        string memory ipName,
        bytes32 contentHash,
        string calldata externalURL
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
            royaltyContext,
            block.chainid,
            tokenContract,
            tokenId,
            address(metadataResolver),
            true,
            canonicalMetadata
        );
    }

    /// @dev Sets custom metadata for an IPA using the default resolver contract.
    function _setCustomIpMetadata(address ipId, Metadata.Attribute[] calldata metadata) internal {
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

    /// @dev Mint license
    function _mintLicense(
        uint256 policyId,
        address licensorTokenContract,
        uint256 licensorTokenId,
        uint256 amount,
        bytes memory royaltyContext
    ) internal returns (uint256 licenseId) {
        address licensorIpId = IP_ASSET_REGISTRY.ipId(block.chainid, licensorTokenContract, licensorTokenId);
        licenseId = LICENSING_MODULE.mintLicense(policyId, licensorIpId, amount, msg.sender, royaltyContext);
    }
}
