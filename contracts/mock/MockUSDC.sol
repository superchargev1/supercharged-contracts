// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    address _owner;
    mapping(address => bool) _transferables;

    event TransferableUpdate(address account, bool oldValue, bool newValue);

    constructor(uint256 initialSupply) ERC20("USDB", "USDB") {
        _owner = msg.sender;
        _transferables[msg.sender] = true;
        _mint(msg.sender, initialSupply);
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
}
