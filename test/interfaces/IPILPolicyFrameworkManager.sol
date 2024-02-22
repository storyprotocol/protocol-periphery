// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";

struct PILPolicy {
    bool transferable;
    bool attribution;
    bool commercialUse;
    bool commercialAttribution;
    string[] commercializers;
    uint32 commercialRevShare;
    bool derivativesAllowed;
    bool derivativesAttribution;
    bool derivativesApproval;
    bool derivativesReciprocal;
    uint32 derivativesRevShare;
    string[] territories;
    string[] distributionChannels;
    string[] contentRestrictions;
    address royaltyPolicy;
}

struct PILAggregator {
    bool commercial;
    bool derivatives;
    bool derivativesReciprocal;
    uint256 lastPolicyId;
    bytes32 territoriesAcc;
    bytes32 distributionChannelsAcc;
    bytes32 contentRestrictionsAcc;
}

interface IPILPolicyFrameworkManager is IERC165 {
    struct VerifyLinkResponse {
        bool isLinkingAllowed;
        bool isRoyaltyRequired;
        address royaltyPolicy;
        uint32 royaltyDerivativeRevShare;
    }

    function registerPolicy(PILPolicy calldata pilPolicy) external returns (uint256 policyId);

    function getPolicy(uint256 policyId) external view returns (PILPolicy memory policy);

    function getPolicyId(PILPolicy calldata pilPolicy) external view returns (uint256 policyId);

    function getAggregator(address ipId) external view returns (PILAggregator memory rights);

    function name() external view returns (string memory);

    function licenseTextUrl() external view returns (string memory);

    function licensingModule() external view returns (address);

    function policyToJson(bytes memory policyData) external view returns (string memory);

    function getRoyaltyPolicy(uint256 policyId) external view returns (address royaltyPolicy);

    function getCommercialRevenueShare(uint256 policyId) external view returns (uint32 commercialRevenueShare);

    function isPolicyCommercial(uint256 policyId) external view returns (bool);

    function processInheritedPolicies(
        bytes memory aggregator,
        uint256 policyId,
        bytes memory policy
    ) external view returns (bool changedAgg, bytes memory newAggregator);

    function verifyMint(
        address caller,
        bool policyWasInherited,
        address licensor,
        address receiver,
        uint256 mintAmount,
        bytes memory policyData
    ) external returns (bool);

    function verifyLink(
        uint256 licenseId,
        address caller,
        address ipId,
        address parentIpId,
        bytes calldata policyData
    ) external returns (VerifyLinkResponse memory);
}
