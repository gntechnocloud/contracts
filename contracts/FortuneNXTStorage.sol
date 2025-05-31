// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract FortuneNXTStorage {
    uint256 public constant ADMIN_FEE_PERCENT = 3;
    uint256 public constant MATRIX_INCOME_PERCENT = 75;
    uint256 public constant LEVEL_INCOME_PERCENT = 25;
    uint256 public constant POOL_EXTRA_PERCENT = 25;
    uint256 public constant MAX_PAYOUT_PERCENT = 200;
    uint256 public constant MAX_PAYOUT_TIME = 90 days;

    struct Slot {
        uint256 price;
        uint256 poolPercent;
        bool active;
    }

    struct Matrix {
        address owner;
        address[] level1;
        address[] level2;
        bool completed;
        uint256 earnings;
        uint256 createdAt;
    }

    struct User {
        address referrer;
        uint256 directReferrals;
        uint256[] activeSlots;
        mapping(uint256 => Matrix) matrices;
        uint256 totalEarnings;
        uint256 matrixEarnings;
        uint256 levelEarnings;
        uint256 poolEarnings;
        uint256 lastPoolDistribution;
        bool isActive;
        uint256 joinedAt;
    }

    struct LevelRequirement {
        uint256 directRequired;
        uint256 percent;
    }

    uint8[3] public poolDistributionDays = [5, 15, 25];

    mapping(address => User) internal users;
    mapping(uint256 => Slot) internal slots;
    mapping(uint256 => uint256) internal poolBalances;
    mapping(uint256 => address[]) internal slotParticipants;
    mapping(uint256 => LevelRequirement) internal levelRequirements;

    address public owner;
    address public treasury;
    uint256 public totalUsers;
    uint256 public totalVolume;
    uint256 public totalPoolBalance;
    uint256 public lastPoolDistributionTime;
    uint256 public version;

    uint256[50] private __gap;
}