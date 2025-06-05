// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.20;

import "./FortuneNXTStorage.sol";

/**
 * @title PoolIncomeFacet
 * @dev Facet for pool income distribution logic in the Diamond pattern.
 */
contract PoolIncomeFacet is FortuneNXTStorage {
    event PoolIncomePaid(address indexed recipient, uint256 amount, uint256 slotNumber);

    /**
     * @dev Distributes pool income to eligible users.
     * Can be called by anyone on the 5th, 15th, or 25th of the month.
     */
    function distributePoolIncome() external {
        uint8 today = uint8((block.timestamp / 86400) % 30) + 1;
        bool isDistributionDay = false;
        for (uint256 i = 0; i < poolDistributionDays.length; i++) {
            if (today == poolDistributionDays[i]) {
                isDistributionDay = true;
                break;
            }
        }
        require(isDistributionDay, "Not a distribution day");
        require(block.timestamp >= lastPoolDistributionTime + 1 days, "Already distributed today");

        lastPoolDistributionTime = block.timestamp;

        for (uint256 slotNumber = 1; slotNumber <= 12; slotNumber++) {
            if (poolBalances[slotNumber] > 0 && slotParticipants[slotNumber].length > 0) {
                _distributeSlotPoolIncome(slotNumber);
            }
        }
    }

    /**
     * @dev Distributes pool income for a specific slot.
     * @param _slotNumber Slot number
     */
    function _distributeSlotPoolIncome(uint256 _slotNumber) internal {
        uint256 poolBalance = poolBalances[_slotNumber];
        address[] memory eligibleUsers = _getEligiblePoolUsers(_slotNumber);

        if (eligibleUsers.length == 0) {
            _redistributePoolBalance(_slotNumber);
            return;
        }

        uint256 sharePerUser = poolBalance / eligibleUsers.length;

        for (uint256 i = 0; i < eligibleUsers.length; i++) {
            address user = eligibleUsers[i];

            if (_isWithinPayoutCap(user, _slotNumber)) {
                uint256 adminFee = sharePerUser * ADMIN_FEE_PERCENT / 100;
                uint256 netAmount = sharePerUser - adminFee;

                users[user].poolEarnings += netAmount;
                users[user].totalEarnings += netAmount;
                users[user].lastPoolDistribution = block.timestamp;

                payable(user).transfer(netAmount);
                payable(treasury).transfer(adminFee);

                emit PoolIncomePaid(user, netAmount, _slotNumber);
            }
        }

        totalPoolBalance -= poolBalances[_slotNumber];
        poolBalances[_slotNumber] = 0;
    }

    /**
     * @dev Gets eligible users for pool income distribution.
     * @param _slotNumber Slot number
     * @return eligibleUsers Array of eligible user addresses
     */
    function _getEligiblePoolUsers(uint256 _slotNumber) internal view returns (address[] memory) {
        address[] memory participants = slotParticipants[_slotNumber];
        uint256 eligibleCount = 0;

        for (uint256 i = 0; i < participants.length; i++) {
            address user = participants[i];
            bool isEligible = block.timestamp < users[user].joinedAt + 90 days ||
                             users[user].directReferrals >= 3;

            if (isEligible && _isWithinPayoutCap(user, _slotNumber)) {
                eligibleCount++;
            }
        }

        address[] memory eligibleUsers = new address[](eligibleCount);
        uint256 index = 0;

        for (uint256 i = 0; i < participants.length; i++) {
            address user = participants[i];
            bool isEligible = block.timestamp < users[user].joinedAt + 90 days ||
                             users[user].directReferrals >= 3;

            if (isEligible && _isWithinPayoutCap(user, _slotNumber)) {
                eligibleUsers[index] = user;
                index++;
            }
        }

        return eligibleUsers;
    }

    /**
     * @dev Checks if a user is within the payout cap.
     * @param _user Address of the user
     * @param _slotNumber Slot number
     * @return isWithinCap True if user is within payout cap
     */
    function _isWithinPayoutCap(address _user, uint256 _slotNumber) internal view returns (bool) {
        Matrix storage matrix = users[_user].matrices[_slotNumber];

        if (block.timestamp > matrix.createdAt + 90 days) {
            return false;
        }

        uint256 slotValue = slots[_slotNumber].price;
        uint256 maxEarnings = slotValue * 200 / 100;

        return matrix.earnings < maxEarnings;
    }

    /**
     * @dev Redistributes pool balance from a slot with no eligible users.
     * @param _slotNumber Slot number
     */
    function _redistributePoolBalance(uint256 _slotNumber) internal {
        uint256 poolBalance = poolBalances[_slotNumber];
        uint256 totalOtherPoolBalance = 0;
        uint256[] memory eligibleSlots = new uint256[](11);
        uint256 eligibleSlotCount = 0;

        for (uint256 i = 1; i <= 12; i++) {
            if (i != _slotNumber && slotParticipants[i].length > 0) {
                address[] memory eligibleUsers = _getEligiblePoolUsers(i);
                if (eligibleUsers.length > 0) {
                    eligibleSlots[eligibleSlotCount] = i;
                    eligibleSlotCount++;
                    totalOtherPoolBalance += poolBalances[i];
                }
            }
        }

        if (eligibleSlotCount > 0) {
            for (uint256 i = 0; i < eligibleSlotCount; i++) {
                uint256 slotNum = eligibleSlots[i];
                uint256 share = poolBalance * poolBalances[slotNum] / totalOtherPoolBalance;
                poolBalances[slotNum] += share;
            }
        }

        totalPoolBalance -= poolBalances[_slotNumber];
        poolBalances[_slotNumber] = 0;
    }
}