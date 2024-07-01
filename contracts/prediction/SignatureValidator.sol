//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../libs/Base.sol";
import "./Libs.sol";
import "./Events.sol";

contract SignatureValidator is OwnableUpgradeable, Base {
    using ECDSA for bytes32;
    bytes32 public constant BOOKER_ROLE = keccak256("BOOKER_ROLE");

    function initialize(address bookieAddress) public initializer {
        __Ownable_init(msg.sender);
        __Base_init(bookieAddress);
    }

    function signatureLimitBuy(
        address orderbookContract,
        address sender,
        Libs.OrderType orderType,
        uint256 outcomeId,
        uint256 price,
        uint256 value,
        bytes memory signature
    ) public view {
        bytes32 hash = keccak256(
            abi.encodePacked(
                orderbookContract,
                sender,
                orderType,
                outcomeId,
                price,
                value
            )
        );
        address recoverBooker = MessageHashUtils
            .toEthSignedMessageHash(hash)
            .recover(signature);
        require(
            bookie.hasRole(BOOKER_ROLE, recoverBooker),
            "Invalid Signature"
        );
    }

    function signatureLimitSell(
        address orderbookContract,
        address sender,
        Libs.OrderType orderType,
        uint256 outcomeId,
        uint256 price,
        uint256 amount,
        bytes memory signature
    ) public view {
        bytes32 hash = keccak256(
            abi.encodePacked(
                orderbookContract,
                sender,
                orderType,
                outcomeId,
                price,
                amount
            )
        );
        address recoverBooker = MessageHashUtils
            .toEthSignedMessageHash(hash)
            .recover(signature);
        require(
            bookie.hasRole(BOOKER_ROLE, recoverBooker),
            "Invalid Signature"
        );
    }

    function signatureClaimEvent(
        address orderbookContract,
        address sender,
        uint32 eventId,
        bytes memory signature
    ) public view {
        //check the signature
        bytes32 hash = keccak256(
            abi.encodePacked(orderbookContract, sender, eventId)
        );
        address recoverBooker = MessageHashUtils
            .toEthSignedMessageHash(hash)
            .recover(signature);
        require(
            bookie.hasRole(BOOKER_ROLE, recoverBooker),
            "Invalid Signature"
        );
    }

    function signatureCloseListOrders(
        address orderbookContract,
        address sender,
        uint256[] memory orderIds,
        bytes memory signature
    ) public view {
        bytes32 hash = keccak256(
            abi.encodePacked(orderbookContract, sender, orderIds)
        );
        address recoverBooker = MessageHashUtils
            .toEthSignedMessageHash(hash)
            .recover(signature);
        require(
            bookie.hasRole(BOOKER_ROLE, recoverBooker),
            "Invalid Signature"
        );
    }

    function signatureCloseOrder(
        address orderbookContract,
        address sender,
        uint256 orderId,
        bytes memory signature
    ) public view {
        bytes32 hash = keccak256(
            abi.encodePacked(orderbookContract, sender, orderId)
        );
        address recoverBooker = MessageHashUtils
            .toEthSignedMessageHash(hash)
            .recover(signature);
        require(
            bookie.hasRole(BOOKER_ROLE, recoverBooker),
            "Invalid Signature"
        );
    }

    function validateMatching(
        Libs.Order memory orgOrder,
        Libs.Order[] memory matchingOrders
    ) public pure {
        for (uint i = 0; i < matchingOrders.length; i++) {
            Libs.Order memory _matchOrder = matchingOrders[i];
            require(
                _matchOrder.status == Libs.OrderStatus.Open ||
                    _matchOrder.status == Libs.OrderStatus.Matched,
                "Invalid Order Status"
            );
            require(
                _matchOrder.outcomeId == orgOrder.outcomeId,
                "Invalid Order Outcome"
            );
            require(
                orgOrder.orderType == Libs.OrderType.BuyYes
                    ? (_matchOrder.orderType == Libs.OrderType.SellYes ||
                        _matchOrder.orderType == Libs.OrderType.BuyNo)
                    : (
                        orgOrder.orderType == Libs.OrderType.BuyNo
                            ? (_matchOrder.orderType == Libs.OrderType.SellNo ||
                                _matchOrder.orderType == Libs.OrderType.BuyYes)
                            : (
                                orgOrder.orderType == Libs.OrderType.SellYes
                                    ? (_matchOrder.orderType ==
                                        Libs.OrderType.BuyYes ||
                                        _matchOrder.orderType ==
                                        Libs.OrderType.SellNo)
                                    : (_matchOrder.orderType ==
                                        Libs.OrderType.BuyNo ||
                                        _matchOrder.orderType ==
                                        Libs.OrderType.SellYes)
                            )
                    ),
                "Invalid Sell Order Type"
            );
            if (
                orgOrder.orderType == Libs.OrderType.BuyYes ||
                orgOrder.orderType == Libs.OrderType.BuyNo
            ) {
                if (orgOrder.price != 0) {
                    require(
                        _matchOrder.price <= orgOrder.price ||
                            _matchOrder.price + orgOrder.price >= Libs.WEI6,
                        "Invalid Price"
                    );
                }
            } else {
                if (orgOrder.price != 0) {
                    require(
                        _matchOrder.price >= orgOrder.price ||
                            _matchOrder.price + orgOrder.price <= Libs.WEI6,
                        "Invalid Price"
                    );
                }
            }
        }
    }

    function validateLimitBuyInput(
        Libs.OrderType orderType,
        uint256 price,
        uint256 value
    ) external pure {
        if (price != 0) {
            require(
                price > 0 && price < Libs.WEI6 && value > 0,
                "Invalid Input"
            );
        }
        require(
            orderType == Libs.OrderType.BuyYes ||
                orderType == Libs.OrderType.BuyNo,
            "Invalid Order Type"
        );
    }

    function validateLimitSellInput(
        Libs.OrderType orderType,
        uint256 price,
        uint256 amount,
        uint256 long,
        uint256 short
    ) external pure {
        if (price != 0) {
            require(
                price > 0 &&
                    price < Libs.WEI6 &&
                    amount > 0 &&
                    orderType == Libs.OrderType.SellYes
                    ? amount <= long
                    : amount <= short,
                "Invalid Input"
            );
        }
        require(
            orderType == Libs.OrderType.SellYes ||
                orderType == Libs.OrderType.SellNo,
            "Invalid Order Type"
        );
    }

    function signatureMarketBuy(
        address orderbookContract,
        address sender,
        Libs.OrderType orderType,
        uint256 outcomeId,
        uint256 value,
        uint256 expireTime,
        uint256[] memory matchingOrderIds,
        bytes memory signature
    ) public view {
        bytes32 hash = keccak256(
            abi.encodePacked(
                orderbookContract,
                sender,
                orderType,
                outcomeId,
                value,
                expireTime,
                matchingOrderIds
            )
        );
        address recoverBooker = MessageHashUtils
            .toEthSignedMessageHash(hash)
            .recover(signature);
        require(
            bookie.hasRole(BOOKER_ROLE, recoverBooker),
            "Invalid Signature"
        );
    }

    function signatureMarketSell(
        address orderbookContract,
        address sender,
        Libs.OrderType orderType,
        uint256 outcomeId,
        uint256 amount,
        uint256 expireTime,
        uint256[] memory matchingOrderIds,
        bytes memory signature
    ) public view {
        bytes32 hash = keccak256(
            abi.encodePacked(
                orderbookContract,
                sender,
                orderType,
                outcomeId,
                amount,
                expireTime,
                matchingOrderIds
            )
        );
        address recoverBooker = MessageHashUtils
            .toEthSignedMessageHash(hash)
            .recover(signature);
        require(
            bookie.hasRole(BOOKER_ROLE, recoverBooker),
            "Invalid Signature"
        );
    }

    function validateCloseOrderInput(
        address orderUser,
        address account,
        Libs.OrderStatus status
    ) external pure {
        require(
            orderUser == account &&
                (status != Libs.OrderStatus.Filled ||
                    status != Libs.OrderStatus.Closed),
            "Invalid"
        );
    }

    function signatureRefundOrder(
        address orderbookContract,
        address sender,
        uint256 orderId,
        uint256 avgPrice,
        bytes memory signature
    ) public view {
        bytes32 hash = keccak256(
            abi.encodePacked(orderbookContract, sender, orderId, avgPrice)
        );
        address recoverBooker = MessageHashUtils
            .toEthSignedMessageHash(hash)
            .recover(signature);
        require(
            bookie.hasRole(BOOKER_ROLE, recoverBooker),
            "Invalid Signature"
        );
    }
}
