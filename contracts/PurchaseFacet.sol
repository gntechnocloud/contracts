// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./FortuneNXTStorage.sol";

import "./IPriceFeed.sol";

/**
 * @title PurchaseFacet
 * @dev Facet for slot purchase logic in the Diamond pattern with dynamic pricing.
 */
contract PurchaseFacet is FortuneNXTStorage {
    event SlotPurchased(
        address indexed user,
        uint256 slotNumber,
        uint256 price
    );

    /**
     * @dev Purchases a slot for the user.
     * @param _slotNumber Slot number to purchase (1-12)
     */
    function purchaseSlot(uint256 _slotNumber) external payable {
        require(users[msg.sender].isActive, "User not registered");
        require(_slotNumber >= 1 && _slotNumber <= 12, "Invalid slot number");
        require(slots[_slotNumber].active, "Slot not active");

        User storage user = users[msg.sender];

        // Enforce sequential slot purchase
        if (_slotNumber > 1) {
            bool hasPreviousSlot = false;
            for (uint256 i = 0; i < user.activeSlots.length; i++) {
                if (user.activeSlots[i] == _slotNumber - 1) {
                    hasPreviousSlot = true;
                    break;
                }
            }
            require(hasPreviousSlot, "Must purchase previous slot first");
        }

        // Check if slot already purchased
        for (uint256 i = 0; i < user.activeSlots.length; i++) {
            require(
                user.activeSlots[i] != _slotNumber,
                "Slot already purchased"
            );
        }

        // Get current Core Coin price from price feed
        uint256 coreCoinPrice = priceFeed.getLatestPrice();
        require(coreCoinPrice > 0, "Invalid Core Coin price");

        // Calculate slot price in Core Coin units
        // Assuming slots[_slotNumber].price is in USD with 18 decimals
        // Adjust calculation if your price units differ
        uint256 slotPriceUSD = slots[_slotNumber].price;
        uint256 slotPriceCoreCoin = (slotPriceUSD * 1e18) / coreCoinPrice;

        // Add pool extra percent
        uint256 totalPrice = slotPriceCoreCoin +
            ((slotPriceCoreCoin * POOL_EXTRA_PERCENT) / 100);

        require(msg.value >= totalPrice, "Insufficient payment");

        // Update user active slots
        user.activeSlots.push(_slotNumber);

        // Update matrix ownership
        Matrix storage matrix = user.matrices[_slotNumber];
        matrix.owner = msg.sender;
        matrix.createdAt = block.timestamp;

        // Add user to slot participants
        slotParticipants[_slotNumber].push(msg.sender);

        // Update pool balances
        uint256 poolAmount = (slotPriceCoreCoin * POOL_EXTRA_PERCENT) / 100;
        poolBalances[_slotNumber] += poolAmount;
        totalPoolBalance += poolAmount;

        emit SlotPurchased(msg.sender, _slotNumber, slotPriceCoreCoin);

        // Refund excess payment
        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }
    }
}
