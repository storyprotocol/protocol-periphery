// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Script, stdJson } from "forge-std/Script.sol";

contract StoryProtocolCoreAddressManager is Script {

    using stdJson for string;

    // TODO: Add dynamic loading of the admin address.
    address internal GOVERNANCE_ADMIN = address(0xf398C12A45Bc409b6C652E25bb0a3e702492A4ab);
    address internal GOVERNANCE;
    address internal ipAssetRegistryAddr;
    address internal licensingModuleAddr;
    address internal ipResolverAddr;
    address internal accessControllerAddr;
    address internal pilPolicyFrameworkManagerAddr;
    address internal moduleRegistryAddr;

    function _readStoryProtocolCoreAddresses() internal {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/node_modules/@storyprotocol/contracts/deploy-out/deployment-11155111.json");
        string memory json = vm.readFile(path);
        GOVERNANCE = json.readAddress(".main.Governance");
        ipAssetRegistryAddr = json.readAddress(".main.IPAssetRegistry");
        licensingModuleAddr = json.readAddress(".main.LicensingModule");
        ipResolverAddr = json.readAddress(".main.IPResolver");
        accessControllerAddr = json.readAddress(".main.AccessController");
        pilPolicyFrameworkManagerAddr = json.readAddress(".main.PILPolicyFrameworkManager");
        moduleRegistryAddr = json.readAddress(".main.ModuleRegistry");

    }
}
