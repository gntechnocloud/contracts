// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./FortuneNXTStorage.sol";

/**
 * @title FortuneNXTImplementation
 * @dev Main implementation contract for Fortunity NXT.np
 * Contains core business logic for the MLM system.
 */
contract FortuneNXTImplementation is 
    Initializable, 
    AccessControlUpgradeable, 
    PausableUpgradeable, 
    ReentrancyGuardUpgradeable,
    FortuneNXTStorage 
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    
    // Events
    event UserRegistered(address indexed user, address indexed referrer);
    event SlotPurchased(address indexed user, uint256 slotNumber, uint256 price);
    event MatrixIncomePaid(address indexed recipient, address indexed from, uint256 amount, uint256 slotNumber, uint256 level);
    event LevelIncomePaid(address indexed recipient, address indexed from, uint256 amount, uint256 slotNumber, uint256 level);
    event PoolIncomePaid(address indexed recipient, uint256 amount, uint256 slotNumber);
    event Rebirth(address indexed user, uint256 oldSlotNumber, uint256 newSlotNumber);
    event AdminFeePaid(uint256 amount);
    
    /**
     * @dev Initializes the contract with initial slot prices and pool distribution.
     * @param _owner Address of the contract owner
     * @param _treasury Address where admin fees will be sent
     * @param _slotPrices Array of prices for each slot (1-12)
     * @param _poolDistribution Array of pool distribution percentages for each slot (1-12)
     */
    function initialize(
        address _owner,
        address _treasury,
        uint256[] memory _slotPrices,
        uint256[] memory _poolDistribution
    ) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        
        require(_slotPrices.length == 12, "Must provide 12 slot prices");
        require(_poolDistribution.length == 12, "Must provide 12 pool distributions");
        
        // Setup roles
        grantRole(DEFAULT_ADMIN_ROLE, _owner);
        grantRole(ADMIN_ROLE, _owner);
        grantRole(OPERATOR_ROLE, _owner);
        
        owner = _owner;
        treasury = _treasury;
        version = 1;
        
        // Initialize slots
        for (uint256 i = 0; i < 12; i++) {
            uint256 slotNumber = i + 1;
            slots[slotNumber] = Slot({
                price: _slotPrices[i],
                poolPercent: _poolDistribution[i],
                active: true
            });
        }
        
        // Initialize level requirements
        // Level 1: 1 Direct, 24%
        levelRequirements[1] = LevelRequirement({directRequired: 1, percent: 24});
        // Level 2: 2 Direct, 10%
        levelRequirements[2] = LevelRequirement({directRequired: 2, percent: 10});
        // Level 3: 3 Direct, 8%
        levelRequirements[3] = LevelRequirement({directRequired: 3, percent: 8});
        // Level 4-5: 5 Direct, 6%
        for (uint256 i = 4; i <= 5; i++) {
            levelRequirements[i] = LevelRequirement({directRequired: 5, percent: 6});
        }
        // Level 6-7: 7 Direct, 4%
        for (uint256 i = 6; i <= 7; i++) {
            levelRequirements[i] = LevelRequirement({directRequired: 7, percent: 4});
        }
        // Level 8-10: 10 Direct, 3%
        for (uint256 i = 8; i <= 10; i++) {
            levelRequirements[i] = LevelRequirement({directRequired: 10, percent: 3});
        }
        // Level 11-15: 10 Direct, 2%
        for (uint256 i = 11; i <= 15; i++) {
            levelRequirements[i] = LevelRequirement({directRequired: 10, percent: 2});
        }
        // Level 16-25: 15 Direct, 0.8%
        for (uint256 i = 16; i <= 25; i++) {
            levelRequirements[i] = LevelRequirement({directRequired: 15, percent: 0.8 * 100});
        }
        // Level 26-40: 15 Direct, 0.6%
        for (uint256 i = 26; i <= 40; i++) {
            levelRequirements[i] = LevelRequirement({directRequired: 15, percent: 0.6 * 100});
        }
        // Level 41-50: 15 Direct, 0.2%
        for (uint256 i = 41; i <= 50; i++) {
            levelRequirements[i] = LevelRequirement({directRequired: 15, percent: 0.2 * 100});
        }
    }
    
    /**
     * @dev Reinitializes the contract for a new version.
     * @param _version New version number
     */
    function reinitialize(uint8 _version) public reinitializer(_version) {
        version = _version;
        // Add any new initialization logic for the upgrade
    }
    
    /**
     * @dev Registers a new user with a referrer.
     * @param _referrer Address of the referrer
     */
    function register(address _referrer) external whenNotPaused {
        require(!users[msg.sender].isActive, "User already registered");
        require(_referrer != msg.sender, "Cannot refer yourself");
        require(users[_referrer].isActive || _referrer == owner, "Referrer not active");
        
        User storage user = users[msg.sender];
        user.referrer = _referrer;
        user.isActive = true;
        user.joinedAt = block.timestamp;
        
        // Increment referrer's direct count
        users[_referrer].directReferrals++;
        
        totalUsers++;
        
        emit UserRegistered(msg.sender, _referrer);
    }
    
    /**
     * @dev Purchases a slot for the user.
     * @param _slotNumber Slot number to purchase (1-12)
     */
    function purchaseSlot(uint256 _slotNumber) external payable whenNotPaused nonReentrant {
        require(users[msg.sender].isActive, "User not registered");
        require(_slotNumber >= 1 && _slotNumber <= 12, "Invalid slot number");
        require(slots[_slotNumber].active, "Slot not active");
        
        User storage user = users[msg.sender];
        
        // Check if user has purchased all previous slots
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
        
        // Check if user already has this slot
        for (uint256 i = 0; i < user.activeSlots.length; i++) {
            require(user.activeSlots[i] != _slotNumber, "Slot already purchased");
        }
        
        uint256 slotPrice = slots[_slotNumber].price;
        uint256 totalPrice = slotPrice + (slotPrice * POOL_EXTRA_PERCENT / 100);
        
        require(msg.value >= totalPrice, "Insufficient payment");
        
        // Add slot to user's active slots
        user.activeSlots.push(_slotNumber);
        
        // Create new matrix for this slot
        Matrix storage matrix = user.matrices[_slotNumber];
        matrix.owner = msg.sender;
        matrix.createdAt = block.timestamp;
        
        // Add user to slot participants
        slotParticipants[_slotNumber].push(msg.sender);
        
        // Add to pool balance
        uint256 poolAmount = slotPrice * POOL_EXTRA_PERCENT / 100;
        poolBalances[_slotNumber] += poolAmount;
        totalPoolBalance += poolAmount;
        
        // Process matrix placement and payouts
        _processMatrixPlacement(msg.sender, _slotNumber);
        
        // Update total volume
        totalVolume += slotPrice;
        
        // Refund excess payment
        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }
        
        emit SlotPurchased(msg.sender, _slotNumber, slotPrice);
    }
    
    /**
     * @dev Processes matrix placement for a user.
     * @param _user Address of the user
     * @param _slotNumber Slot number
     */
    function _processMatrixPlacement(address _user, uint256 _slotNumber) internal {
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
        
        // Process level income
        _processLevelIncome(_user, _slotNumber);
    }
    
    /**
     * @dev Finds an upline for matrix placement.
     * @param _user Address of the user
     * @param _slotNumber Slot number
     * @return upline Address of the upline
     */
    function _findMatrixUpline(address _user, uint256 _slotNumber) internal view returns (address upline) {
        // First try to place under referrer
        address referrer = users[_user].referrer;
        
        if (referrer != address(0) && _hasActiveSlot(referrer, _slotNumber)) {
            Matrix storage referrerMatrix = users[referrer].matrices[_slotNumber];
            
            // Check if referrer's matrix has space
            if (!referrerMatrix.completed) {
                return referrer;
            }
        }
        
        // If referrer's matrix is full or referrer doesn't have this slot,
        // find another matrix with space using breadth-first search
        for (uint256 i = 0; i < slotParticipants[_slotNumber].length; i++) {
            address participant = slotParticipants[_slotNumber][i];
            Matrix storage participantMatrix = users[participant].matrices[_slotNumber];
            
            if (!participantMatrix.completed) {
                return participant;
            }
        }
        
        // If no matrix with space is found, place under owner (root)
        return owner;
    }
    
    /**
     * @dev Checks if a user has an active slot.
     * @param _user Address of the user
     * @param _slotNumber Slot number
     * @return hasSlot True if user has the slot
     */
    function _hasActiveSlot(address _user, uint256 _slotNumber) internal view returns (bool) {
        User storage user = users[_user];
        
        for (uint256 i = 0; i < user.activeSlots.length; i++) {
            if (user.activeSlots[i] == _slotNumber) {
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * @dev Pays matrix income to a user.
     * @param _recipient Address of the recipient
     * @param _from Address of the user who triggered the payment
     * @param _amount Amount to pay
     * @param _slotNumber Slot number
     * @param _level Matrix level (1 or 2)
     */
    function _payMatrixIncome(
        address _recipient, 
        address _from, 
        uint256 _amount, 
        uint256 _slotNumber, 
        uint256 _level
    ) internal {
        // Deduct admin fee
        uint256 adminFee = _amount * ADMIN_FEE_PERCENT / 100;
        uint256 netAmount = _amount - adminFee;
        
        // Update user earnings
        users[_recipient].matrixEarnings += netAmount;
        users[_recipient].totalEarnings += netAmount;
        users[_recipient].matrices[_slotNumber].earnings += netAmount;
        
        // Transfer funds
        payable(_recipient).transfer(netAmount);
        payable(treasury).transfer(adminFee);
        
        emit MatrixIncomePaid(_recipient, _from, netAmount, _slotNumber, _level);
        emit AdminFeePaid(adminFee);
    }
    
    /**
     * @dev Processes rebirth for a user.
     * @param _user Address of the user
     * @param _slotNumber Current slot number
     * @param _amount Amount to use for rebirth
     */
    function _processRebirth(address _user, uint256 _slotNumber, uint256 _amount) internal {
        // Determine next slot number
        uint256 nextSlotNumber = _slotNumber + 1;
        
        // Check if next slot exists and user doesn't already have it
        if (nextSlotNumber <= 12 && !_hasActiveSlot(_user, nextSlotNumber)) {
            // Add next slot to user's active slots
            users[_user].activeSlots.push(nextSlotNumber);
            
            // Create new matrix for next slot
            Matrix storage matrix = users[_user].matrices[nextSlotNumber];
            matrix.owner = _user;
            matrix.createdAt = block.timestamp;
            
            // Add user to slot participants
            slotParticipants[nextSlotNumber].push(_user);
            
            // Process matrix placement for the new slot
            _processMatrixPlacement(_user, nextSlotNumber);
            
            emit Rebirth(_user, _slotNumber, nextSlotNumber);
        } else {
            // If rebirth is not possible, pay as regular matrix income
            _payMatrixIncome(_user, address(0), _amount, _slotNumber, 2);
        }
    }
    
    /**
     * @dev Processes level income for a user.
     * @param _user Address of the user
     * @param _slotNumber Slot number
     */
    function _processLevelIncome(address _user, uint256 _slotNumber) internal {
        uint256 levelIncomeTotal = slots[_slotNumber].price * LEVEL_INCOME_PERCENT / 100;
        address current = users[_user].referrer;
        
        // Distribute level income up to 50 levels
        for (uint256 level = 1; level <= 50 && current != address(0); level++) {
            // Check if upline has enough direct referrals to qualify
            if (users[current].directReferrals >= levelRequirements[level].directRequired) {
                // Calculate level income amount
                uint256 levelIncomeAmount = levelIncomeTotal * levelRequirements[level].percent / 100;
                
                // Deduct admin fee
                uint256 adminFee = levelIncomeAmount * ADMIN_FEE_PERCENT / 100;
                uint256 netAmount = levelIncomeAmount - adminFee;
                
                // Update user earnings
                users[current].levelEarnings += netAmount;
                users[current].totalEarnings += netAmount;
                
                // Transfer funds
                payable(current).transfer(netAmount);
                payable(treasury).transfer(adminFee);
                
                emit LevelIncomePaid(current, _user, netAmount, _slotNumber, level);
                emit AdminFeePaid(adminFee);
            }
            
            // Move to next upline
            current = users[current].referrer;
        }
    }
    
    /**
     * @dev Distributes pool income to eligible users.
     * Can be called by anyone on the 5th, 15th, or 25th of the month.
     */
    function distributePoolIncome() external whenNotPaused nonReentrant {
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
        require(block.timestamp >= lastPoolDistributionTime + 1 days, "Already distributed today");
        
        lastPoolDistributionTime = block.timestamp;
        
        // Distribute pool income for each slot
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
            // If no eligible users, redistribute to other slots
            _redistributePoolBalance(_slotNumber);
            return;
        }
        
        uint256 sharePerUser = poolBalance / eligibleUsers.length;
        
        for (uint256 i = 0; i < eligibleUsers.length; i++) {
            address user = eligibleUsers[i];
            
            // Check if user has reached max payout cap
            if (_isWithinPayoutCap(user, _slotNumber)) {
                // Deduct admin fee
                uint256 adminFee = sharePerUser * ADMIN_FEE_PERCENT / 100;
                uint256 netAmount = sharePerUser - adminFee;
                
                // Update user earnings
                users[user].poolEarnings += netAmount;
                users[user].totalEarnings += netAmount;
                users[user].lastPoolDistribution = block.timestamp;
                
                // Transfer funds
                payable(user).transfer(netAmount);
                payable(treasury).transfer(adminFee);
                
                emit PoolIncomePaid(user, netAmount, _slotNumber);
                emit AdminFeePaid(adminFee);
            }
        }
        
        // Reset pool balance
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
        
        // First count eligible users
        for (uint256 i = 0; i < participants.length; i++) {
            address user = participants[i];
            
            // For first 3 months, all active users are eligible
            // After 3 months, only users with ≥3 direct sponsors qualify
            bool isEligible = block.timestamp < users[user].joinedAt + 90 days || 
                             users[user].directReferrals >= 3;
            
            if (isEligible && _isWithinPayoutCap(user, _slotNumber)) {
                eligibleCount++;
            }
        }
        
        // Create array of eligible users
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
        
        // Check time cap (3 months)
        if (block.timestamp > matrix.createdAt + MAX_PAYOUT_TIME) {
            return false;
        }
        
        // Check earnings cap (200% of slot value)
        uint256 slotValue = slots[_slotNumber].price;
        uint256 maxEarnings = slotValue * MAX_PAYOUT_PERCENT / 100;
        
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
        
        // Find eligible slots with users
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
        
        // Redistribute proportionally
        if (eligibleSlotCount > 0) {
            for (uint256 i = 0; i < eligibleSlotCount; i++) {
                uint256 slotNum = eligibleSlots[i];
                uint256 share = poolBalance * poolBalances[slotNum] / totalOtherPoolBalance;
                poolBalances[slotNum] += share;
            }
        }
        
        // Reset original pool balance
        totalPoolBalance -= poolBalances[_slotNumber];
        poolBalances[_slotNumber] = 0;
    }
    
    /**
     * @dev Pauses the contract.
     * Can only be called by an admin.
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @dev Unpauses the contract.
     * Can only be called by an admin.
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @dev Updates the treasury address.
     * @param _newTreasury New treasury address
     */
    function setTreasury(address _newTreasury) external onlyRole(ADMIN_ROLE) {
        require(_newTreasury != address(0), "Invalid treasury address");
        treasury = _newTreasury;
    }
    
    /**
     * @dev Updates a slot's price and pool percentage.
     * @param _slotNumber Slot number
     * @param _price New price
     * @param _poolPercent New pool percentage
     */
    function updateSlot(uint256 _slotNumber, uint256 _price, uint256 _poolPercent) external onlyRole(ADMIN_ROLE) {
        require(_slotNumber >= 1 && _slotNumber <= 12, "Invalid slot number");
        
        slots[_slotNumber].price = _price;
        slots[_slotNumber].poolPercent = _poolPercent;
    }
    
    /**
     * @dev Activates or deactivates a slot.
     * @param _slotNumber Slot number
     * @param _active Active status
     */
    function setSlotActive(uint256 _slotNumber, bool _active) external onlyRole(ADMIN_ROLE) {
        require(_slotNumber >= 1 && _slotNumber <= 12, "Invalid slot number");
        
        slots[_slotNumber].active = _active;
    }
    
    /**
     * @dev Updates pool distribution days.
     * @param _days Array of days (1-30)
     */
    function setPoolDistributionDays(uint8[3] memory _days) external onlyRole(ADMIN_ROLE) {
        for (uint256 i = 0; i < 3; i++) {
            require(_days[i] >= 1 && _days[i] <= 30, "Invalid day");
        }
        
        poolDistributionDays = _days;
    }
    
    /**
     * @dev Updates a level requirement.
     * @param _level Level number
     * @param _directRequired Number of direct referrals required
     * @param _percent Percentage of level income
     */
    function updateLevelRequirement(uint256 _level, uint256 _directRequired, uint256 _percent) external onlyRole(ADMIN_ROLE) {
        require(_level >= 1 && _level <= 50, "Invalid level");
        
        levelRequirements[_level].directRequired = _directRequired;
        levelRequirements[_level].percent = _percent;
    }
    
    /**
     * @dev Migrates data during an upgrade.
     * @param _data Migration data
     */
    function migrateData(bytes calldata _data) external onlyRole(ADMIN_ROLE) {
        // Implementation depends on the specific migration needs
        // This is a placeholder for future upgrades
    }
    
    /**
     * @dev Emergency withdrawal of stuck funds.
     * Can only be called by the owner.
     * @param _amount Amount to withdraw
     */
    function emergencyWithdraw(uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_amount <= address(this).balance, "Insufficient balance");
        
        payable(owner).transfer(_amount);
    }
    
    /**
     * @dev Fallback function to receive ETH.
     */
    receive() external payable {}
}