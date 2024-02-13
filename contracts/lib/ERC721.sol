// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

/// @notice Library for ERC721 collection-based operations.
library ERC721 {

    /// @notice ERC-721 configuration settings to pass in to a collection.
    struct CollectionSettings {
        uint48 start;
        uint48 end;
        string name;
        string symbol;
        uint256 maxSupply;
        address metadataProvider;
        bytes metadata;
    }

    /// @notice ERC-721 collection types usable for new IP representation.
    /// TODO: Add other collection types (e.g. ERC721a / SeaDrop / etc.)
    enum CollectionType {
        // The Story Protocol default ERC-721 collection - used when IP creators wish to tokenize 
        // a single IP without the complexity of launching an entire collection an entire collection.
        SP_DEFAULT_COLLECTION
    }
}

