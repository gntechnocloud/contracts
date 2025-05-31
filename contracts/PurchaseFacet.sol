// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.20;

import "./FortuneNXTStorage.sol";

/**
 * @title PurchaseFacet
 * @dev Facet for slot purchase logic in the Diamond pattern.
 */
contract PurchaseFacet is FortuneNXTStorage {
    event SlotPurchased(address indexed user, uint256 slotNumber, uint256 price);

    /**
     * @dev Purchases a slot for the user.
     * @param _slotNumber Slot number to purchase (1-12)
     */
    function purchaseSlot(uint256 _slotNumber) external payable {
        require(users[msg.sender].isActive, "User not registered");
        require(_slotNumber >= 1 && _slotNumber <= 12, "Invalid slot number");
        require(slots[_slotNumber].active, "Slot not active");

        User storage user = users[msg.sender];

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

        for (uint256 i = 0; i < user.activeSlots.length; i++) {
            require(user.activeSlots[i] != _slotNumber, "Slot already purchased");
        }

        uint256 slotPrice = slots[_slotNumber].price;
        uint256 totalPrice = slotPrice + (slotPrice * POOL_EXTRA_PERCENT / 100);

        require(msg.value >= totalPrice, "Insufficient payment");

        user.activeSlots.push(_slotNumber);

        Matrix storage matrix = user.matrices[_slotNumber];
        matrix.owner = msg.sender;
        matrix.createdAt = block.timestamp;

        slotParticipants[_slotNumber].push(msg.sender);

        uint256 poolAmount = slotPrice * POOL_EXTRA_PERCENT / 100;
        poolBalances[_slotNumber] += poolAmount;
        totalPoolBalance += poolAmount;

        emit SlotPurchased(msg.sender, _slotNumber, slotPrice);

        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }
    }
}