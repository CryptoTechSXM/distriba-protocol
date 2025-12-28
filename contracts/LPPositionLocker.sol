// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @notice Minimal ERC721 receiver interface.
 * Uniswap v3 Position Manager mints LP positions as NFTs and uses safeTransferFrom.
 */
contract LPPositionLocker {
    /// @notice Uniswap v3 NonfungiblePositionManager on the chain (Arbitrum).
    address public immutable positionManager;

    mapping(uint256 => bool) public isLocked;

    event PositionLocked(uint256 indexed tokenId);

    constructor(address positionManager_) {
        require(positionManager_ != address(0), "pm=0");
        positionManager = positionManager_;
    }

    /**
     * @notice Accept Uniswap v3 position NFTs and permanently lock them.
     * Anyone transferring an LP NFT here is effectively burning withdrawal rights.
     *
     * IMPORTANT:
     * - There is NO withdraw function.
     * - This contract is intentionally dumb and irreversible.
     */
    function onERC721Received(
        address, /* operator */
        address, /* from */
        uint256 tokenId,
        bytes calldata /* data */
    ) external returns (bytes4) {
        // Optional safety: only accept from the Uniswap position manager
        require(msg.sender == positionManager, "not pm");

        isLocked[tokenId] = true;
        emit PositionLocked(tokenId);

        return this.onERC721Received.selector;
    }
}
