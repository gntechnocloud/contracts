// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Address.sol";
import "./FortuneNXTStorage.sol";

/**
 * @title MagicPoolFacet
 * @dev Facet for Magic Pool Income logic with updated business rules.
 */
contract MagicPoolFacet is FortuneNXTStorage {
    using Address for address payable;

    // Events
    event MagicPoolIncomePaid(
        address indexed recipient,
        uint256 amount,
        uint256 slotNumber
    );
    event AdminFeePaid(uint256 amount);

    // Data Structures

    // Track user closings count per slot
    mapping(address => mapping(uint256 => uint256)) internal userSlotClosings;

    // Track direct referrals list
    mapping(address => address[]) internal directReferralsList;

    // Track user business volume per slot
    mapping(address => mapping(uint256 => uint256))
        internal userSlotBusinessVolume;

    // External Functions

    /**
     * @dev Called when a user closes a slot position to update closings count.
     *      This should be called by the matrix placement or purchase logic when a closing happens.
     * @param _user Address of the user
     * @param _slotNumber Slot number
     */
    function recordClosing(address _user, uint256 _slotNumber) external {
        // Only callable by this contract or authorized facets
        require(
            msg.sender == address(this),
            "MagicPoolFacet: Unauthorized caller"
        );

        userSlotClosings[_user][_slotNumber]++;
    }

    /**
     * @dev Adds a direct referral for a user.
     *      Should be called during user registration.
     * @param _user Address of the user
     * @param _referral Address of the direct referral
     */
    function addDirectReferral(address _user, address _referral) external {
        require(
            msg.sender == address(this),
            "MagicPoolFacet: Unauthorized caller"
        );

        directReferralsList[_user].push(_referral);
    }

    /**
     * @dev Updates user business volume for a slot.
     *      Should be called during slot purchase or relevant transactions.
     * @param _user Address of the user
     * @param _slotNumber Slot number
     * @param _amount Business volume amount to add
     */
    function updateUserSlotBusiness(
        address _user,
        uint256 _slotNumber,
        uint256 _amount
    ) external {
        require(
            msg.sender == address(this),
            "MagicPoolFacet: Unauthorized caller"
        );
        userSlotBusinessVolume[_user][_slotNumber] += _amount;
    }

    /**
     * @dev Distributes Magic Pool Income for a given slot.
     *      Can be called on distribution days (5th, 15th, 25th).
     * @param _slotNumber Slot number
     */
    function distributeMagicPoolIncome(uint256 _slotNumber) external {
        require(_slotNumber >= 1 && _slotNumber <= 12, "Invalid slot number");

        // Check if today is a distribution day
        uint8 today = uint8((block.timestamp / 86400) % 30) + 1; // Day of month (1-30)
        bool isDistributionDay = false;
        for (uint256 i = 0; i < poolDistributionDays.length; i++) {
            if (today == poolDistributionDays[i]) {
                isDistributionDay = true;
                break;
            }
        }
        require(isDistributionDay, "Not a distribution day");

        uint256 poolBalance = poolBalances[_slotNumber];
        require(poolBalance > 0, "No pool balance");

        address[] memory participants = slotParticipants[_slotNumber];
        uint256 eligibleCount = 0;

        // First count eligible users
        for (uint256 i = 0; i < participants.length; i++) {
            address user = participants[i];
            if (_isEligibleForMagicPool(user, _slotNumber)) {
                eligibleCount++;
            }
        }

        require(eligibleCount > 0, "No eligible users");

        uint256 sharePerUser = poolBalance / eligibleCount;

        for (uint256 i = 0; i < participants.length; i++) {
            address user = participants[i];
            if (_isEligibleForMagicPool(user, _slotNumber)) {
                uint256 payout = _calculatePayout(
                    user,
                    _slotNumber,
                    sharePerUser
                );

                if (payout > 0) {
                    // Deduct admin fee
                    uint256 adminFee = (payout * ADMIN_FEE_PERCENT) / 100;
                    uint256 netAmount = payout - adminFee;

                    // Update earnings
                    users[user].poolEarnings += netAmount;
                    users[user].totalEarnings += netAmount;
                    users[user].lastPoolDistribution = block.timestamp;

                    // Transfer funds
                    payable(user).sendValue(netAmount);
                    payable(treasury).sendValue(adminFee);

                    emit MagicPoolIncomePaid(user, netAmount, _slotNumber);
                    emit AdminFeePaid(adminFee);
                }
            }
        }

        // Reset pool balance for the slot
        totalPoolBalance -= poolBalances[_slotNumber];
        poolBalances[_slotNumber] = 0;
    }

    // Internal Functions

    /**
     * @dev Checks if a user is eligible for Magic Pool Income for a slot.
     * @param _user Address of the user
     * @param _slotNumber Slot number
     * @return True if eligible
     */
    function _isEligibleForMagicPool(
        address _user,
        uint256 _slotNumber
    ) internal view returns (bool) {
        uint256 closings = userSlotClosings[_user][_slotNumber];
        uint256 joinedAt = users[_user].joinedAt;
        uint256 directReferrals = directReferralsList[_user].length;

        // First 9 closings: no direct referral required
        if (closings < 9) {
            return true;
        }

        // Next 9 closings (10 to 18): require at least 1 direct referral of same slot or combined referral business after 90 days
        if (closings >= 9 && closings < 18) {
            if (directReferrals >= 1) {
                // Check if direct referral has same slot or combined referral business >= slot price
                if (_hasDirectReferralWithSlot(_user, _slotNumber)) {
                    return true;
                }
                // After 90 days, check combined referral business
                if (block.timestamp >= joinedAt + 90 days) {
                    if (_hasCombinedReferralBusiness(_user, _slotNumber)) {
                        return true;
                    }
                }
            }
            return false;
        }

        // After 18 closings, require 2X referral business from max slot price after 180 days
        if (closings >= 18) {
            if (block.timestamp >= joinedAt + 180 days) {
                if (_hasDoubleReferralBusiness(_user)) {
                    return true;
                }
                return false;
            }
            // Before 180 days, allow if direct referral condition met
            if (directReferrals >= 1) {
                return true;
            }
            return false;
        }

        return false;
    }

    /**
@dev Checks if user has at least one direct referral with the same slot active.
@param _user Address of the user
@param _slotNumber Slot number
@return True if condition met
*/
    function _hasDirectReferralWithSlot(
        address _user,
        uint256 _slotNumber
    ) internal view returns (bool) {
        address[] memory directRefs = directReferralsList[_user];
        for (uint256 i = 0; i < directRefs.length; i++) {
            if (_hasActiveSlot(directRefs[i], _slotNumber)) {
                return true;
            }
        }
        return false;
    }
    /**
@dev Checks if combined referral business of direct referrals >= slot price.
@param _user Address of the user
@param _slotNumber Slot number
@return True if condition met
*/
    function _hasCombinedReferralBusiness(
        address _user,
        uint256 _slotNumber
    ) internal view returns (bool) {
        address[] memory directRefs = directReferralsList[_user];
        uint256 combinedBusiness = 0;
        for (uint256 i = 0; i < directRefs.length; i++) {
            combinedBusiness += userSlotBusinessVolume[directRefs[i]][
                _slotNumber
            ];
        }
        return combinedBusiness >= slots[_slotNumber].price;
    }

    /**
     * @dev Checks if user has 2X referral business from max slot price.
     * @param _user Address of the user
     * @return True if condition met
     */
    function _hasDoubleReferralBusiness(
        address _user
    ) internal view returns (bool) {
        uint256 maxSlot = _getMaxUserSlot(_user);
        uint256 requiredBusiness = slots[maxSlot].price * 2;
        uint256 totalReferralBusiness = 0;

        address[] memory directRefs = directReferralsList[_user];
        for (uint256 i = 0; i < directRefs.length; i++) {
            // Sum total business across all slots for each direct referral
            totalReferralBusiness += _getUserTotalBusiness(directRefs[i]);
        }
        return totalReferralBusiness >= requiredBusiness;
    }

    /**
 * @dev Calculates payout amount considering 
referral slot level limitation.
* @param _user Address of the user
* @param _slotNumber Slot number
* @param _share Proposed share amount
* @return payout Amount to pay
*/
    function _calculatePayout(
        address _user,
        uint256 _slotNumber,
        uint256 _share
    ) internal view returns (uint256) {
        uint256 userMaxSlot = _getMaxUserSlot(_user);
        if (_slotNumber > userMaxSlot) {
            // Limit payout to slot price of user's max slot
            return
                slots[userMaxSlot].price < _share
                    ? slots[userMaxSlot].price
                    : _share;
        }
        return _share;
    }

    /**
     * @dev Helper: Checks if a user has an active slot.
     * @param _user Address of the user
     * @param _slotNumber Slot number
     * @return True if user has the slot
     */
    function _hasActiveSlot(
        address _user,
        uint256 _slotNumber
    ) internal view returns (bool) {
        User storage user = users[_user];
        for (uint256 i = 0; i < user.activeSlots.length; i++) {
            if (user.activeSlots[i] == _slotNumber) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Helper: Gets the max slot number the user has.
     * @param _user Address of the user
     * @return maxSlot Max slot number
     */
    function _getMaxUserSlot(
        address _user
    ) internal view returns (uint256 maxSlot) {
        User storage user = users[_user];
        maxSlot = 0;
        for (uint256 i = 0; i < user.activeSlots.length; i++) {
            if (user.activeSlots[i] > maxSlot) {
                maxSlot = user.activeSlots[i];
            }
        }
    }

    /**
     * @dev Helper: Gets total business volume of a user across all slots.
     * @param _user Address of the user
     * @return totalBusiness Total business volume
     */
    function _getUserTotalBusiness(
        address _user
    ) internal view returns (uint256 totalBusiness) {
        totalBusiness = 0;
        User storage user = users[_user];
        for (uint256 i = 0; i < user.activeSlots.length; i++) {
            uint256 slotNum = user.activeSlots[i];
            totalBusiness += userSlotBusinessVolume[_user][slotNum];
        }
    }
}
