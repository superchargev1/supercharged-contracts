// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Libs.sol";

library CalculatorHelper {
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function minus(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function getBuyFillingValue(
        uint256 price,
        uint256 fillingAmount,
        uint256 sellPrice,
        Libs.OrderType sellOrderType,
        uint256 buyFee
    ) external pure returns (uint256, uint256) {
        uint256 fillingValue = price != 0
            ? (fillingAmount * price) / Libs.WEI6
            : (fillingAmount *
                (
                    sellOrderType == Libs.OrderType.SellYes ||
                        sellOrderType == Libs.OrderType.SellNo
                        ? sellPrice
                        : (Libs.WEI6 - sellPrice)
                )) / Libs.WEI6;
        uint256 _buyFee = (fillingValue * buyFee) / 1000;
        return (fillingValue, _buyFee);
    }

    function getSellFillingValue(
        uint256 price,
        uint256 fillingAmount,
        uint256 buyPrice,
        Libs.OrderType buyOrderType
    ) external pure returns (uint256) {
        uint256 fillingValue = price != 0
            ? (fillingAmount * price) / Libs.WEI6
            : (fillingAmount *
                (
                    buyOrderType == Libs.OrderType.BuyYes ||
                        buyOrderType == Libs.OrderType.BuyNo
                        ? buyPrice
                        : (Libs.WEI6 - buyPrice)
                )) / Libs.WEI6;
        return (fillingValue);
    }
}
