// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ERC721SPNFT } from "contracts/nft/ERC721SPNFT.sol";
import { ERC721BaseTest } from "test/nft/erc721/ERC721Base.t.sol";
import { ERC721CloneableTest } from "test/nft/erc721/ERC721Cloneable.t.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { IStoryProtocolDrop } from "contracts/interfaces/IStoryProtocolDrop.sol";
import { SPG } from "contracts/lib/SPG.sol";
import { MockERC721MetadataProvider } from "test/mocks/nft/MockERC721MetadataProvider.sol";
import { MockStoryProtocolDrop } from "test/mocks/MockStoryProtocolDrop.sol";

/// @title ERC721 SP NFT Test Contract
contract ERC721SPNFTTest is ERC721BaseTest {

    /// @notice Mock collection-wide contract URI.
    string MOCK_CONTRACT_URI = "https://storyprotocol.xyz";

    /// @notice Mock token-specific URI.
    string MOCK_TOKEN_URI = "https://myawesometoken.xyz";

    /// @notice Mock attribute value for the required mock metadata provider.
    uint256 MOCK_CONTRACT_METADATA_ATTRIBUTE_X = 0;

    /// @notice Mock placeholder for the SP NFT owner.
    address owner = vm.addr(0x9999);

    /// @notice Mock placeholder for the SPG (initial NFT minter).
    address public spg;

    /// @notice Mock Story Protocol drops manager.
    address factory = vm.addr(0x69);


    /// @notice The ERC721 SP NFT SUT.
    ERC721SPNFT public spNFT;

    /// @notice Mock ERC-721 metadata provider.
    MockERC721MetadataProvider public provider;

    /// @notice The maximum token supply to configure for the collection.
    uint256 public constant MAX_SUPPLY = 3;

    /// Mock metadata to use for the ERC-721 SP NFT.
    string internal constant _NAME = "MOCK_NAME";
    string internal constant _SYMBOL = "MOCK_SYMBOL";

    /// @notice Initializes the ERC721 SP NFT test contract.
    function setUp() public virtual override(ERC721BaseTest) {
        ERC721BaseTest.setUp();
    }

    /// @notice Tests that the initialization works as expected.
    function test_ERC721SPNFT_Initialize() public {
        assertEq(spNFT.metadataProvider(), address(provider));
        assertTrue(spNFT.isMinter(spg));
        assertEq(spNFT.owner(), owner);
    }


    /// @notice Tests that initialization reverts if not called by the factory.
    function test_ERC721SPNFT_Initialize_Reverts_InvalidFactory() public {
        spNFT = new ERC721SPNFT(factory);
        vm.expectRevert(Errors.ERC721SPNFT__FactoryInvalid.selector);
        spNFT.initialize(
            owner,
            spg,
            address(provider),
            "",
            _NAME,
            _SYMBOL,
            MAX_SUPPLY
        );
    }


    /// @notice Tests that mints by registered minters work.
    function test_ERC721SPNFT_Mint() public {
        uint256 totalSupply = spNFT.totalSupply();
        uint256 balance = spNFT.balanceOf(alice);
        vm.expectEmit({ emitter: address(spNFT) });
        emit IERC721.Transfer(address(0), alice, TEST_TOKEN);
        _mintToken(alice, TEST_TOKEN);
        assertEq(spNFT.balanceOf(alice), balance + 1);
        assertEq(spNFT.totalSupply(), totalSupply + 1);
        assertEq(spNFT.ownerOf(TEST_TOKEN), alice);
        assertEq(spNFT.tokenURI(TEST_TOKEN), MOCK_TOKEN_URI);
        assertEq(spNFT.contractURI(), MOCK_CONTRACT_URI);
        assertEq(spNFT.metadataProvider(TEST_TOKEN), address(provider));
    }

    /// @notice Tests that mints performed by unregistered minters revert.
    function test_ERC721SPNFT_Mint_Reverts_MinterInvalid() public {
        vm.expectRevert(Errors.ERC721SPNFT__MinterInvalid.selector);
        spNFT.mint(alice, "");
    }

    /// @notice Tests that mints past the maximum supply revert.
    function test_ERC721SPNFT_Mint_Reverts_MaxSupply() public {
        vm.startPrank(spg);
        MockERC721MetadataProvider.TokenMetadata memory metadata = MockERC721MetadataProvider.TokenMetadata({
            url: MOCK_TOKEN_URI
        });
        spNFT.mint(alice, abi.encode(metadata));
        spNFT.mint(alice, abi.encode(metadata));
        spNFT.mint(alice, abi.encode(metadata));
        vm.expectRevert(Errors.ERC721__MaxSupplyReached.selector);
        spNFT.mint(alice, abi.encode(metadata));
    }

    /// @notice Tests that mints with non-compliant metadata revert.
    /// TODO: Add better error-handling around abi-decoding issues.
    function test_ERC721SPNFT_Mint_Reverts_MetadataInvalid() public {
        vm.expectRevert();
        vm.prank(spg);
        spNFT.mint(alice, "");
    }

    /// @notice Tests that token burns work as intended.
    function test_ERC721SPNFT_Burn() public {
        _mintToken(alice, TEST_TOKEN);
        uint256 totalSupply = spNFT.totalSupply();
        uint256 balance = spNFT.balanceOf(alice);
        vm.expectEmit({ emitter: address(spNFT) });
        emit IERC721.Transfer(alice, address(0), TEST_TOKEN);
        vm.prank(alice);
        spNFT.burn(TEST_TOKEN);
        assertEq(spNFT.balanceOf(alice), balance - 1);
        assertEq(spNFT.totalSupply(), totalSupply - 1);
        assertEq(spNFT.ownerOf(TEST_TOKEN), address(0));
    }

    /// @notice Tests that token burns by non-owners revert.
    function test_ERC721SPNFT_Burn_Reverts_InvalidOwner() public {
        vm.expectRevert(Errors.ERC721__OwnerInvalid.selector);
        spNFT.burn(TEST_TOKEN);
    }

    /// @notice Tests that minting settings can be configured.
    function test_ERC721SPNFT_ConfigureMintSettings() public {
        uint256 startTime = block.timestamp;
        uint256 endTime = block.timestamp + 10000;
        SPG.MintSettings memory mintSettings = SPG.MintSettings({
            start: startTime,
            end: endTime
        });
        vm.prank(owner);
        spNFT.configureMintSettings(spg, mintSettings);
        SPG.MintSettings memory spgMintSettings = IStoryProtocolDrop(spg).getMintSettings(address(spNFT));
        assertEq(spgMintSettings.start, startTime);
        assertEq(spgMintSettings.end, endTime);
    }

    /// @notice Tests that configuring minting settings on the SPG reverts if owner is invalid.
    function test_ERC721SPNFT_ConfigureMintSettings_Reverts_Unauthorized() public {
        uint256 startTime = block.timestamp;
        uint256 endTime = block.timestamp + 10000;
        SPG.MintSettings memory mintSettings = SPG.MintSettings({
            start: startTime,
            end: endTime
        });
        vm.expectRevert();
        spNFT.configureMintSettings(spg, mintSettings);
    }


    /// @notice Tests that setting new minters works.
    function test_ERC721SPNFT_SetMinter() public {
        vm.prank(owner);
        spNFT.setMinter(bob, true);
        MockERC721MetadataProvider.TokenMetadata memory metadata = MockERC721MetadataProvider.TokenMetadata({
            url: MOCK_TOKEN_URI
        });
        vm.prank(bob);
        spNFT.mint(cal, abi.encode(metadata));
    }

    /// @notice Tests that setting new metadata providers works as expected.
    function test_ERC721SPNFT_SetMetadataProvider() public {
        MockERC721MetadataProvider.ContractMetadata memory providerMetadata = MockERC721MetadataProvider.ContractMetadata({
            url: MOCK_CONTRACT_URI,
            x: 0
        });
        MockERC721MetadataProvider providerV2 = new MockERC721MetadataProvider();
        vm.prank(owner);
        spNFT.setMetadataProvider(address(providerV2), abi.encode(providerMetadata));
        assertEq(spNFT.metadataProvider(), address(providerV2));
    }


    /// @dev Mints a token to address `to`.
    function _mintToken(address to, uint256 id) internal virtual override {
        /// @dev Note: Currently test inheritance only supports tests on TEST_TOKEN.
        assertEq(id, spNFT.totalSupply());
        assertEq(id, TEST_TOKEN);
        MockERC721MetadataProvider.TokenMetadata memory metadata = MockERC721MetadataProvider.TokenMetadata({
            url: MOCK_TOKEN_URI
        });
        vm.prank(spg);
        spNFT.mint(to, abi.encode(metadata));
    }

    /// @dev Deploys the SP NFT contract.
    function _deployContract() internal virtual override returns (address) {
        MockERC721MetadataProvider.ContractMetadata memory metadata = MockERC721MetadataProvider.ContractMetadata({
            url: MOCK_CONTRACT_URI,
            x: 0
        });
        provider = new MockERC721MetadataProvider();
        vm.prank(owner);
        spNFT = new ERC721SPNFT(factory);
        spg = address(new MockStoryProtocolDrop());
        vm.prank(factory);
        spNFT.initialize(
            owner,
            spg,
            address(provider),
            abi.encode(metadata),
            _NAME,
            _SYMBOL,
            MAX_SUPPLY
        );
        return address(spNFT);
    }

    /// @dev Gets the expected name for the ERC721 contract.
    function _expectedName() internal virtual pure override returns (string memory) {
        return _NAME;
    }

    /// @dev Gets the expected symbol for the ERC721 contract.
    function _expectedSymbol() internal virtual pure override returns (string memory) {
        return _SYMBOL;
    }

}
