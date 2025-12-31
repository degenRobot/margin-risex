// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IErrors} from "../interfaces/IErrors.sol";

/// @title Pausable
/// @notice Emergency pause functionality for critical operations
/// @dev Extends Ownable to restrict pause/unpause to owner
abstract contract Pausable is Ownable, IErrors {
    /// @notice Whether the contract is paused
    bool private _paused;
    
    /// @notice Emitted when contract is paused
    event Paused(address indexed by);
    
    /// @notice Emitted when contract is unpaused
    event Unpaused(address indexed by);
    
    /// @notice Modifier to check if not paused
    modifier whenNotPaused() {
        if (_paused) revert ContractPaused();
        _;
    }
    
    /// @notice Modifier to check if paused
    modifier whenPaused() {
        if (!_paused) revert("Not paused");
        _;
    }
    
    /// @notice Returns whether the contract is paused
    function paused() public view returns (bool) {
        return _paused;
    }
    
    /// @notice Pause the contract (only owner)
    /// @dev Emits Paused event
    function pause() external onlyOwner whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }
    
    /// @notice Unpause the contract (only owner)
    /// @dev Emits Unpaused event
    function unpause() external onlyOwner whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }
    
    /// @notice Internal function to pause
    /// @dev Can be called by inheriting contracts
    function _pause() internal whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }
    
    /// @notice Internal function to unpause
    /// @dev Can be called by inheriting contracts
    function _unpause() internal whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}