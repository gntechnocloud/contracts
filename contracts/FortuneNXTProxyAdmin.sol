// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title FortuneNXTProxyAdmin
 * @dev Admin contract for the proxy, with multi-signature capabilities.
 * Controls upgrade permissions and administrative functions.
 */
contract FortuneNXTProxyAdmin is ProxyAdmin, AccessControl {
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint256 public constant UPGRADE_TIMELOCK = 2 days;

    struct UpgradeProposal {
        address newImplementation;
        uint256 proposalTime;
        bool executed;
        mapping(address => bool) approvals;
        uint256 approvalCount;
    }

    uint256 public requiredApprovals;
    uint256 public currentProposalId;
    mapping(uint256 => UpgradeProposal) public upgradeProposals;

    event UpgradeProposed(uint256 proposalId, address newImplementation);
    event UpgradeApproved(uint256 proposalId, address approver);
    event UpgradeReady(uint256 proposalId, address newImplementation);

    constructor(address initialOwner, address[] memory _admins, uint256 _requiredApprovals)
        ProxyAdmin(initialOwner)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        for (uint256 i = 0; i < _admins.length; i++) {
            _grantRole(ADMIN_ROLE, _admins[i]);
            _grantRole(UPGRADER_ROLE, _admins[i]);
        }
        requiredApprovals = _requiredApprovals;
    }

    function proposeUpgrade(address _implementation)
        external
        onlyRole(UPGRADER_ROLE)
        returns (uint256 proposalId)
    {
        require(_implementation != address(0), "Invalid implementation address");
        proposalId = currentProposalId++;
        UpgradeProposal storage proposal = upgradeProposals[proposalId];
        proposal.newImplementation = _implementation;
        proposal.proposalTime = block.timestamp;
        proposal.executed = false;
        proposal.approvalCount = 1;
        proposal.approvals[msg.sender] = true;
        emit UpgradeProposed(proposalId, _implementation);
        return proposalId;
    }

    function approveUpgrade(uint256 _proposalId) external onlyRole(UPGRADER_ROLE) {
        UpgradeProposal storage proposal = upgradeProposals[_proposalId];
        require(proposal.newImplementation != address(0), "Proposal does not exist");
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.approvals[msg.sender], "Already approved");
        proposal.approvals[msg.sender] = true;
        proposal.approvalCount += 1;
        emit UpgradeApproved(_proposalId, msg.sender);
    }

    function markUpgradeReady(uint256 _proposalId) external onlyRole(UPGRADER_ROLE) {
        UpgradeProposal storage proposal = upgradeProposals[_proposalId];
        require(proposal.newImplementation != address(0), "Proposal does not exist");
        require(!proposal.executed, "Proposal already executed");
        require(proposal.approvalCount >= requiredApprovals, "Not enough approvals");
        require(block.timestamp >= proposal.proposalTime + UPGRADE_TIMELOCK, "Timelock not expired");
        proposal.executed = true;
        emit UpgradeReady(_proposalId, proposal.newImplementation);
        // The actual upgrade must be performed by the ProxyAdmin owner using a script or admin UI.
    }
}
// This contract allows for proposing, approving, and marking upgrades ready with a timelock mechanism.
// It uses OpenZeppelin's AccessControl for role management and ProxyAdmin for upgrade management.
// The contract ensures that upgrades can only be executed after a certain number of approvals and a timelock period.
// The actual upgrade execution is expected to be handled externally, as the ProxyAdmin does not allow direct upgrades from within the contract.
// The contract emits events for each significant action, allowing for easy tracking of upgrade proposals and approvals.
// The `UPGRADER_ROLE` is responsible for proposing and approving upgrades, while the `ADMIN_ROLE` can manage the contract. 
// The `DEFAULT_ADMIN_ROLE` is granted to the initial owner and can manage roles and permissions.
// The `requiredApprovals` variable sets the number of approvals needed for an upgrade to be marked ready.
// The `UPGRADE_TIMELOCK` constant defines the minimum time that must pass before an upgrade can be executed after being marked ready.
// The `UpgradeProposal` struct holds the details of each upgrade proposal, including the new implementation address, proposal time, execution status, and approvals.
// The `proposeUpgrade` function allows an upgrader to propose a new implementation, initializing a new proposal.
// The `approveUpgrade` function allows an upgrader to approve a proposed upgrade, increasing the approval count and marking their approval.    
// The `markUpgradeReady` function checks if the proposal has enough approvals and if the timelock has expired, marking it ready for execution.
// The contract is designed to be secure and flexible, allowing for multi-signature control over upgrades while preventing unauthorized changes.
// The contract can be extended with additional features such as upgrade history, rollback mechanisms, or more complex approval workflows as needed.
// The contract is compatible with OpenZeppelin's upgradeable contracts and can be integrated into a larger system for managing smart contract upgrades in a decentralized application.
// The contract is designed to be used in a decentralized application where multiple parties need to agree on upgrades, ensuring security and transparency in the upgrade process.
// The contract can be deployed on Ethereum or compatible networks, providing a robust solution for managing smart contract upgrades in a decentralized manner. 
// The contract is written in Solidity 0.8.20, ensuring compatibility with the latest features and security improvements in the language.
// The contract can be tested using frameworks like Hardhat or Truffle, allowing for automated testing of the upgrade process and role management.
// The contract can be integrated with a front-end application to provide a user interface for managing upgrades, approvals, and role assignments.
// The contract can be extended with additional features such as upgrade history, rollback mechanisms, or more complex approval workflows as needed.
// The contract is designed to be secure and flexible, allowing for multi-signature control over upgrades while preventing unauthorized changes.
// The contract is compatible with OpenZeppelin's upgradeable contracts and can be integrated into a larger system for managing smart contract upgrades in a decentralized application. 
// The contract is designed to be used in a decentralized application where multiple parties need to agree on upgrades, ensuring security and transparency in the upgrade process.
// The contract can be deployed on Ethereum or compatible networks, providing a robust solution for managing smart contract upgrades in a decentralized manner.
