// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { MockERC721Receiver } from "test/mocks/nft/MockERC721Receiver.sol";
import { BaseTest } from "test/utils/Base.t.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { TransferHelper } from "./TransferHelper.sol";
import { Errors } from "contracts/lib/Errors.sol";

/// @title ERC721 Base Test Contract
/// @notice Base contract for testing standard ERC721 functionality.
abstract contract ERC721BaseTest is TransferHelper {

    // Expected return value by contract recipients for ERC-721 safe transfers.
    bytes4 constant ERC721_RECEIVER_MAGIC_VALUE = bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));

    /// @notice The ERC721 token contract SUT.
    IERC721Metadata public token;

    /// @notice Initializes the base ERC721 contract for testing.
    function setUp() public virtual override(TransferHelper) {
        TransferHelper.setUp();
        token = IERC721Metadata(address(erc721));
    }

    /// @notice Tests the default ERC721 initialization settings are applied.
    function test_ERC721_Initialize() public {
        assertEq(token.name(), _expectedName());
        assertEq(token.symbol(), _expectedSymbol());
    }

    /// @notice Tests that standard approvals work as intended.
    function test_ERC721_Approve() public {
        _mintToken(alice, TEST_TOKEN);
        vm.expectEmit({ emitter: address(erc721) });
        emit IERC721.Approval(alice, bob, TEST_TOKEN);
        vm.prank(alice);
        erc721.approve(bob, TEST_TOKEN);
        assertEq(erc721.getApproved(TEST_TOKEN), bob);
    }

    /// @notice Tests that approvals by non-owners revert.
    function test_ERC721_Approve_Reverts_Unauthorized() public {
        _mintToken(alice, TEST_TOKEN);
        vm.expectRevert(Errors.ERC721__SenderUnauthorized.selector);
        erc721.approve(bob, TEST_TOKEN);
    }

    /// @notice Tests that operator approvals work as intended.
    function test_ERC721_SetApprovalForAll() public {
        _mintToken(alice, TEST_TOKEN);
        vm.expectEmit({ emitter: address(erc721) });
        emit IERC721.ApprovalForAll(alice, bob, true);
        vm.prank(alice);
        erc721.setApprovalForAll(bob, true);
        assertTrue(erc721.isApprovedForAll(alice, bob));
    }

    /// @notice Tests that normal ERC721 transfers made by owners work.
    function test_ERC721_Transfer() public runAll(sut_Transfers_TransferFrom()) {
        _mintToken(_t.from, _t.id);
        _transferAndAssert();
    }

    /// @notice Tests that approved ERC721 transfers work.
    function test_ERC721_Transfer_Approved() public runAll(sut_Transfers_TransferFrom_Operator()) {
        _mintToken(_t.from, _t.id);
        vm.prank(_t.from);
        erc721.approve(_t.sender, _t.id);
        _transferAndAssert();
    }

    /// @notice Tests that operator-approved ERC721 transfers work.
    function test_ERC721_Transfer_Operator() public runAll(sut_Transfers_TransferFrom_Operator()) {
        _mintToken(_t.from, _t.id);
        vm.prank(_t.from);
        erc721.setApprovalForAll(_t.sender, true);
        _transferAndAssert();
    }

    /// @notice Tests that transfers to the zero address reverts.
    function test_ERC721_Transfer_Reverts_ZeroAddress() public runAll(sut_Transfers_TransferFrom()) {
        _mintToken(_t.from, _t.id);
        _t.to = address(0);
        vm.expectRevert(Errors.ERC721__ReceiverInvalid.selector);
        _transfer();
    }

    /// @notice Tests that transfers made by non-owners revert.
    function test_ERC721_Transfer_Reverts_OwnerInvalid() public runAll(sut_Transfers_TransferFrom()) {
        vm.expectRevert(Errors.ERC721__OwnerInvalid.selector);
        _transfer();
    }

    /// @notice Tests that transfers made by unauthorized senders revert.
    function test_ERC721_Transfer_Reverts_SenderUnauthorized() public runAll(sut_Transfers_TransferFrom_Operator()) {
        _mintToken(_t.from, _t.id);
        vm.expectRevert(Errors.ERC721__SenderUnauthorized.selector);
        _transfer();
    }

    /// @notice Tests that safe transfers to contract receivers works.
    function test_ERC721_SafeTransfer() public runAll(sut_Transfers_SafeTransferFrom()) {
        _mintToken(_t.from, _t.id);
        _t.to = address(new MockERC721Receiver(IERC721Receiver.onERC721Received.selector, false));
        vm.expectEmit({ emitter: _t.to });
        emit MockERC721Receiver.ERC721Received(_t.sender, _t.from, _t.id, _t.data);
        _transfer();
    }

    /// @notice Tests that safe transfers revert when receivers use invalid magic values.
    function test_ERC721_SafeTransfer_Reverts_InvalidMagicValue() public runAll(sut_Transfers_SafeTransferFrom()) {
        _mintToken(_t.from, _t.id);
        _t.to = address(new MockERC721Receiver(0xDEADBEEF, false));
        vm.expectRevert(Errors.ERC721__SafeTransferUnsupported.selector);
        _transfer();
    }

    /// @notice Tests that safe transfers revert when receivers themselves revert.
    function test_ERC721_SafeTransfer_Reverts_ThrowingReceiver() public runAll(sut_Transfers_SafeTransferFrom()) {
        _mintToken(_t.from, _t.id);
        _t.to = address(new MockERC721Receiver(IERC721Receiver.onERC721Received.selector, true));
        vm.expectRevert(Errors.ERC721__SafeTransferUnsupported.selector);
        _transfer();
    }

    /// @notice Tests that the erc721 supports the required interfaces.
    function test_ERC721SupportsInterface() public {
        assertTrue(erc721.supportsInterface(0x01ffc9a7)); // ERC-165
        assertTrue(erc721.supportsInterface(0x80ac58cd)); // ERC-721
    }

    /// @dev Gets the expected name for the ERC721 contract.
    function _expectedName() internal virtual pure returns (string memory);

    /// @dev Gets the expected symbol for the ERC721 contract.
    function _expectedSymbol() internal virtual pure returns (string memory);

}
