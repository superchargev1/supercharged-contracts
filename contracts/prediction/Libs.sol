// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Libs {
    uint64 public constant WEI6 = 10 ** 6; // base for calculation
    enum OrderType {
        BuyYes,
        SellYes,
        BuyNo,
        SellNo
    }

    enum OrderStatus {
        Open,
        Matched,
        Filled,
        Closed
    }

    struct Config {
        //base per 1000
        uint256 winningFee;
        address feeWallet;
        //base per 1000
        uint256 buyFee;
        //base per 1000
        uint256 sellFee;
    }

    struct Order {
        OrderType orderType;
        address user;
        uint256 outcomeId;
        uint256 value;
        uint256 price;
        uint256 amount;
        OrderStatus status;
    }

    struct OrderFilled {
        uint256 amount;
        uint256 value;
    }

    function toCredit(
        uint256 value,
        uint8 decimal
    ) internal pure returns (uint256) {
        return (value * (10 ** decimal)) / WEI6;
    }

    function toDebit(
        uint256 value,
        uint8 decimal
    ) internal pure returns (uint256) {
        return (value * WEI6) / (10 ** decimal);
    }

    function getBuyFillingValue(
        uint256 price,
        uint256 fillingAmount,
        uint256 sellPrice,
        Libs.OrderType sellOrderType,
        uint256 buyFee
    ) internal pure returns (uint256, uint256) {
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
}
