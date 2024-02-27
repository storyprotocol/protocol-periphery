// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IPAssetRegistry } from "@storyprotocol/contracts/registries/IPAssetRegistry.sol";

import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";


import { StoryProtocolGateway } from "contracts/StoryProtocolGateway.sol";
import { StoryProtocolCoreAddressManager } from "./utils/StoryProtocolCoreAddressManager.sol";
import { StringUtil } from "./utils/StringUtil.sol";
import { BroadcastManager } from "./utils/BroadcastManager.s.sol";
import { JsonDeploymentHandler } from "./utils/JsonDeploymentHandler.s.sol";

contract Main is Script, StoryProtocolCoreAddressManager, BroadcastManager, JsonDeploymentHandler {

    using StringUtil for uint256;

    StoryProtocolGateway public spg;

    constructor() JsonDeploymentHandler("main") {}

    /// @dev To use, run the following command (e.g. for Sepolia):
    /// forge script script/Main.s.sol:Main --rpc-url $RPC_URL --broadcast --verify -vvvv
    function run() public {
        _readStoryProtocolCoreAddresses();
        _beginBroadcast();
        _deployProtocolContracts(deployer);
        _writeDeployment();
        _endBroadcast();
    }

    function _deployProtocolContracts(address accessControlDeployer) private {
        string memory contractKey;

        contractKey = "SPG";
        _predeploy(contractKey);
        spg = new StoryProtocolGateway(
            accessControllerAddr,
            ipAssetRegistryAddr,
            licensingModuleAddr,
            pilPolicyFrameworkManagerAddr,
            ipResolverAddr
        );
        _postdeploy(contractKey, address(spg));

        contractKey = "SPNFTImpl";
        _predeploy(contractKey);
        _postdeploy(contractKey, address(spg.SP_NFT_IMPL()));

        contractKey = "MetadataProviderImpl";
        _predeploy(contractKey);
        _postdeploy(contractKey, address(spg.METADATA_PROVIDER_IMPL()));
    }

    function _predeploy(string memory contractKey) private view {
        console2.log(string.concat("Deploying ", contractKey, "..."));
    }

    function _postdeploy(string memory contractKey, address newAddress) private {
        _writeAddress(contractKey, newAddress);
        console2.log(string.concat(contractKey, " deployed to:"), newAddress);
    }

}

