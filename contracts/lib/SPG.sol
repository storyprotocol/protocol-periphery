// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

/// @notice Library for SPG collection management.
library SPG {
    /// @notice SPG ERC-721 configuration settings to pass in to a collection.
    struct CollectionSettings {
        string name;
        string symbol;
        uint256 maxSupply;
        bytes contractMetadata;
    }

    /// @notice SPG ERC-721 collection types usable for new IP representation.
    /// TODO: Add other collection types (e.g. ERC721a / SeaDrop / etc.)
    enum CollectionType {
        // The Story Protocol default ERC-721 collection - used when IP creators wish to tokenize
        // a single IP without the complexity of launching an entire collection an entire collection.
        SP_DEFAULT_COLLECTION,
        RFU // Reserved for future use - used only for testing.
    }

    /// @notice Mint settings to configure for an SPG-managed collection drop.
    /// TODO: Add additional configs like mintPrice, fees, recipients, etc.
    /// TODO: Peform gas optimizations at a later time - this is not tightly packed.
    struct MintSettings {
        // Time at which the public mint should start.
        uint256 start;
        // Time at which the mint should end, or 0 if there is no end time.
        uint256 end;
    }

    /// @notice Signature of ERC712.
    struct Signature {
        address signer;
        uint256 deadline;
        // abi.encodePacked(r, s, v)
        bytes signature;
    }
}
