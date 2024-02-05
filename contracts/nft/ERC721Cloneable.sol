// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { Errors } from "contracts/lib/Errors.sol";

/// @title Minimal ERC-721 Cloneable Contract
/// @notice Minimal cloneable ERC-721 contract supporting the metadata extension.
abstract contract ERC721Cloneable is IERC721Metadata, Initializable {
    /// @notice ERC-721 collection-wide token name.
    string public name;

    /// @notice ERC-721 collection-wide token symbol.
    string public symbol;

    /// @notice Maps tokens to their owner addresses.
    mapping(uint256 => address) public ownerOf;

    /// @notice Checks for an owner if an address is an authorized operator.
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /// @notice Gets the approved address for an NFT.
    mapping(uint256 => address) public getApproved;

    /// @notice Gets the number of NFTs owned by an address.
    mapping(address => uint256) public balanceOf;

    /// @notice Tracks the total number of ERC-721 NFTs in circulation.
    uint256 public totalSupply;

    // EIP-165 identifiers for all supported interfaces.
    bytes4 private constant _ERC165_INTERFACE_ID = 0x01ffc9a7;
    bytes4 private constant _ERC721_INTERFACE_ID = 0x80ac58cd;

    /// @dev Initializes a new ERC721 Cloneable NFT.
    /// @param tokenName The name to set for the NFT collection.
    /// @param tokenSymbol The symbol to set for the NFT collection.
    function __ERC721Cloneable_init(string memory tokenName, string memory tokenSymbol) internal onlyInitializing {
        name = tokenName;
        symbol = tokenSymbol;
    }

    /// @notice Sets the operator for `msg.sender` to `operator`.
    /// @param operator The operator address managing NFTs of `msg.sender`.
    /// @param approved Whether operator can manage NFTs of `msg.sender`.
    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /// @notice Sets approved address of NFT `id` to address `approved`.
    /// @param approved The new approved address for the NFT.
    /// @param tokenId The id of the NFT to approve.
    function approve(address approved, uint256 tokenId) public virtual {
        address owner = ownerOf[tokenId];

        // Revert unless msg.sender is the owner or approved operator.
        if (msg.sender != owner && !isApprovedForAll[owner][msg.sender]) {
            revert Errors.ERC721__SenderUnauthorized();
        }

        getApproved[tokenId] = approved;
        emit Approval(owner, approved, tokenId);
    }

    /// @notice Transfers NFT of id `id` from address `from` to address `to`,
    ///  with safety checks ensuring `to` is capable of receiving the NFT.
    /// @dev Safety checks are only performed if `to` is a smart contract.
    /// @param from The existing owner address of the NFT to be transferred.
    /// @param to The new owner address of the NFT being transferred.
    /// @param data Additional data in bytes to pass to the receiver.
    /// @param tokenId The id of the NFT being transferred.
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) external {
        transferFrom(from, to, tokenId);
        if (
            to.code.length != 0 &&
            IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) !=
            IERC721Receiver.onERC721Received.selector
        ) {
            revert Errors.ERC721__SafeTransferUnsupported();
        }
    }

    /// @notice Transfers NFT of id `id` from address `from` to address `to`,
    ///  with safety checks ensuring `to` is capable of receiving the NFT.
    /// @dev Safety checks are only performed if `to` is a smart contract.
    /// @param from The existing owner address of the NFT to be transferred.
    /// @param to The new owner address of the NFT being transferred.
    /// @param tokenId The id of the NFT being transferred.
    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        transferFrom(from, to, tokenId);
        if (
            to.code.length != 0 &&
            IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, "") !=
            IERC721Receiver.onERC721Received.selector
        ) {
            revert Errors.ERC721__SafeTransferUnsupported();
        }
    }

    /// @notice Transfers NFT of id `id` from address `from` to address `to`,
    ///  without performing any safety checks.
    /// @dev Existence of an NFT is inferred by having a non-zero owner address.
    ///  Transfers clear owner approvals without `Approval` events emitted.
    /// @param from The existing owner address of the NFT being transferred.
    /// @param to The new owner address of the NFT being transferred.
    /// @param tokenId The id of the NFT being transferred.
    function transferFrom(address from, address to, uint256 tokenId) public virtual {
        if (from != ownerOf[tokenId]) {
            revert Errors.ERC721__OwnerInvalid();
        }

        if (msg.sender != from && msg.sender != getApproved[tokenId] && !isApprovedForAll[from][msg.sender]) {
            revert Errors.ERC721__SenderUnauthorized();
        }

        if (to == address(0)) {
            revert Errors.ERC721__ReceiverInvalid();
        }

        delete getApproved[tokenId];

        unchecked {
            balanceOf[from]--;
            balanceOf[to]++;
        }

        ownerOf[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    /// @notice Checks if interface of identifier `id` is supported.
    /// @param id The ERC-165 interface identifier.
    /// @return True if interface id `id` is supported, false otherwise.
    function supportsInterface(bytes4 id) public view virtual override(IERC165) returns (bool) {
        return id == _ERC165_INTERFACE_ID || id == _ERC721_INTERFACE_ID;
    }

    /// @dev Mints an NFT of identifier `tokenId` to recipient address `to`.
    /// @param to Address of the new NFT owner.
    /// @param tokenId Id of the NFT being minted.
    function _mint(address to, uint256 tokenId) internal virtual {
        if (to == address(0)) {
            revert Errors.ERC721__ReceiverInvalid();
        }

        if (ownerOf[tokenId] != address(0)) {
            revert Errors.ERC721__TokenAlreadyMinted();
        }

        unchecked {
            totalSupply++;
            balanceOf[to]++;
        }

        ownerOf[tokenId] = to;
        emit Transfer(address(0), to, tokenId);
    }

    /// @dev Burns an NFT with identifier `tokenId`.
    /// @param tokenId The id of the NFT being burned.
    function _burn(uint256 tokenId) internal virtual {
        address owner = ownerOf[tokenId];

        if (owner == address(0)) {
            revert Errors.ERC721__TokenNonExistent();
        }

        unchecked {
            totalSupply--;
            balanceOf[owner]--;
        }

        delete ownerOf[tokenId];
        delete getApproved[tokenId];
        emit Transfer(owner, address(0), tokenId);
    }
}
