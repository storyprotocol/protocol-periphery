// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

/// @title  Metadata Library
/// @notice Library for ERC-721 JSON compliant token metadata.
library Metadata {
    /// @notice Attributes related to contract-wide metadata.
    struct ContractData {
        string description;
        string image;
        string uri;
    }

    /// @notice Describes a custom string key-value pair attribute.
    struct Attribute {
        string key;
        string value;
    }

    /// @notice Attributes related to IP metadata.
    struct IPMetadata {
        string name;
        bytes32 hash;
        string url;
        Attribute[] customMetadata;
    }

    /// @notice Attributes related to token-specific ERC-721 metadata.
    struct TokenMetadata {
        string name;
        string description;
        string externalUrl;
        string image;
        Attribute[] attributes;
    }
}
