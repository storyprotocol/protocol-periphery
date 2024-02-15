// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { BaseTest } from "test/utils/Base.t.sol";

/// @title Transer Helper Contract
/// @notice Utility contract for creating ERC721 transfer test simulations.
abstract contract TransferHelper is BaseTest {

    // Arbitrary safe transfer data used for safe transfer tests.
    bytes private SAFE_TRANSFER_DATA = "mockERC721SafeTransferFromData";

    /// @notice The ERC721 contract SUT.
    IERC721 public erc721;

    /// @notice Default test token id to use.
    uint256 public TEST_TOKEN = 0;

    // Used for identifying transfer types for test reuse.
    enum TransferType { TRANSFER_FROM, SAFE_TRANSFER_FROM }

    // Encapsulates all details of an ERC721 transfer.
    struct Transfer {
        TransferType transferType; // Type of the transfer
        address sender;            // Transfer sender
        address from;              // Original token owner
        address to;                // Token recipient
        uint256 id;                // The id of the NFT being transferred.
        bytes data;                // Additional data to send with the transfer.
    }

    // Internal helper 
    Transfer internal _t;      // The current transfer being examined.
    Transfer[] internal _ts;   // The current list of transfers being examined.

    /// @notice Modifier for running multiple transfer simulations for a test.
    modifier runAll(Transfer[] memory transfers) {
        for (uint256 i = 0; i < transfers.length; i++) {
            uint256 snapshot = vm.snapshot();
            _t = transfers[i];
            _;
            vm.revertTo(snapshot);
        }
    }

    /// @notice Initializes the base ERC721 contract for testing.
    function setUp() public virtual override(BaseTest) {
        BaseTest.setUp();
        erc721 = IERC721(_deployContract());
    }

    /// @notice Creates a mixed set of ERC721 transfers where the sender is not the token owner.
    function sut_Transfers_TransferFrom_Operator() internal returns (Transfer[] memory) {
        delete _ts;
        _ts.push(_buildSafeTransferFrom(cal, alice, bob, TEST_TOKEN, ""));
        _ts.push(_buildTransferFrom(bob, alice, alice, TEST_TOKEN));
        _ts.push(_buildSafeTransferFrom(cal, alice, cal, TEST_TOKEN, SAFE_TRANSFER_DATA));
        _ts.push(_buildTransferFrom(bob, alice, alice, TEST_TOKEN));
        return _ts;
    }


    /// @notice Creates a mixed set of ERC721 transfers.
    function sut_Transfers_TransferFrom() internal returns (Transfer[] memory) {
        delete _ts;
        _ts.push(_buildSafeTransferFrom(alice, alice, bob, TEST_TOKEN, ""));
        _ts.push(_buildTransferFrom(alice, alice, alice, TEST_TOKEN));
        _ts.push(_buildSafeTransferFrom(alice, alice, bob, TEST_TOKEN, SAFE_TRANSFER_DATA));
        _ts.push(_buildTransferFrom(alice, alice, alice, TEST_TOKEN));
        return _ts;
    }

    /// @notice Creates a set of ERC721 `transferFrom` transfers.
    function sut_Transfers_SafeTransferFrom() internal returns (Transfer[] memory) {
        delete _ts;
        _ts.push(_buildSafeTransferFrom(alice, alice, bob, TEST_TOKEN, SAFE_TRANSFER_DATA));
        _ts.push(_buildSafeTransferFrom(alice, alice, bob, TEST_TOKEN, ""));
        return _ts;
    }

    /// @dev Returns a built Transfer struct for a `transferFrom` call.
    function _buildTransferFrom(
        address sender,
        address from,
        address to,
        uint256 id
    ) internal pure returns (Transfer memory) {
        return Transfer({
            transferType: TransferType.TRANSFER_FROM,
            sender: sender,
            from: from,
            to: to,
            id: id,
            data: ""
        });
    }

    /// @dev Returns a built Transfer struct for a `safeTransferFrom` call.
    function _buildSafeTransferFrom(
        address sender,
        address from,
        address to,
        uint256 id,
        bytes memory data
    ) internal pure returns (Transfer memory) {
        return Transfer({
            transferType: TransferType.SAFE_TRANSFER_FROM,
            sender: sender,
            from: from,
            to: to,
            id: id,
            data: data
        });
    }

    /// @dev Performs a transfer, while ensuring balances and events are as expected.
    function _transferAndAssert() internal {
        uint256 fromBal = erc721.balanceOf(_t.from);
        uint256 toBal = erc721.balanceOf(_t.to);
        vm.expectEmit({ emitter: address(erc721) });
        emit IERC721.Transfer(_t.from, _t.to, _t.id);
        _transfer();
        if (_t.from == _t.to) {
            assertEq(erc721.balanceOf(_t.from), fromBal);
        } else {
            assertEq(erc721.balanceOf(_t.from), fromBal - 1);
            assertEq(erc721.balanceOf(_t.to), toBal + 1);
        }
    }

    /// @dev Performs a transfer based on the active transfer test object.
    function _transfer() internal {
        vm.prank(_t.sender);
        if (_t.transferType == TransferType.TRANSFER_FROM) {
            erc721.transferFrom(_t.from, _t.to, _t.id);
        } else {
            if (_t.data.length == 0) {
                erc721.safeTransferFrom(_t.from, _t.to, _t.id);
            } else {
                erc721.safeTransferFrom(_t.from, _t.to, _t.id, _t.data);
            }
        }
    }

    /// @dev Mints NFT `id` to address `to`.
    function _mintToken(address to, uint256 id) internal virtual;

    /// @dev Deploy a new ERC721 NFT contract.
    function _deployContract() internal virtual returns (address);
}
