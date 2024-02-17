// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseTest } from "test/utils/Base.t.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { ERC721MetadataProvider } from "contracts/nft/ERC721MetadataProvider.sol";
import { Errors } from "contracts/lib/Errors.sol";

import { MockERC721SPNFT } from "test/mocks/nft/MockERC721SPNFT.sol";
import { Metadata } from "contracts/lib/Metadata.sol";

/// @title ERC721 Metadata Provider Test Contract
contract ERC721MetadataProviderTest is BaseTest {

    /// @notice Test contract metadata.
    string public constant CONTRACT_DESCRIPTION = "SP NFT Test Contract Description";
    string public constant CONTRACT_IMAGE = "https://storyprotocol.xyz/image.png";
    string public constant CONTRACT_URI = "https://storyprotocol.xyz";
    string public constant CONTRACT_NAME = "Test Contract";
    string public constant CONTRACT_SYMBOL = "Test Symbol";

    /// @notice Test token metadata.
    string public constant TOKEN_NAME = "SP NFT #1";
    string public constant TOKEN_DESCRIPTION = "This is a SP token";
    string public constant TOKEN_URL = "https://storyprotocol.xyz/token/1";
    string public constant TOKEN_IMAGE = "reddit.com/r/storyprotocol/image.png";

    /// @notice Test token attributes.
    string public constant ATTR_1_KEY = "Color";
    string public constant ATTR_1_VALUE = "Blue";
    string public constant ATTR_2_KEY = "Size";
    string public constant ATTR_2_VALUE = "Medium";
    string public constant ATTR_3_KEY = "Material";
    string public constant ATTR_3_VALUE = "Cotton";

    /// @notice Test token id.
    uint256 TEST_TOKEN = 0;

    /// @notice Mock SP NFT for testing metadata provider setting.
    MockERC721SPNFT public spNFT;

    /// @notice The metadata provider SUT.
    ERC721MetadataProvider public provider;

    /// @notice Test token metadata (encoded).
    bytes testTokenData;

    /// @notice Initializes the ERC721 Metadata Provider Test
    function setUp() public virtual override(BaseTest) {
        BaseTest.setUp();

        testTokenData = _generateTokenMetadata(
            TOKEN_NAME,
            TOKEN_DESCRIPTION,
            TOKEN_URL,
            TOKEN_IMAGE
        );

        Metadata.ContractData memory contractData = Metadata.ContractData({
            description: CONTRACT_DESCRIPTION,
            image: CONTRACT_IMAGE,
            uri: CONTRACT_URI
        });

        provider = new ERC721MetadataProvider();
        spNFT = new MockERC721SPNFT();
        spNFT.initialize(
            address(provider),
            abi.encode(contractData),
            CONTRACT_NAME,
            CONTRACT_SYMBOL
        );
    }

    /// @notice Tests that the metadata provider initialization is successful.
    function test_ERC721MetadataProvider_Initialize() public {
        assertEq(provider.token(), address(spNFT));
    }

    /// @notice Tests that the metadata provider contract URI works as expected.
    function test_ERC721MetadataProvider_ContractURI() public {
        string memory uriEncoding = string(abi.encodePacked(
            '{"description": "SP NFT Test Contract Description", ',
            '"external_link": "https://storyprotocol.xyz", ',
            '"image": "https://storyprotocol.xyz/image.png", ',
            '"name": "Test Contract"}'
        ));
        string memory expectedURI = string(abi.encodePacked(
            "data:application/json;base64,",
            Base64.encode(bytes(string(abi.encodePacked(uriEncoding))))
        ));
        assertEq(provider.contractURI(), expectedURI);
    }

    /// @notice Tests that the token URI correctly renders for a SP NFT.
    function test_ERC721MetadataProvider_TokenURI() public {
        spNFT.mint(alice, testTokenData);
        string memory uriEncoding = string(abi.encodePacked(
            '{"description": "This is a SP token", ',
            '"external_url": "https://storyprotocol.xyz/token/1", ',
            '"image": "reddit.com/r/storyprotocol/image.png", ',
            '"name": "SP NFT #1", ',
            '"attributes": [',
            '{"trait_type": "Color", "value": "Blue"}, ',
            '{"trait_type": "Size", "value": "Medium"}, ',
            '{"trait_type": "Material", "value": "Cotton"}',
            ']}'
        ));
        string memory expectedURI = string(abi.encodePacked(
            "data:application/json;base64,",
            Base64.encode(bytes(string(abi.encodePacked(uriEncoding))))
        ));
        assertEq(provider.tokenURI(0), expectedURI);
    }

    /// @notice Tests that metadata setting fails if the sender is not the token.
    function test_ERC721MetadataProvider_SetMetadata_Reverts_InvalidToken() public {
        vm.expectRevert(Errors.ERC721MetadataProvider__TokenInvalid.selector);
        provider.setMetadata(TEST_TOKEN, "");
    }

    /// @notice Tests that metadata setting fails if the name is invalid.
    // function test_ERC721MetadataProvider_SetMetadata_Reverts_InvalidName() public {
    //     vm.expectRevert(Errors.ERC721MetadataProvider__NameInvalid.selector);
    //     vm.prank(address(spNFT));
    //     provider.setMetadata(
    //         TEST_TOKEN,
    //         _generateTokenMetadata(
    //             "",
    //             TOKEN_DESCRIPTION,
    //             TOKEN_URL,
    //             TOKEN_IMAGE
    //         )
    //     );
    // }

    /// @notice Tests that metadata setting fails if the description is invalid.
    // function test_ERC721MetadataProvider_SetMetadata_Reverts_InvalidDescription() public {
    //     vm.expectRevert(Errors.ERC721MetadataProvider__DescriptionInvalid.selector);
    //     vm.prank(address(spNFT));
    //     provider.setMetadata(
    //         TEST_TOKEN,
    //         _generateTokenMetadata(
    //             TOKEN_NAME,
    //             "",
    //             TOKEN_URL,
    //             TOKEN_IMAGE
    //         )
    //     );
    // }

    /// @notice Tests that metadata setting fails if the URL is invalid.
    // function test_ERC721MetadataProvider_SetMetadata_Reverts_InvalidURL() public {
    //     vm.expectRevert(Errors.ERC721MetadataProvider__URLInvalid.selector);
    //     vm.prank(address(spNFT));
    //     provider.setMetadata(
    //         TEST_TOKEN,
    //         _generateTokenMetadata(
    //             TOKEN_NAME,
    //             TOKEN_DESCRIPTION,
    //             "",
    //             TOKEN_IMAGE
    //         )
    //     );
    // }

    /// @notice Tests that metadata setting fails if the image is invalid.
    // function test_ERC721MetadataProvider_SetMetadata_Reverts_InvalidImage() public {
    //     vm.expectRevert(Errors.ERC721MetadataProvider__ImageInvalid.selector);
    //     vm.prank(address(spNFT));
    //     provider.setMetadata(
    //         TEST_TOKEN,
    //         _generateTokenMetadata(
    //             TOKEN_NAME,
    //             TOKEN_DESCRIPTION,
    //             TOKEN_URL,
    //             ""
    //         )
    //     );
    // }

    /// @dev Generates bytes-encoded token metadata.
    function _generateTokenMetadata(string memory name, string memory description, string memory url, string memory image) internal pure returns (bytes memory) {
        Metadata.Attribute[] memory attributes = new Metadata.Attribute[](3);
        attributes[0] = Metadata.Attribute(ATTR_1_KEY, ATTR_1_VALUE);
        attributes[1] = Metadata.Attribute(ATTR_2_KEY, ATTR_2_VALUE);
        attributes[2] = Metadata.Attribute(ATTR_3_KEY, ATTR_3_VALUE);

        Metadata.TokenMetadata memory tokenData = Metadata.TokenMetadata({
            name: name,
            description: description,
            externalUrl: url,
            image: image,
            attributes: attributes
        });
        return abi.encode(tokenData);
    }
}
