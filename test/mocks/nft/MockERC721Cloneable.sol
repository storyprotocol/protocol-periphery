// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { ERC721Cloneable } from "contracts/nft/ERC721Cloneable.sol";

/// @title Mock ERC721 Cloneable
contract MockERC721Cloneable is ERC721Cloneable {

    /// @notice Initializes the mock ERC721 cloneable contract.
    function initialize(
        string memory tokenName,
        string memory tokenSymbol
    ) public initializer {
        __ERC721Cloneable_init(tokenName, tokenSymbol);
    }

    /// @notice Mints a token to address `to`.
    function mint(address to, uint256 id) external returns (uint256) {
        _mint(to, id);
        return id;
    }

    /// @notice Burns a token.
    function burn(uint256 id) external {
        _burn(id);
    }

    /// @notice Returns the token URI configured for the ERC721.
    function tokenURI(uint256) external pure returns (string memory) {
        return "";
    }
}

