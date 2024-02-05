// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ERC721BaseTest } from "./ERC721Base.t.sol";
import { MockERC721Cloneable } from "test/mocks/nft/MockERC721Cloneable.sol";
import { Errors } from "contracts/lib/Errors.sol";

/// @title ERC721 Cloneable Test Contract
contract ERC721CloneableTest is ERC721BaseTest {

    string internal constant _NAME = "MOCK_NAME";
    string internal constant _SYMBOL = "MOCK_SYMBOL";
    MockERC721Cloneable public cloneable;

    /// @notice Initializes the ERC721 Cloneable testing contract.
    function setUp() public virtual override(ERC721BaseTest) {
        ERC721BaseTest.setUp();
        cloneable = MockERC721Cloneable(address(token));
    }

    /// @notice Tests that token mints work as intended.
    function test_ERC721Cloneable_Mint() public {
        uint256 totalSupply = cloneable.totalSupply();
        uint256 balance = cloneable.balanceOf(alice);
        vm.expectEmit({ emitter: address(cloneable) });
        emit IERC721.Transfer(address(0), alice, TEST_TOKEN);
        _mintToken(alice, TEST_TOKEN);
        assertEq(cloneable.balanceOf(alice), balance + 1);
        assertEq(cloneable.totalSupply(), totalSupply + 1);
        assertEq(cloneable.ownerOf(TEST_TOKEN), alice);
    }

    /// @notice Tests that duplicate mints revert.
    function test_ERC721Cloneable_Mint_Reverts_DuplicateMint() public {
        _mintToken(alice, TEST_TOKEN);
        vm.expectRevert(Errors.ERC721__TokenAlreadyMinted.selector);
        _mintToken(alice, TEST_TOKEN);
    }

    /// @notice Tests that token mints to the zero address revert.
    function test_ERC721Cloneable_Mint_Reverts_ZeroAddress() public {
        vm.expectRevert(Errors.ERC721__ReceiverInvalid.selector);
        _mintToken(address(0), TEST_TOKEN);
    }

    /// @notice Tests that token burns work as intended.
    function test_ERC721Cloneable_Burn() public {
        _mintToken(alice, TEST_TOKEN);
        uint256 totalSupply = cloneable.totalSupply();
        uint256 balance = cloneable.balanceOf(alice);
        vm.expectEmit({ emitter: address(cloneable) });
        emit IERC721.Transfer(alice, address(0), TEST_TOKEN);
        vm.prank(alice);
        cloneable.burn(TEST_TOKEN);
        assertEq(cloneable.balanceOf(alice), balance - 1);
        assertEq(cloneable.totalSupply(), totalSupply - 1);
        assertEq(cloneable.ownerOf(TEST_TOKEN), address(0));
    }

    /// @notice Tests that token burns to non-existent tokens revert.
    function test_ERC721Cloneable_Burn_Reverts_NonExistentToken() public {
        vm.expectRevert(Errors.ERC721__TokenNonExistent.selector);
        cloneable.burn(TEST_TOKEN);
    }

    /// @notice Tests that burning already burned tokens revert.
    function test_ERC721Cloneable_Burn_Reverts_DuplicateBurn() public {
        _mintToken(alice, TEST_TOKEN);
        vm.prank(alice);
        cloneable.burn(TEST_TOKEN);
        vm.expectRevert(Errors.ERC721__TokenNonExistent.selector);
        cloneable.burn(TEST_TOKEN);
    }

    /// @dev Deploys the ERC721 cloneable contract.
    function _deployContract() internal virtual override returns (address) {
        MockERC721Cloneable mock = new MockERC721Cloneable();
        mock.initialize(_NAME, _SYMBOL);
        return address(mock);
    }

    /// @dev Mints a token to address `to`.
    function _mintToken(address to, uint256 id) internal virtual override {
        MockERC721Cloneable(address(token)).mint(to, id);
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
