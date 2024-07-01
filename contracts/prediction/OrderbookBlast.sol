//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "./Orderbook.sol";
import "../blast/Blastyield.sol";
import "../blast/Blastpoint.sol";

contract OrderbookBlast is Orderbook, Blastyield, Blastpoint {
    bytes32 public constant BLAST_POINT_OPERATOR_ROLE =
        keccak256("BLAST_POINT_OPERATOR_ROLE");

    ///////////////////////////
    ////// BLAST CLAIM YIELD //////
    ///////////////////////////
    function initBlastYield() external onlyRole(ADMIN_ROLE) {
        _initBlastYield();
    }

    function claimAllYield() external onlyRole(ADMIN_ROLE) {
        OrderbookStorage storage $ = _getOwnStorage();
        _claimAllYield($.config.feeWallet);
    }

    ///////////////////////////
    ////// BLAST POINT //////
    ///////////////////////////
    function configurePointsOperator()
        external
        onlyRole(BLAST_POINT_OPERATOR_ROLE)
    {
        _configurePointsOperator();
    }

    function configurePointsOperatorOnBehalf(
        address contractAddress
    ) external onlyRole(BLAST_POINT_OPERATOR_ROLE) {
        _configurePointsOperatorOnBehalf(contractAddress);
    }
}
