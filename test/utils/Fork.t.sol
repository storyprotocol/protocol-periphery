// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseTest } from "./Base.t.sol";

/// @title Fork Test Contract
contract ForkTest is BaseTest {

    // List of fork identifiers.
    uint256 sepoliaFork;

    // List of chain RPC URLs.
    string SEPOLIA_RPC_URL = vm.envString("SEPOLIA_RPC_URL");

    /// @notice Sets up the base test contract.
    function setUp() public virtual override(BaseTest) {
        sepoliaFork = vm.createFork(SEPOLIA_RPC_URL);
        vm.selectFork(sepoliaFork);
        BaseTest.setUp();
    }
}

