// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import "./FortuneNXTStorage.sol";

/**
 * @title AdminFacet
 * @dev Facet for administrative functions in the Diamond pattern.
 */
contract AdminFacet is FortuneNXTStorage, AccessControlEnumerable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    event AdminFeePaid(uint256 amount);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event SlotUpdated(uint256 indexed slotNumber, uint256 price, uint256 poolPercent);
    event SlotActiveStatusChanged(uint256 indexed slotNumber, bool active);
    event PoolDistributionDaysUpdated(uint8[3] distributionDays);
    event LevelRequirementUpdated(uint256 indexed level, uint256 directRequired, uint256 percent);

    /**
    * @dev Initializes the admin facet with admin roles
    * @param admin Address to grant admin privileges
    */
    function initializeAdminFacet(address admin) external {
        require(admin != address(0), "Invalid admin address");
        
        // Check if this is the initial setup (no DEFAULT_ADMIN_ROLE exists)
        bool isInitialSetup = getRoleMemberCount(DEFAULT_ADMIN_ROLE) == 0;
        
        if (isInitialSetup) {
            // For initial setup, directly set the roles using internal functions
            _grantRole(DEFAULT_ADMIN_ROLE, admin);
            _grantRole(ADMIN_ROLE, admin);
        } else {
            // For subsequent calls, require existing admin privileges
            require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller must have DEFAULT_ADMIN_ROLE");
            require(!hasRole(DEFAULT_ADMIN_ROLE, admin), "Admin already has DEFAULT_ADMIN_ROLE");
            
            grantRole(DEFAULT_ADMIN_ROLE, admin);
            grantRole(ADMIN_ROLE, admin);
        }
    }

    /**
    * @dev Updates the treasury address.
    * @param _newTreasury New treasury address
    */
    function setTreasury(address _newTreasury) external onlyRole(ADMIN_ROLE) {
        require(_newTreasury != address(0), "Invalid treasury address");
        address oldTreasury = treasury;
        treasury = _newTreasury;
        emit TreasuryUpdated(oldTreasury, _newTreasury);
    }

    /**
    * @dev Updates a slot's price and pool percentage.
    * @param _slotNumber Slot number
    * @param _price New price
    * @param _poolPercent New pool percentage
    */
    function updateSlot(uint256 _slotNumber, uint256 _price, uint256 _poolPercent) external onlyRole(ADMIN_ROLE) {
        require(_slotNumber >= 1 && _slotNumber <= 12, "Invalid slot number");
        require(_price > 0, "Price must be greater than 0");
        require(_poolPercent <= 100, "Pool percent cannot exceed 100");

        slots[_slotNumber].price = _price;
        slots[_slotNumber].poolPercent = _poolPercent;
        
        emit SlotUpdated(_slotNumber, _price, _poolPercent);
    }

    /**
    * @dev Activates or deactivates a slot.
    * @param _slotNumber Slot number
    * @param _active Active status
    */
    function setSlotActive(uint256 _slotNumber, bool _active) external onlyRole(ADMIN_ROLE) {
        require(_slotNumber >= 1 && _slotNumber <= 12, "Invalid slot number");

        slots[_slotNumber].active = _active;
        
        emit SlotActiveStatusChanged(_slotNumber, _active);
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
        
        emit PoolDistributionDaysUpdated(_days);
    }

    /**
    * @dev Updates a level requirement.
    * @param _level Level number
    * @param _directRequired Number of direct referrals required
    * @param _percent Percentage of level income
    */
    function updateLevelRequirement(uint256 _level, uint256 _directRequired, uint256 _percent) external onlyRole(ADMIN_ROLE) {
        require(_level >= 1 && _level <= 50, "Invalid level");
        require(_directRequired > 0, "Direct required must be greater than 0");
        require(_percent > 0, "Percent must be greater than 0");

        levelRequirements[_level].directRequired = _directRequired;
        levelRequirements[_level].percent = _percent;
        
        emit LevelRequirementUpdated(_level, _directRequired, _percent);
    }

    /**
    * @dev Grants admin role to a new address
    * @param _newAdmin Address to grant admin role
    */
    function grantAdminRole(address _newAdmin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_newAdmin != address(0), "Invalid admin address");
        grantRole(ADMIN_ROLE, _newAdmin);
    }

    /**
    * @dev Revokes admin role from an address
    * @param _admin Address to revoke admin role from
    */
    function revokeAdminRole(address _admin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_admin != address(0), "Invalid admin address");
        _revokeRole(ADMIN_ROLE, _admin);
    }

    /**
    * @dev Gets the treasury address
    * @return Treasury address
    */
    function getTreasury() external view returns (address) {
        return treasury;
    }

    /**
    * @dev Gets slot information
    * @param _slotNumber Slot number (1-12)
    * @return price Slot price
    * @return poolPercent Pool percentage
    * @return active Whether slot is active
    */
    function getSlotInfo(uint256 _slotNumber) external view returns (
        uint256 price,
        uint256 poolPercent,
        bool active
    ) {
        require(_slotNumber >= 1 && _slotNumber <= 12, "Invalid slot number");
        
        Slot storage slot = slots[_slotNumber];
        return (slot.price, slot.poolPercent, slot.active);
    }

    /**
    * @dev Gets pool distribution days
    * @return Array of 3 distribution days
    */
    function getPoolDistributionDays() external view returns (uint8[3] memory) {
        return poolDistributionDays;
    }

    /**
    * @dev Gets level requirement information
    * @param _level Level number (1-50)
    * @return directRequired Number of direct referrals required
    * @return percent Percentage of level income
    */
    function getLevelRequirement(uint256 _level) external view returns (
        uint256 directRequired,
        uint256 percent
    ) {
        require(_level >= 1 && _level <= 50, "Invalid level");
        
        LevelRequirement storage requirement = levelRequirements[_level];
        return (requirement.directRequired, requirement.percent);
    }

    /**
    * @dev Emergency withdrawal of stuck funds
    * Can only be called by the default admin role
    * @param _amount Amount to withdraw
    */
    function emergencyWithdraw(uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_amount <= address(this).balance, "Insufficient balance");
        require(owner != address(0), "Owner not set");
        
        payable(owner).transfer(_amount);
    }
}