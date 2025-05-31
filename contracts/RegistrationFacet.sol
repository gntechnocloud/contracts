// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.20;

import "./FortuneNXTStorage.sol";

/**
 * @title RegistrationFacet
 * @dev Facet for user registration logic in the Diamond pattern.
 */
contract RegistrationFacet is FortuneNXTStorage {
    event UserRegistered(address indexed user, address indexed referrer);

    /**
     * @dev Registers a new user with a referrer.
     * @param _referrer Address of the referrer
     */
    function register(address _referrer) external {
        require(!users[msg.sender].isActive, "User already registered");
        require(_referrer != msg.sender, "Cannot refer yourself");
        require(users[_referrer].isActive || _referrer == owner, "Referrer not active");

        User storage user = users[msg.sender];
        user.referrer = _referrer;
        user.isActive = true;
        user.joinedAt = block.timestamp;

        users[_referrer].directReferrals++;

        totalUsers++;

        emit UserRegistered(msg.sender, _referrer);
    }
}