// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IModule } from "@storyprotocol/contracts/interfaces/modules/base/IModule.sol";

import { IStoryProtocolDrop } from "./IStoryProtocolDrop.sol";
import { Metadata } from "../lib/Metadata.sol";

/// @title Story Protocol Gateway Interface
/// @notice Interface for the Story Protocol Gateway, used as the de facto entrypoint
///         for IP interactions in Story Protocol, particularly registrations.
interface IStoryProtocolGateway is IStoryProtocolDrop, IModule {

    /// @notice Registers an existing NFT as into the protocol as an IP Asset.
    /// @param policyId The policy that will identify the licensing terms of the IP.
    /// @param tokenContract The address of the contract of the NFT being registered.
    /// @param tokenId The id of the NFT being registered.
    /// @param ipMetadata Metadata related to IP attribution.
    /// @return The address identifier of the newly registered IP asset.
    function registerIp(
        uint256 policyId,
        address tokenContract,
        uint256 tokenId,
        Metadata.IPMetadata calldata ipMetadata
    ) external returns (address);

    /// @notice Mints a Story Protocol NFT and registers it into the protocol as an IP asset.
    /// @param policyId The policy that will identify the licensing terms of the IP.
    /// @param tokenContract The address of the NFT being minted.
    /// @param tokenMetadata Token metadata in bytes to include for NFT minting.
    /// @param ipMetadata Metadata related to IP attribution.
    function mintAndRegisterIp(
        uint256 policyId,
        address tokenContract,
        bytes calldata tokenMetadata,
        Metadata.IPMetadata calldata ipMetadata
    ) external returns (uint256 tokenId, address ipId);

    /// @notice Registers an existing NFT into the protocol as an IP asset derivative.
    /// @param licenseIds The licenses to incorporate for the new IP.
    /// @param minRoyalty The minimum royalty % to be collected by the IP asset.
    /// @param tokenContract The address of the contract of the NFT being registered.
    /// @param tokenId The id of the NFT being registered.
    /// @param ipMetadata Metadata related to IP attribution.
    function registerDerivativeIp(
        uint256[] calldata licenseIds,
        uint32 minRoyalty,
        address tokenContract,
        uint256 tokenId,
        Metadata.IPMetadata calldata ipMetadata
    ) external returns (address);

    /// @notice Registers an existing NFT into the protocol as an IP asset derivative.
    /// @param licenseIds The licenses to incorporate for the new IP.
    /// @param minRoyalty The minimum royalty % to be collected by the IP asset.
    /// @param tokenContract The address of the NFT being minted.
    /// @param tokenMetadata Token metadata in bytes to include for NFT minting.
    /// @param ipMetadata Metadata related to IP attribution.
    /// @return tokenId The id of the newly minted NFT.
    /// @return ipId The address identifier of the newly registered IP asset.
    function mintAndRegisterDerivativeIp(
        uint256[] calldata licenseIds,
        uint32 minRoyalty,
        address tokenContract,
        bytes calldata tokenMetadata,
        Metadata.IPMetadata calldata ipMetadata
    ) external returns (uint256 tokenId, address ipId);

}
