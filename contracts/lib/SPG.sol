// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { Metadata } from "./Metadata.sol";

/// @title SPG Library
/// @notice Library for functionality around the SPG.
library SPG {
    /// @notice Configuration settings for SPG-managed collection mints.
    /// TODO: Add additional configs like mintPrice, fees, recipients, etc.
    /// @notice Mint settings to configure for an SPG-managed collection drop.
    struct MintSettings {
        // Time at which the public mint should start.
        uint48 start;
        // Time at which the mint should end, or 0 if there is no end time.
        uint48 end;
    }

}
