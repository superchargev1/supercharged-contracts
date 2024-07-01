// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

enum YieldModeERC20 {
    AUTOMATIC,
    VOID,
    CLAIMABLE
}

interface IERC20Rebasing {
    // changes the yield mode of the caller and update the balance
    // to reflect the configuration
    function configure(YieldModeERC20) external returns (uint256);

    // "claimable" yield mode accounts can call this this claim their yield
    // to another address
    function claim(
        address recipient,
        uint256 amount
    ) external returns (uint256);

    // read the claimable amount for an account
    function getClaimableAmount(
        address account
    ) external view returns (uint256);

    //transfer the amount to the recipient
    function transfer(address to, uint256 value) external returns (bool);

    //balanceOf account
    function balanceOf(address account) external view returns (uint256);

    //transferFrom
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    //decimals
    function decimals() external view returns (uint8);
}
