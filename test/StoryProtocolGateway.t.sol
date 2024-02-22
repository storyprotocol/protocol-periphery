// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IPAssetRegistry } from "@storyprotocol/contracts/registries/IPAssetRegistry.sol";
import { LicensingModule } from "@storyprotocol/contracts/modules/licensing/LicensingModule.sol";
import { ILicensingModule } from "@storyprotocol/contracts/interfaces/modules/licensing/ILicensingModule.sol";
import { IRoyaltyPolicyLAP } from "@storyprotocol/contracts/interfaces/modules/royalty/policies/IRoyaltyPolicyLAP.sol";
import { AccessPermission } from "@storyprotocol/contracts/lib/AccessPermission.sol";
import { ModuleRegistry } from "@storyprotocol/contracts/registries/ModuleRegistry.sol";
import { PILPolicy, IPILPolicyFrameworkManager, RegisterPILPolicyParams } from "@storyprotocol/contracts/interfaces/modules/licensing/IPILPolicyFrameworkManager.sol";
import { IP } from "@storyprotocol/contracts/lib/IP.sol";
import { AccessController } from "@storyprotocol/contracts/AccessController.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { IPResolver } from "@storyprotocol/contracts/resolvers/IPResolver.sol";
import { KeyValueResolver } from "@storyprotocol/contracts/resolvers/KeyValueResolver.sol";

import { MockERC721Cloneable } from "./mocks/nft/MockERC721Cloneable.sol";
import { ForkTest } from "./utils/Fork.t.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { ERC721SPNFT } from "contracts/nft/ERC721SPNFT.sol";
import { SPG } from "contracts/lib/SPG.sol";
import { Metadata } from "contracts/lib/Metadata.sol";
import { StoryProtocolGateway } from "contracts/StoryProtocolGateway.sol";

/// @title Story Protocol Gateway Test Contract
contract StoryProtocolGatewayTest is ForkTest {
    // TODO: Switch to programmatically loading this as a JSON from @protocol-core.
    address internal GOVERNANCE = address(0x7f7eE01b9af466ff95A62A1D52dA350b0f24A445);
    address internal GOVERNANCE_ADMIN = address(0xf398C12A45Bc409b6C652E25bb0a3e702492A4ab);
    address internal ipAssetRegistryAddr = address(0x980d2c331E8fD31D7397d83AA9Bba44EaA4daeBC);
    address internal licensingModuleAddr = address(0x46d7d7f2450066344B291e182371E8885558568a);
    address internal ipResolverAddr = address(0xF1d5e6f17580680f106b91E1c00E3896E9fC95AD);
    address internal accessControllerAddr = address(0xaFfE6DE30Dfa2b35b63789b9aBF45b0A5Da201Eb);
    address internal pilPolicyFrameworkManagerAddr = address(0x3E881bEB7DeD9610CBCD0049972Ab12c2859170f);
    address internal moduleRegistryAddr = address(0x20Ec5239BC268b485E4372EA1a287434d2030fD2);

    MockERC721Cloneable internal externalNFT;
    IPAssetRegistry internal ipAssetRegistry;
    ILicensingModule internal licensingModule;
    IPResolver internal ipResolver;
    ERC721SPNFT internal nft;
    ModuleRegistry internal moduleRegistry;
    AccessController internal accessController;
    IPILPolicyFrameworkManager internal policyManager;

    // Metadata for our default SPG test collection.
    string internal SPG_DEFAULT_NFT_NAME = "SPG Default Collection";
    string internal SPG_DEFAULT_NFT_SYMBOL = "IP";
    uint256 internal SPG_DEFAULT_NFT_MAX_SUPPLY = 99;
    string internal SPG_CONTRACT_DESCRIPTION = "Test SPG contract";
    string internal SPG_CONTRACT_IMAGE = "https://storyprotocol.xyz/ip.jpeg";
    string internal SPG_CONTRACT_URI = "https://storyprotocol.xyz";

    // Test IP metadata.
    string internal IP_METADATA_NAME = "Name for an IPA";
    bytes32 internal IP_METADATA_HASH = bytes32("sup");
    string internal IP_METADATA_URL = "https://storyprotocol.xyz/ip/0";
    string internal IP_CUSTOM_METADATA_KEY = "copyright type";
    string internal IP_CUSTOM_METADATA_VALUE = "literary work";

    // Test NFT Token Metadata.
    string internal TOKEN_METADATA_NAME = "IPA #100";
    string internal TOKEN_METADATA_DESCRIPTION = "Hello I am an IPA";
    string internal TOKEN_METADATA_URL = "https://storyprotocol.xyz/stories/0";
    string internal TOKEN_METADATA_IMAGE = "https://storyprotocol.xyz/stories/0.jpeg";
    string internal TOKEN_CUSTOM_METADATA_KEY = "Galaxy";
    string internal TOKEN_CUSTOM_METADATA_VALUE = "Renaissance";

    uint256 internal policyId;

    bytes internal emptyRoyaltyPolicyLAPInitParams;

    /// @notice The Story Protocol Gateway SUT.
    StoryProtocolGateway public spg;

    function setUp() public virtual override(ForkTest) {
        ForkTest.setUp();
        ipAssetRegistry = IPAssetRegistry(ipAssetRegistryAddr);
        licensingModule = ILicensingModule(licensingModuleAddr);
        accessController = AccessController(accessControllerAddr);
        policyManager = IPILPolicyFrameworkManager(pilPolicyFrameworkManagerAddr);
        moduleRegistry = ModuleRegistry(moduleRegistryAddr);
        externalNFT = new MockERC721Cloneable();
        externalNFT.initialize("externalNFT", "eIP");
        externalNFT.mint(alice, 0);
        externalNFT.mint(bob, 1);
        ipResolver = IPResolver(ipResolverAddr);

        PILPolicy memory pilPolicy = PILPolicy({
            attribution: true,
            commercialUse: false,
            commercialAttribution: false,
            commercializerChecker: address(0),
            commercializerCheckerData: "",
            commercialRevShare: 0,
            derivativesAllowed: false,
            derivativesAttribution: false,
            derivativesApproval: false,
            derivativesReciprocal: false,
            territories: new string[](0),
            distributionChannels: new string[](0),
            contentRestrictions: new string[](0)
        });

        assertTrue(licensingModule.isFrameworkRegistered(address(policyManager)));
        policyId = policyManager.registerPolicy(
            RegisterPILPolicyParams({
                transferable: true,
                royaltyPolicy: address(0),
                mintingFee: 0,
                mintingFeeToken: address(0),
                policy: pilPolicy
            })
        );

        spg = new StoryProtocolGateway(
            ipAssetRegistryAddr,
            licensingModuleAddr,
            pilPolicyFrameworkManagerAddr,
            ipResolverAddr
        );

        vm.prank(GOVERNANCE_ADMIN);
        moduleRegistry.registerModule("SPG", address(spg));

        vm.prank(GOVERNANCE_ADMIN);
        accessController.setGlobalPermission(
            address(spg),
            address(licensingModule),
            ILicensingModule.addPolicyToIp.selector,
            AccessPermission.ALLOW
        );

        vm.prank(GOVERNANCE_ADMIN);
        accessController.setGlobalPermission(
            address(ipAssetRegistry),
            address(licensingModule),
            ILicensingModule.linkIpToParents.selector,
            AccessPermission.ALLOW
        );

        vm.prank(GOVERNANCE_ADMIN);
        accessController.setGlobalPermission(
            address(spg),
            address(ipResolver),
            KeyValueResolver.setValue.selector,
            AccessPermission.ALLOW
        );

        vm.prank(alice);
        ipAssetRegistry.setApprovalForAll(address(spg), true);

        vm.prank(bob);
        ipAssetRegistry.setApprovalForAll(address(spg), true);

        Metadata.ContractData memory contractData = Metadata.ContractData({
            description: SPG_CONTRACT_DESCRIPTION,
            image: SPG_CONTRACT_IMAGE,
            uri: SPG_CONTRACT_URI
        });
        vm.prank(cal);
        nft = ERC721SPNFT(
            spg.createIpCollection(
                SPG.CollectionType.SP_DEFAULT_COLLECTION,
                SPG.CollectionSettings({
                    name: SPG_DEFAULT_NFT_NAME,
                    symbol: SPG_DEFAULT_NFT_SYMBOL,
                    maxSupply: SPG_DEFAULT_NFT_MAX_SUPPLY,
                    contractMetadata: abi.encode(contractData)
                }),
                SPG.MintSettings({ start: 0, end: block.timestamp + 999 })
            )
        );

        emptyRoyaltyPolicyLAPInitParams = abi.encode(
            IRoyaltyPolicyLAP.InitParams({
                targetAncestors: new address[](0),
                targetRoyaltyAmount: new uint32[](0),
                parentAncestors1: new address[](0),
                parentAncestors2: new address[](0),
                parentAncestorsRoyalties1: new uint32[](0),
                parentAncestorsRoyalties2: new uint32[](0)
            })
        );
    }

    /// @notice Tests that SPG initialization works as expected.
    function test_SPG_Constructor() public {
        assertEq(address(spg.LICENSING_MODULE()), licensingModuleAddr);
        assertEq(address(spg.IP_ASSET_REGISTRY()), ipAssetRegistryAddr);
        assertEq(address(spg.metadataResolver()), ipResolverAddr);
    }

    /// @notice Tests that the default collection is correctly configured.
    function test_SPG_CreateIPCollection() public {
        SPG.MintSettings memory mintSettings = spg.getMintSettings(address(nft));
        assertEq(mintSettings.start, block.timestamp);
        assertEq(mintSettings.end, block.timestamp + 999);
        assertEq(nft.maxSupply(), SPG_DEFAULT_NFT_MAX_SUPPLY);
        assertEq(nft.owner(), cal);
        assertTrue(nft.isMinter(address(spg)));
        assertEq(nft.name(), SPG_DEFAULT_NFT_NAME);
        assertEq(nft.symbol(), SPG_DEFAULT_NFT_SYMBOL);

        string memory uriEncoding = string(
            abi.encodePacked(
                '{"description": "Test SPG contract", ',
                '"external_link": "https://storyprotocol.xyz", ',
                '"image": "https://storyprotocol.xyz/ip.jpeg", ',
                '"name": "SPG Default Collection"}'
            )
        );
        string memory expectedURI = string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(bytes(string(abi.encodePacked(uriEncoding))))
            )
        );
        assertEq(nft.contractURI(), expectedURI);
    }

    /// @notice Tests that unsupported collections may not be created.
    function test_SPG_CreateIpCollection_Reverts_InvalidCollection() public {
        vm.expectRevert(Errors.SPG__CollectionTypeUnsupported.selector);
        spg.createIpCollection(
            SPG.CollectionType(SPG.CollectionType.RFU),
            SPG.CollectionSettings({
                name: SPG_DEFAULT_NFT_NAME,
                symbol: SPG_DEFAULT_NFT_SYMBOL,
                maxSupply: SPG_DEFAULT_NFT_MAX_SUPPLY,
                contractMetadata: ""
            }),
            SPG.MintSettings({ start: 0, end: 0 })
        );
    }

    /// @notice Tests that registration and remixing of an existing NFT works.
    function test_SPG_RegisterIp() public {
        Metadata.Attribute[] memory customIpMetadata = new Metadata.Attribute[](1);
        customIpMetadata[0] = Metadata.Attribute(IP_CUSTOM_METADATA_KEY, IP_CUSTOM_METADATA_VALUE);

        Metadata.IPMetadata memory ipMetadata = Metadata.IPMetadata({
            name: IP_METADATA_NAME,
            hash: IP_METADATA_HASH,
            url: IP_METADATA_URL,
            customMetadata: customIpMetadata
        });
        vm.prank(alice);
        address ipId = spg.registerIp(policyId, address(externalNFT), 0, ipMetadata);
        assertTrue(ipAssetRegistry.isRegistered(ipId));

        uint256 licenseId = licensingModule.mintLicense(policyId, ipId, 1, bob, emptyRoyaltyPolicyLAPInitParams);
        uint256[] memory licenses = new uint256[](1);
        licenses[0] = licenseId;
        vm.prank(bob);
        address derivativeIpId = spg.registerDerivativeIp(licenses, "", address(externalNFT), 1, ipMetadata);
        assertTrue(ipAssetRegistry.isRegistered(derivativeIpId));
    }

    /// @notice Tests that registrations of IP by non-owners revert.
    function test_SPG_RegisterIp_Reverts_InvalidOwner() public {
        Metadata.Attribute[] memory customIpMetadata = new Metadata.Attribute[](1);
        customIpMetadata[0] = Metadata.Attribute(IP_CUSTOM_METADATA_KEY, IP_CUSTOM_METADATA_VALUE);

        Metadata.IPMetadata memory ipMetadata = Metadata.IPMetadata({
            name: IP_METADATA_NAME,
            hash: IP_METADATA_HASH,
            url: IP_METADATA_URL,
            customMetadata: customIpMetadata
        });
        vm.expectRevert(Errors.SPG__InvalidOwner.selector);
        spg.registerIp(policyId, address(externalNFT), 0, ipMetadata);
    }

    /// @notice Tests that registering NFTs minted from the default collection works.
    function test_SPG_MintAndRegisterIp() public {
        Metadata.Attribute[] memory customIpMetadata = new Metadata.Attribute[](1);
        customIpMetadata[0] = Metadata.Attribute(IP_CUSTOM_METADATA_KEY, IP_CUSTOM_METADATA_VALUE);

        Metadata.IPMetadata memory ipMetadata = Metadata.IPMetadata({
            name: IP_METADATA_NAME,
            hash: IP_METADATA_HASH,
            url: IP_METADATA_URL,
            customMetadata: customIpMetadata
        });

        Metadata.Attribute[] memory customTokenMetadata = new Metadata.Attribute[](1);
        customTokenMetadata[0] = Metadata.Attribute(TOKEN_CUSTOM_METADATA_KEY, TOKEN_CUSTOM_METADATA_VALUE);
        bytes memory tokenMetadata = abi.encode(
            Metadata.TokenMetadata({
                name: TOKEN_METADATA_NAME,
                description: TOKEN_METADATA_DESCRIPTION,
                externalUrl: TOKEN_METADATA_URL,
                image: TOKEN_METADATA_IMAGE,
                attributes: customTokenMetadata
            })
        );

        vm.prank(alice);
        (, address ipId) = spg.mintAndRegisterIp(policyId, address(nft), tokenMetadata, ipMetadata);
        assertTrue(ipAssetRegistry.isRegistered(ipId));

        uint256 licenseId = licensingModule.mintLicense(policyId, ipId, 1, bob, emptyRoyaltyPolicyLAPInitParams);
        uint256[] memory licenses = new uint256[](1);
        licenses[0] = licenseId;
        vm.prank(bob);
        (, address derivativeIpId) = spg.mintAndRegisterDerivativeIp(
            licenses,
            "",
            address(nft),
            tokenMetadata,
            ipMetadata
        );
        assertTrue(ipAssetRegistry.isRegistered(derivativeIpId));
    }

    /// @notice Tests that SPG mints can be configured by collection owners.
    function test_SPG_ConfigureMintSettings() public {
        SPG.MintSettings memory mintSettings = SPG.MintSettings({ start: 0, end: block.timestamp + 101 });
        vm.prank(cal);
        nft.configureMintSettings(address(spg), mintSettings);
        SPG.MintSettings memory updatedMintSettings = spg.getMintSettings(address(nft));
        assertEq(updatedMintSettings.start, block.timestamp);
        assertEq(updatedMintSettings.end, block.timestamp + 101);
    }

    /// @notice Tests that SPG mint setting configurations revert if don by an invalid token.
    function test_SPG_ConfigureMintSettings_Reverts_InvalidToken() public {
        SPG.MintSettings memory mintSettings = SPG.MintSettings({ start: 0, end: block.timestamp + 101 });
        vm.prank(address(externalNFT));
        vm.expectRevert(Errors.SPG__CollectionTypeUnsupported.selector);
        spg.configureMintSettings(mintSettings);
    }

    /// @notice Tests that SPG mints revert for collections not initialized by the SPG.
    function test_SPG_ConfigureMintSettings_Reverts_UninitializedCollection() public {
        SPG.MintSettings memory mintSettings = SPG.MintSettings({ start: 0, end: block.timestamp + 101 });
        ERC721SPNFT uninitializedNFT = new ERC721SPNFT(address(this));
        vm.prank(address(uninitializedNFT));
        vm.expectRevert(Errors.SPG__CollectionNotInitialized.selector);
        spg.configureMintSettings(mintSettings);
    }

    /// @notice Tests that SPG registrations with mints revert if the collection mints have yet to begin or have ended.
    function test_SPG_RegisterIp_Reverts_InvalidTimestamp() public {
        Metadata.ContractData memory contractData = Metadata.ContractData({
            description: SPG_CONTRACT_DESCRIPTION,
            image: SPG_CONTRACT_IMAGE,
            uri: SPG_CONTRACT_URI
        });
        vm.prank(cal);
        ERC721SPNFT token = ERC721SPNFT(
            spg.createIpCollection(
                SPG.CollectionType.SP_DEFAULT_COLLECTION,
                SPG.CollectionSettings({
                    name: SPG_DEFAULT_NFT_NAME,
                    symbol: SPG_DEFAULT_NFT_SYMBOL,
                    maxSupply: SPG_DEFAULT_NFT_MAX_SUPPLY,
                    contractMetadata: abi.encode(contractData)
                }),
                SPG.MintSettings({ start: block.timestamp + 1, end: block.timestamp + 99 })
            )
        );

        Metadata.Attribute[] memory customIpMetadata = new Metadata.Attribute[](1);
        customIpMetadata[0] = Metadata.Attribute(IP_CUSTOM_METADATA_KEY, IP_CUSTOM_METADATA_VALUE);

        Metadata.IPMetadata memory ipMetadata = Metadata.IPMetadata({
            name: IP_METADATA_NAME,
            hash: IP_METADATA_HASH,
            url: IP_METADATA_URL,
            customMetadata: customIpMetadata
        });

        Metadata.Attribute[] memory customTokenMetadata = new Metadata.Attribute[](1);
        customTokenMetadata[0] = Metadata.Attribute(TOKEN_CUSTOM_METADATA_KEY, TOKEN_CUSTOM_METADATA_VALUE);
        bytes memory tokenMetadata = abi.encode(
            Metadata.TokenMetadata({
                name: TOKEN_METADATA_NAME,
                description: TOKEN_METADATA_DESCRIPTION,
                externalUrl: TOKEN_METADATA_URL,
                image: TOKEN_METADATA_IMAGE,
                attributes: customTokenMetadata
            })
        );

        vm.expectRevert(Errors.SPG__MintingNotYetStarted.selector);
        spg.mintAndRegisterIp(policyId, address(token), tokenMetadata, ipMetadata);
        vm.warp(block.timestamp + 100);
        vm.expectRevert(Errors.SPG__MintingAlreadyEnded.selector);
        spg.mintAndRegisterIp(policyId, address(token), tokenMetadata, ipMetadata);
    }
}
