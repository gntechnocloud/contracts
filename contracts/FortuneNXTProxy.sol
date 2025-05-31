// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/**
 * @title FortuneNXTProxy
 * @dev Main proxy contract that delegates calls to the implementation contract.
 * This contract never changes once deployed.
 */
contract FortuneNXTProxy is TransparentUpgradeableProxy {
    /**
     * @dev Initializes the proxy with an implementation contract, admin, and initialization data.
     * @param _logic Address of the initial implementation contract
     * @param _admin Address of the proxy admin
     * @param _data Initialization data to be passed to the implementation contract
     */
    constructor(
        address _logic,
        address _admin,
        bytes memory _data
    ) TransparentUpgradeableProxy(_logic, _admin, _data) {}
}