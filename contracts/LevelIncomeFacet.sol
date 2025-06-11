// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.20;

import "./FortuneNXTStorage.sol";

/**
 * @title LevelIncomeFacet
 * @dev Facet for level income distribution logic in the Diamond pattern.
 */
contract LevelIncomeFacet is FortuneNXTStorage {
    event LevelIncomePaid(address indexed recipient, address indexed from, uint256 amount, uint256 slotNumber, uint256 level);

    /**
     * @dev Processes level income for a user up to 50 levels.
     * @param _user Address of the user
     * @param _slotNumber Slot number
     */
    function processLevelIncome(address _user, uint256 _slotNumber) external {
        uint256 levelIncomeTotal = slots[_slotNumber].price * LEVEL_INCOME_PERCENT / 100;
        address current = users[_user].referrer;

        for (uint256 level = 1; level <= 50 && current != address(0); level++) {
            if (users[current].directReferrals >= levelRequirements[level].directRequired) {
                uint256 levelIncomeAmount = levelIncomeTotal * levelRequirements[level].percent / 100;
                uint256 adminFee = levelIncomeAmount * ADMIN_FEE_PERCENT / 100;
                uint256 netAmount = levelIncomeAmount - adminFee;

                users[current].levelEarnings += netAmount;
                users[current].totalEarnings += netAmount;

                payable(current).transfer(netAmount);
                payable(treasury).transfer(adminFee);

                emit LevelIncomePaid(current, _user, netAmount, _slotNumber, level);
            }
            

            current = users[current].referrer;
        }
    }
}