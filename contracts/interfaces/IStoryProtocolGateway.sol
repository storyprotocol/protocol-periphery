// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IModule } from "@story-protocol/protocol-core/contracts/interfaces/modules/base/IModule.sol";

import { IStoryProtocolDrop } from "./IStoryProtocolDrop.sol";
import { Metadata } from "../lib/Metadata.sol";
import { SPG } from "../lib/SPG.sol";

/// @title Story Protocol Gateway Interface
/// @notice Interface for the Story Protocol Gateway, used as the de facto entrypoint
///         for IP interactions in Story Protocol, particularly registrations.
interface IStoryProtocolGateway is IStoryProtocolDrop, IModule {
    /// @notice Registers an existing NFT as into the protocol as an IP Asset.
    /// @param policyId The policy that will identify the licensing terms of the IP.
    /// @param tokenContract The address of the contract of the NFT being registered.
    /// @param tokenId The id of the NFT being registered.
    /// @param ipMetadata Metadata related to IP attribution.
    /// @param signature The signature set permission to SPG.
    /// @return The address identifier of the newly registered IP asset.
    function registerIpWithSig(
        uint256 policyId,
        address tokenContract,
        uint256 tokenId,
        Metadata.IPMetadata calldata ipMetadata,
        SPG.Signature calldata signature
    ) external returns (address);

    /// @notice Mints a Story Protocol NFT and registers it into the protocol as an IP asset.
    /// @param policyId The policy that will identify the licensing terms of the IP.
    /// @param tokenContract The address of the NFT being minted.
    /// @param tokenMetadata Token metadata in bytes to include for NFT minting.
    /// @param ipMetadata Metadata related to IP attribution.
    /// @param signature The signature set permission to SPG.
    function mintAndRegisterIpWithSig(
        uint256 policyId,
        address tokenContract,
        bytes calldata tokenMetadata,
        Metadata.IPMetadata calldata ipMetadata,
        SPG.Signature calldata signature
    ) external returns (uint256 tokenId, address ipId);

    /// @notice Registers an existing NFT into the protocol as an IP asset derivative.
    /// @param licenseIds The licenses to incorporate for the new IP.
    /// @param royaltyContext The bytes-encoded context for royalty policy to process.
    /// @param tokenContract The address of the contract of the NFT being registered.
    /// @param tokenId The id of the NFT being registered.
    /// @param ipMetadata Metadata related to IP attribution.
    /// @param signature The signature set permission to SPG.
    function registerDerivativeIpWithSig(
        uint256[] calldata licenseIds,
        bytes calldata royaltyContext,
        address tokenContract,
        uint256 tokenId,
        Metadata.IPMetadata calldata ipMetadata,
        SPG.Signature calldata signature
    ) external returns (address);

    /// @notice Registers an existing NFT into the protocol as an IP asset derivative.
    /// @param licenseIds The licenses to incorporate for the new IP.
    /// @param royaltyContext The bytes-encoded context for royalty policy to process.
    /// @param tokenContract The address of the NFT being minted.
    /// @param tokenMetadata Token metadata in bytes to include for NFT minting.
    /// @param ipMetadata Metadata related to IP attribution.
    /// @param signature The signature set permission to SPG.
    /// @return tokenId The id of the newly minted NFT.
    /// @return ipId The address identifier of the newly registered IP asset.
    function mintAndRegisterDerivativeIpWithSig(
        uint256[] calldata licenseIds,
        bytes calldata royaltyContext,
        address tokenContract,
        bytes calldata tokenMetadata,
        Metadata.IPMetadata calldata ipMetadata,
        SPG.Signature calldata signature
    ) external returns (uint256 tokenId, address ipId);
}
