//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "../interfaces/IBlast.sol";
import "../interfaces/IERC20Rebasing.sol";

contract Blastyield {
    IBlast public constant BLAST =
        IBlast(0x4300000000000000000000000000000000000002);

    // NOTE: these addresses differ on the Blast mainnet and testnet; the lines below are the mainnet addresses
    IERC20Rebasing public constant USDB =
        IERC20Rebasing(0x4300000000000000000000000000000000000003);
    IERC20Rebasing public constant WETH =
        IERC20Rebasing(0x4300000000000000000000000000000000000004);

    // NOTE: the commented lines below are the testnet addresses
    // IERC20Rebasing public constant USDB =
    //     IERC20Rebasing(0x4200000000000000000000000000000000000022);
    // IERC20Rebasing public constant WETH =
    //     IERC20Rebasing(0x4200000000000000000000000000000000000023);

    function _claimAllYield(address recipient) internal {
        //internal function to claim the yield
        BLAST.claimAllYield(address(this), recipient);
    }

    function _initBlastYield() internal {
        //Blast configuration for claimable yield
        BLAST.configureClaimableYield();
        BLAST.configureClaimableGas();
        USDB.configure(YieldModeERC20.CLAIMABLE); //configure claimable yield for USDB
        WETH.configure(YieldModeERC20.CLAIMABLE); //configure claimable yield for WETH
    }
}
