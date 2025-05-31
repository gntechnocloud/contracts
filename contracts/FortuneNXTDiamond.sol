// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./FortuneNXTStorage.sol";

/**
 * @title FortuneNXTDiamond
 * @dev Implementation of the Diamond pattern (EIP-2535) for Fortunity NXT.
 * Allows for modular upgrades of specific facets of functionality.
 */
contract FortuneNXTDiamond is FortuneNXTStorage {
    using Address for address;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    // Events
    event DiamondCut(FacetCut[] _diamondCut, address _init, bytes _calldata);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // Structs
    struct Facet {
        address facetAddress;
        EnumerableSet.Bytes32Set functionSelectors; // Changed from Bytes4Set to Bytes32Set
    }

    struct FacetCut {
        address facetAddress;
        bytes4[] functionSelectors;
        uint8 action; // 0 = Add, 1 = Replace, 2 = Remove
    }

    // Constants
    uint8 internal constant ADD = 0;
    uint8 internal constant REPLACE = 1;
    uint8 internal constant REMOVE = 2;

    // Storage - renamed to avoid conflict with function name
    mapping(bytes4 => address) internal selectorToFacetAddress;
    mapping(address => Facet) internal _facets;
    address[] internal _facetAddresses; // Renamed from facetAddresses

    /**
     * @dev Initializes the diamond with facets.
     * @param _newDiamondCut Array of facet cuts to apply (renamed to avoid shadowing)
     */
    constructor(FacetCut[] memory _newDiamondCut) {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
        
        _diamondCut(_newDiamondCut, address(0), "");
    }

    /**
     * @dev Fallback function that delegates calls to facets.
     */
    fallback() external payable {
        address facet = selectorToFacetAddress[msg.sig];
        require(facet != address(0), "Diamond: Function does not exist");
        
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    /**
     * @dev Receive function to accept ETH.
     */
    receive() external payable {}

    /**
     * @dev Cuts facets (add, replace, remove).
     * @param diamondCutParam Array of facet cuts to apply (renamed to avoid shadowing)
     * @param _init Address of the initialization contract
     * @param _calldata Calldata for initialization
     */
    function diamondCut(
        FacetCut[] memory diamondCutParam,
        address _init,
        bytes memory _calldata
    ) external {
        require(msg.sender == owner, "Diamond: Not authorized");
        _diamondCut(diamondCutParam, _init, _calldata);
    }

    /**
     * @dev Internal implementation of diamondCut.
     * @param diamondCutData Array of facet cuts to apply (renamed to avoid shadowing)
     * @param _init Address of the initialization contract
     * @param _calldata Calldata for initialization
     */
    function _diamondCut(
        FacetCut[] memory diamondCutData,
        address _init,
        bytes memory _calldata
    ) internal {
        for (uint256 i = 0; i < diamondCutData.length; i++) {
            FacetCut memory cut = diamondCutData[i];
            
            if (cut.action == ADD) {
                _addFunctions(cut.facetAddress, cut.functionSelectors);
            } else if (cut.action == REPLACE) {
                _replaceFunctions(cut.facetAddress, cut.functionSelectors);
            } else if (cut.action == REMOVE) {
                _removeFunctions(cut.facetAddress, cut.functionSelectors);
            } else {
                revert("Diamond: Invalid action");
            }
        }
        
        emit DiamondCut(diamondCutData, _init, _calldata);
        
        if (_init != address(0)) {
            if (_calldata.length > 0) {
                _init.functionDelegateCall(_calldata);
            } else {
                _init.functionDelegateCall(abi.encodeWithSignature("init()"));
            }
        }
    }

    /**
     * @dev Adds functions to a facet.
     * @param _facetAddress Address of the facet
     * @param _functionSelectors Array of function selectors to add
     */
    function _addFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        require(_facetAddress != address(0), "Diamond: Invalid facet address");
        require(_functionSelectors.length > 0, "Diamond: No selectors provided");
        
        Facet storage facet = _facets[_facetAddress];
        
        if (facet.facetAddress == address(0)) {
            _facetAddresses.push(_facetAddress);
            facet.facetAddress = _facetAddress;
        }
        
        for (uint256 i = 0; i < _functionSelectors.length; i++) {
            bytes4 selector = _functionSelectors[i];
            require(selectorToFacetAddress[selector] == address(0), "Diamond: Function already exists");
            
            // Cast bytes4 to bytes32 when adding to the set
            facet.functionSelectors.add(bytes32(selector));
            selectorToFacetAddress[selector] = _facetAddress;
        }
    }

    /**
     * @dev Replaces functions in a facet.
     * @param _facetAddress Address of the facet
     * @param _functionSelectors Array of function selectors to replace
     */
    function _replaceFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        require(_facetAddress != address(0), "Diamond: Invalid facet address");
        require(_functionSelectors.length > 0, "Diamond: No selectors provided");
        
        for (uint256 i = 0; i < _functionSelectors.length; i++) {
            bytes4 selector = _functionSelectors[i];
            address oldFacetAddress = selectorToFacetAddress[selector];
            
            require(oldFacetAddress != address(0), "Diamond: Function does not exist");
            require(oldFacetAddress != _facetAddress, "Diamond: Cannot replace with same facet");
            
            // Remove from old facet - cast bytes4 to bytes32
            _facets[oldFacetAddress].functionSelectors.remove(bytes32(selector));
            
            // Add to new facet
            Facet storage facet = _facets[_facetAddress];
            
            if (facet.facetAddress == address(0)) {
                _facetAddresses.push(_facetAddress);
                facet.facetAddress = _facetAddress;
            }
            
            // Cast bytes4 to bytes32 when adding to the set
            facet.functionSelectors.add(bytes32(selector));
            selectorToFacetAddress[selector] = _facetAddress;
        }
    }

    /**
     * @dev Removes functions from a facet.
     * @param _facetAddress Address of the facet (not used, just for consistency)
     * @param _functionSelectors Array of function selectors to remove
     */
    function _removeFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "Diamond: No selectors provided");
        
        for (uint256 i = 0; i < _functionSelectors.length; i++) {
            bytes4 selector = _functionSelectors[i];
            address currentFacetAddress = selectorToFacetAddress[selector];
            
            require(currentFacetAddress != address(0), "Diamond: Function does not exist");
            
            // Remove from facet - cast bytes4 to bytes32
            _facets[currentFacetAddress].functionSelectors.remove(bytes32(selector));
            
            // Remove from selector mapping
            delete selectorToFacetAddress[selector];
            
            // If facet has no more functions, remove it from _facetAddresses
            if (_facets[currentFacetAddress].functionSelectors.length() == 0) {
                for (uint256 j = 0; j < _facetAddresses.length; j++) {
                    if (_facetAddresses[j] == currentFacetAddress) {
                        _facetAddresses[j] = _facetAddresses[_facetAddresses.length - 1];
                        _facetAddresses.pop();
                        break;
                    }
                }
                
                delete _facets[currentFacetAddress];
            }
        }
    }

    /**
     * @dev Gets all facet addresses.
     * @return facetAddresses_ Array of facet addresses
     */
    function facetAddresses() external view returns (address[] memory facetAddresses_) {
        return _facetAddresses;
    }

    /**
     * @dev Gets all function selectors for a facet.
     * @param _facet Address of the facet
     * @return selectors Array of function selectors
     */
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory) {
        Facet storage facet = _facets[_facet];
        uint256 selectorCount = facet.functionSelectors.length();
        bytes4[] memory selectors = new bytes4[](selectorCount);
        
        for (uint256 i = 0; i < selectorCount; i++) {
            // Cast bytes32 back to bytes4 when reading from the set
            selectors[i] = bytes4(facet.functionSelectors.at(i));
        }
        
        return selectors;
    }

    /**
     * @dev Gets the facet address for a function selector.
     * @param _functionSelector Function selector
     * @return facetAddress_ Address of the facet
     */
    function facetAddress(bytes4 _functionSelector) external view returns (address facetAddress_) {
        return selectorToFacetAddress[_functionSelector];
    }

    /**
     * @dev Transfer ownership of the diamond
     * @param _newOwner The new owner address
     */
    function transferOwnership(address _newOwner) external {
        require(msg.sender == owner, "Diamond: Not authorized");
        require(_newOwner != address(0), "New owner cannot be zero address");
        
        address previousOwner = owner;
        owner = _newOwner;
        
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    /**
     * @dev Get the owner of the diamond
     * @return owner_ The owner address
     */
    function getOwner() external view returns (address owner_) {
        return owner;
    }

    /**
     * @dev Check if a function selector exists in the diamond
     * @param _functionSelector The function selector to check
     * @return exists True if the function exists
     */
    function functionExists(bytes4 _functionSelector) external view returns (bool exists) {
        return selectorToFacetAddress[_functionSelector] != address(0);
    }

    /**
     * @dev Get all facets and their function selectors
     * @return facets_ Array of facet information
     */
    function facets() external view returns (FacetInfo[] memory facets_) {
        uint256 facetCount = _facetAddresses.length;
        facets_ = new FacetInfo[](facetCount);
        
        for (uint256 i = 0; i < facetCount; i++) {
            address facetAddr = _facetAddresses[i];
            Facet storage facet = _facets[facetAddr];
            
            uint256 selectorCount = facet.functionSelectors.length();
            bytes4[] memory selectors = new bytes4[](selectorCount);
            
            for (uint256 j = 0; j < selectorCount; j++) {
                // Cast bytes32 back to bytes4 when reading from the set
                selectors[j] = bytes4(facet.functionSelectors.at(j));
            }
            
            facets_[i] = FacetInfo({
                facetAddress: facetAddr,
                functionSelectors: selectors
            });
        }
    }

    struct FacetInfo {
        address facetAddress;
        bytes4[] functionSelectors;
    }
}