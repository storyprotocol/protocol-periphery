// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IPAssetRegistry } from "@storyprotocol/contracts/registries/IPAssetRegistry.sol";
import { ILicensingModule } from "@storyprotocol/contracts/interfaces/modules/licensing/ILicensingModule.sol";
import { AccessPermission } from "@storyprotocol/contracts/lib/AccessPermission.sol";
import { ModuleRegistry } from "@storyprotocol/contracts/registries/ModuleRegistry.sol";
import { IUMLPolicyFrameworkManager } from "./interfaces/IUMLPolicyFrameworkManager.sol";
import { UMLPolicy } from "./interfaces/IUMLPolicyFrameworkManager.sol";
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
    address public GOVERNANCE = address(0xc0F5bBc6D8853BC66a7a323aEC993c6AB5f23c90);
    address public GOVERNANCE_ADMIN = address(0x9A3A5EdDDFEe1E3A1BBef6Fdf0850B10D4979405);
    address ipAssetRegistryAddr = address(0x7567ea73697De50591EEc317Fe2b924252c41608);
    address licensingModuleAddr = address(0xC7FB0655bf248633235B79c961Ee033b34146BB2);
    address ipResolverAddr = address(0xEF808885355B3c88648D39c9DB5A0c08D99C6B71);
    address accessControllerAddr = address(0x263f0634E64A191884cc778E58f505F758b295E0);
    address umlPolicyFrameworkManagerAddr = address(0xDEc23819025c761FAAbA391AC7dBB3FEDB3CDDF7);
    address moduleRegistryAddr = address(0xA32408A1d408Aa7cC88471Cc4912c029f67f0087);

    MockERC721Cloneable public externalNFT;
    IPAssetRegistry public ipAssetRegistry;
    ILicensingModule public licensingModule;
    IPResolver public ipResolver;
    ERC721SPNFT public nft;
    ModuleRegistry public moduleRegistry;
    AccessController public accessController;
    IUMLPolicyFrameworkManager public policyManager;

    // Metadata for our default SPG test collection.
    string SPG_DEFAULT_NFT_NAME = "SPG Default Collection";
    string SPG_DEFAULT_NFT_SYMBOL = "IP";
    uint256 SPG_DEFAULT_NFT_MAX_SUPPLY = 99;
    string SPG_CONTRACT_DESCRIPTION = "Test SPG contract";
    string SPG_CONTRACT_IMAGE = "https://storyprotocol.xyz/ip.jpeg";
    string SPG_CONTRACT_URI = "https://storyprotocol.xyz";

    // Test IP metadata.
    string IP_METADATA_NAME = "Name for an IPA";
    bytes32 IP_METADATA_HASH = bytes32("sup");
    string IP_METADATA_URL = "https://storyprotocol.xyz/ip/0";
    string IP_CUSTOM_METADATA_KEY = "copyright type";
    string IP_CUSTOM_METADATA_VALUE = "literary work";

    // Test NFT Token Metadata.
    string TOKEN_METADATA_NAME = "IPA #100";
    string TOKEN_METADATA_DESCRIPTION = "Hello I am an IPA";
    string TOKEN_METADATA_URL = "https://storyprotocol.xyz/stories/0";
    string TOKEN_METADATA_IMAGE = "https://storyprotocol.xyz/stories/0.jpeg";
    string TOKEN_CUSTOM_METADATA_KEY = "Galaxy";
    string TOKEN_CUSTOM_METADATA_VALUE = "Renaissance";

    /// @notice Test policy for IP registrations.
    UMLPolicy public policy;
    uint256 public policyId;

    /// @notice The Story Protocol Gateway SUT.
    StoryProtocolGateway public spg;

    function setUp() public virtual override(ForkTest) {
        ForkTest.setUp();
        ipAssetRegistry = IPAssetRegistry(ipAssetRegistryAddr);
        licensingModule = ILicensingModule(licensingModuleAddr);
        accessController = AccessController(accessControllerAddr);
        policyManager = IUMLPolicyFrameworkManager(umlPolicyFrameworkManagerAddr);
        moduleRegistry = ModuleRegistry(moduleRegistryAddr);
        externalNFT = new MockERC721Cloneable();
        externalNFT.initialize("externalNFT", "eIP");
        ipResolver = IPResolver(ipResolverAddr);

        policy = UMLPolicy({
            transferable: false,
            attribution: true,
            commercialUse: false,
            commercialAttribution: false,
            commercializers: new string[](0),
            commercialRevShare: 0,
            derivativesAllowed: false,
            derivativesAttribution: false,
            derivativesApproval: false,
            derivativesReciprocal: false,
            derivativesRevShare: 0,
            territories: new string[](0),
            distributionChannels: new string[](0),
            contentRestrictions: new string[](0),
            royaltyPolicy: address(0)
        });

        assertTrue(licensingModule.isFrameworkRegistered(address(policyManager)));
        policyId = policyManager.registerPolicy(policy);

        spg = new StoryProtocolGateway(
            ipAssetRegistryAddr,
            licensingModuleAddr,
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
            address(spg),
            address(ipResolver),
            KeyValueResolver.setValue.selector,
            AccessPermission.ALLOW
        );

        Metadata.ContractData memory contractData = Metadata.ContractData({
            description: SPG_CONTRACT_DESCRIPTION,
            image: SPG_CONTRACT_IMAGE,
            uri: SPG_CONTRACT_URI
        });
        nft = ERC721SPNFT(
            spg.createIpCollection(
                SPG.CollectionType.SP_DEFAULT_COLLECTION,
                SPG.CollectionSettings({
                    name: SPG_DEFAULT_NFT_NAME,
                    symbol: SPG_DEFAULT_NFT_SYMBOL,
                    maxSupply: SPG_DEFAULT_NFT_MAX_SUPPLY,
                    contractMetadata: abi.encode(contractData)
                }),
                SPG.MintSettings({
                    start: 0,
                    end: block.timestamp + 999
                })
            )
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
        assertEq(nft.owner(), address(this));
        assertTrue(nft.isMinter(address(spg)));
        assertEq(nft.name(), SPG_DEFAULT_NFT_NAME);
        assertEq(nft.symbol(), SPG_DEFAULT_NFT_SYMBOL);

        string memory uriEncoding = string(abi.encodePacked(
            '{"description": "Test SPG contract", ',
            '"external_link": "https://storyprotocol.xyz", ',
            '"image": "https://storyprotocol.xyz/ip.jpeg", ',
            '"name": "SPG Default Collection"}'
        ));
        string memory expectedURI = string(abi.encodePacked(
            "data:application/json;base64,",
            Base64.encode(bytes(string(abi.encodePacked(uriEncoding))))
        ));
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
            SPG.MintSettings({
                start: 0,
                end: 0
            })
        );
    }

    /// @notice Tests that basic registration of an existing NFT works.
    function test_SPG_RegisterIp() public {
        externalNFT.mint(alice, 0);
        Metadata.Attribute[] memory customIpMetadata = new Metadata.Attribute[](1);
        customIpMetadata[0] = Metadata.Attribute(IP_CUSTOM_METADATA_KEY, IP_CUSTOM_METADATA_VALUE);

        Metadata.IPMetadata memory ipMetadata = Metadata.IPMetadata({
            name: IP_METADATA_NAME,
            hash: IP_METADATA_HASH,
            url: IP_METADATA_URL,
            customMetadata: customIpMetadata
        });
        vm.prank(alice);
        address ipId = spg.registerIp(
            policyId,
            address(externalNFT),
            0,
            ipMetadata
        );
        assertTrue(ipAssetRegistry.isRegistered(ipId));
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
        bytes memory tokenMetadata = abi.encode(Metadata.TokenMetadata({
            name: TOKEN_METADATA_NAME,
            description: TOKEN_METADATA_DESCRIPTION,
            externalUrl: TOKEN_METADATA_URL,
            image: TOKEN_METADATA_IMAGE,
            attributes: customTokenMetadata
        }));
        vm.prank(alice);
        (uint256 tokenId, address ipId) = spg.mintAndRegisterIp(
            policyId,
            address(nft),
            tokenMetadata,
            ipMetadata
        );
        assertTrue(ipAssetRegistry.isRegistered(ipId));
    }

}
