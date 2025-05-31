// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.20;

import "./FortuneNXTStorage.sol";

/**
 * @title MatrixFacet
 * @dev Facet for matrix-related logic in the Diamond pattern.
 */
contract MatrixFacet is FortuneNXTStorage {
    event MatrixIncomePaid(address indexed recipient, address indexed from, uint256 amount, uint256 slotNumber, uint256 level);
    event Rebirth(address indexed user, uint256 oldSlotNumber, uint256 newSlotNumber);

    /**
     * @dev Places a user in the matrix and processes matrix income.
     * @param _user Address of the user
     * @param _slotNumber Slot number
     */
    function processMatrixPlacement(address _user, uint256 _slotNumber) external {
        // Find a matrix to place the user in
        address upline = _findMatrixUpline(_user, _slotNumber);

        if (upline != address(0)) {
            Matrix storage uplineMatrix = users[upline].matrices[_slotNumber];

            // Place in level 1 if there's space
            if (uplineMatrix.level1.length < 2) {
                uplineMatrix.level1.push(_user);

                // Pay matrix income to upline (25% of slot value)
                uint256 matrixIncome = slots[_slotNumber].price * MATRIX_INCOME_PERCENT / 100 * 25 / 100;
                _payMatrixIncome(upline, _user, matrixIncome, _slotNumber, 1);
            }
            // Place in level 2 if there's space
            else if (uplineMatrix.level2.length < 4) {
                uplineMatrix.level2.push(_user);

                // Pay matrix income to upline (50% of slot value)
                uint256 matrixIncome = slots[_slotNumber].price * MATRIX_INCOME_PERCENT / 100 * 50 / 100;

                // Check if this is position 4 or 6 (last two positions in level 2)
                if (uplineMatrix.level2.length == 3 || uplineMatrix.level2.length == 4) {
                    // Trigger rebirth instead of payment
                    _processRebirth(upline, _slotNumber, matrixIncome);
                } else {
                    // Regular payment for positions 3 and 5
                    _payMatrixIncome(upline, _user, matrixIncome, _slotNumber, 2);
                }

                // Check if matrix is now complete
                if (uplineMatrix.level2.length == 4) {
                    uplineMatrix.completed = true;
                }
            }
        }
    }

    // Internal helper functions (copied from implementation for modularity)
    function _findMatrixUpline(address _user, uint256 _slotNumber) internal view returns (address upline) {
        address referrer = users[_user].referrer;
        if (referrer != address(0) && _hasActiveSlot(referrer, _slotNumber)) {
            Matrix storage referrerMatrix = users[referrer].matrices[_slotNumber];
            if (!referrerMatrix.completed) {
                return referrer;
            }
        }
        for (uint256 i = 0; i < slotParticipants[_slotNumber].length; i++) {
            address participant = slotParticipants[_slotNumber][i];
            Matrix storage participantMatrix = users[participant].matrices[_slotNumber];
            if (!participantMatrix.completed) {
                return participant;
            }
        }
        return owner;
    }

    function _hasActiveSlot(address _user, uint256 _slotNumber) internal view returns (bool) {
        User storage user = users[_user];
        for (uint256 i = 0; i < user.activeSlots.length; i++) {
            if (user.activeSlots[i] == _slotNumber) {
                return true;
            }
        }
        return false;
    }

    function _payMatrixIncome(
        address _recipient,
        address _from,
        uint256 _amount,
        uint256 _slotNumber,
        uint256 _level
    ) internal {
        uint256 adminFee = _amount * ADMIN_FEE_PERCENT / 100;
        uint256 netAmount = _amount - adminFee;
        users[_recipient].matrixEarnings += netAmount;
        users[_recipient].totalEarnings += netAmount;
        users[_recipient].matrices[_slotNumber].earnings += netAmount;
        payable(_recipient).transfer(netAmount);
        payable(treasury).transfer(adminFee);
        emit MatrixIncomePaid(_recipient, _from, netAmount, _slotNumber, _level);
    }

    function _processRebirth(address _user, uint256 _slotNumber, uint256 _amount) internal {
        uint256 nextSlotNumber = _slotNumber + 1;
        if (nextSlotNumber <= 12 && !_hasActiveSlot(_user, nextSlotNumber)) {
            users[_user].activeSlots.push(nextSlotNumber);
            Matrix storage matrix = users[_user].matrices[nextSlotNumber];
            matrix.owner = _user;
            matrix.createdAt = block.timestamp;
            slotParticipants[nextSlotNumber].push(_user);
            emit Rebirth(_user, _slotNumber, nextSlotNumber);
        } else {
            _payMatrixIncome(_user, address(0), _amount, _slotNumber, 2);
        }
    }
}