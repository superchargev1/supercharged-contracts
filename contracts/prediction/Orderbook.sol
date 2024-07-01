// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "../interfaces/IERC20Rebasing.sol";
import "../libs/Base.sol";
import "./Events.sol";
import "./Libs.sol";
import "./SignatureValidator.sol";

contract Orderbook is OwnableUpgradeable, Base {
    using ECDSA for bytes32;
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant BATCHING = keccak256("BATCHING");
    bytes32 public constant BOOKER_ROLE = keccak256("BOOKER_ROLE");
    uint64 public constant PRICE_WEI = 10 ** 8; // base for calculation
    uint256 public constant TINY_VALUE = 100; //

    struct OrderbookStorage {
        Libs.Config config;
        IERC20Rebasing credit;
        Events events;
        SignatureValidator signatureValidator;
        // orders
        mapping(uint256 => Libs.Order) limitOrders;
        mapping(uint256 => Libs.Order) marketOrders;
        mapping(uint256 => Libs.OrderFilled) orderFilleds;
        mapping(uint32 => mapping(address => uint256)) totalClaimed;
        uint256 lastOrderId;
    }

    // keccak256(abi.encode(uint256(keccak256("predition.storage.Orderbook")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OrderbookStorageLocation =
        0xb791fb8bc4ba217b3e654b867c95f2e44daa9b925b304cbff8ea6fc818afa800;

    function _getOwnStorage()
        internal
        pure
        returns (OrderbookStorage storage $)
    {
        assembly {
            $.slot := OrderbookStorageLocation
        }
    }

    event NewOrder(
        Libs.OrderType orderType,
        uint256 orderId,
        uint256 olId,
        address user,
        uint256 outcomeId,
        uint256 value,
        uint256 price,
        uint256 amount,
        uint256 curAmount
    );

    event FillOrder(
        uint256 orderId1,
        uint256 orderId2,
        uint256 price,
        uint256 curAmount,
        uint256 filledValue,
        Libs.OrderStatus matchOrderStatus,
        uint256 filledAmount,
        uint256 ticketBuyAmount,
        uint fee
    );
    event CloseOrder(uint256 orderId, Libs.OrderStatus status, address account);

    event EventClaim(
        uint32 eventId,
        uint256 totalWinning,
        uint256 returnAmount,
        uint256 winningFee,
        address account
    );

    function initialize(
        address bookieAddress,
        address eventAddress,
        address sinatureValidatorAddress,
        address usdbToken
    ) public virtual initializer {
        __Ownable_init(msg.sender);
        __Base_init(bookieAddress);

        OrderbookStorage storage $ = _getOwnStorage();
        // system leverage
        $.credit = IERC20Rebasing(usdbToken);
        $.events = Events(eventAddress);
        $.signatureValidator = SignatureValidator(sinatureValidatorAddress);
        $.config.feeWallet = owner();
        $.config.sellFee = 5;
        $.config.winningFee = 10;
    }

    //////////////////
    ///// SYSTEM /////
    //////////////////

    function matchingBuyLimit(
        uint256 orderId,
        uint256[] memory matchingOrderIds
    ) external onlyFrom(BATCHING) {
        _matchingBuyLimit(orderId, matchingOrderIds);
    }

    function matchingSellLimit(
        uint256 orderId,
        uint256[] memory matchingOrderIds
    ) external onlyFrom(BATCHING) {
        _matchingSellLimit(orderId, matchingOrderIds);
    }

    //////////////////
    ////// USER //////
    //////////////////

    function limitBuy(
        Libs.OrderType orderType,
        uint256 outcomeId,
        uint256 price,
        uint256 value,
        uint256 olId,
        bytes memory signature
    ) external {
        _limitBuy(orderType, olId, outcomeId, price, value, signature);
    }

    function limitSell(
        Libs.OrderType orderType,
        uint256 outcomeId,
        uint256 price,
        uint256 amount,
        uint256 olId,
        bytes memory signature
    ) external {
        _limitSell(orderType, olId, outcomeId, price, amount, signature);
    }

    function claimEvent(uint32 eventId, bytes memory signature) external {
        OrderbookStorage storage $ = _getOwnStorage();
        //check the signature
        $.signatureValidator.signatureClaimEvent(
            address(this),
            msg.sender,
            eventId,
            signature
        );
        (
            uint256 _totalWinning,
            uint256 _returnAmount,
            uint256 _totalWinningFee
        ) = $.events.claim(eventId, msg.sender, $.config.winningFee);
        $.totalClaimed[eventId][msg.sender] += _returnAmount;
        $.credit.transfer(
            msg.sender,
            Libs.toCredit(_returnAmount, $.credit.decimals())
        );
        $.credit.transfer(
            $.config.feeWallet,
            Libs.toCredit(_totalWinningFee, $.credit.decimals())
        );
        emit EventClaim(
            eventId,
            _totalWinning,
            _returnAmount,
            _totalWinningFee,
            msg.sender
        );
    }

    function closeListOrders(
        uint256[] memory orderIds,
        bytes memory signature
    ) external {
        //check the signature
        OrderbookStorage storage $ = _getOwnStorage();
        $.signatureValidator.signatureCloseListOrders(
            address(this),
            msg.sender,
            orderIds,
            signature
        );
        for (uint i = 0; i < orderIds.length; i++) {
            _closeOrder(orderIds[i], msg.sender);
        }
    }

    function closeOrder(uint256 orderId, bytes memory signature) external {
        //check the signature
        OrderbookStorage storage $ = _getOwnStorage();
        $.signatureValidator.signatureCloseOrder(
            address(this),
            msg.sender,
            orderId,
            signature
        );
        address _user = msg.sender;
        _closeOrder(orderId, _user);
    }

    function marketBuy(
        Libs.OrderType orderType,
        uint256 olId,
        uint256 outcomeId,
        uint256 value,
        uint256 expireTime,
        uint256[] memory matchingOrderIds,
        bytes memory signature
    ) external {
        //validate signature
        OrderbookStorage storage $ = _getOwnStorage();
        $.signatureValidator.signatureMarketBuy(
            address(this),
            msg.sender,
            orderType,
            outcomeId,
            value,
            expireTime,
            matchingOrderIds,
            signature
        );
        //validate input
        require(block.timestamp <= expireTime, "Expired");
        //create order
        uint256 _newOrderId = _buy(orderType, olId, outcomeId, 0, value, $);
        //matching
        if (_matchingBuyLimit(_newOrderId, matchingOrderIds) == false) {
            // not filled all
            _closeOrder(_newOrderId, msg.sender);
        }
    }

    function marketSell(
        Libs.OrderType orderType,
        uint256 olId,
        uint256 outcomeId,
        uint256 amount,
        uint256 expireTime,
        uint256[] memory matchingOrderIds,
        bytes memory signature
    ) external {
        //validate signature
        OrderbookStorage storage $ = _getOwnStorage();
        $.signatureValidator.signatureMarketSell(
            address(this),
            msg.sender,
            orderType,
            outcomeId,
            amount,
            expireTime,
            matchingOrderIds,
            signature
        );
        //validate input
        require(block.timestamp <= expireTime, "Expired");
        //create order
        uint256 _newOrderId = _sell(orderType, olId, outcomeId, 0, amount, $);
        //matching
        if (_matchingSellLimit(_newOrderId, matchingOrderIds) == false) {
            // not filled all
            _closeOrder(_newOrderId, msg.sender);
        }
    }

    function refundOrder(
        uint256 orderId,
        uint256 avgPrice,
        bytes memory signature
    ) external {
        //check the signature
        OrderbookStorage storage $ = _getOwnStorage();
        $.signatureValidator.signatureRefundOrder(
            address(this),
            msg.sender,
            orderId,
            avgPrice,
            signature
        );
        Events.OutcomeStatus _outcomeStatus = $.events.getOutcomeStatus(
            $.limitOrders[orderId].outcomeId
        );
        require(
            $.limitOrders[orderId].user == msg.sender &&
                _outcomeStatus == Events.OutcomeStatus.Cancelled &&
                $.limitOrders[orderId].status != Libs.OrderStatus.Closed,
            ""
        );
        uint256 _refund = ($.limitOrders[orderId].orderType ==
            Libs.OrderType.BuyYes ||
            $.limitOrders[orderId].orderType == Libs.OrderType.BuyNo)
            ? $.limitOrders[orderId].value
            : (($.limitOrders[orderId].amount -
                $.orderFilleds[orderId].amount) * avgPrice) / Libs.WEI6;
        $.credit.transfer(
            msg.sender,
            Libs.toCredit(_refund, $.credit.decimals())
        );
        $.limitOrders[orderId].status = Libs.OrderStatus.Closed;
        emit CloseOrder(orderId, $.limitOrders[orderId].status, msg.sender);
    }

    //////////////////
    ///// SETTER /////
    //////////////////

    function setFee(
        uint256 buyFee,
        uint256 sellFee,
        uint256 winningFee
    ) external onlyRole(OPERATOR_ROLE) {
        OrderbookStorage storage $ = _getOwnStorage();
        $.config.buyFee = buyFee;
        $.config.sellFee = sellFee;
        $.config.winningFee = winningFee;
    }

    function setFeeWallet(address feeWallet) external onlyOwner {
        OrderbookStorage storage $ = _getOwnStorage();
        $.config.feeWallet = feeWallet;
    }

    //////////////////
    ///// GETTER /////
    //////////////////

    function getClaimEvent(
        uint32 eventId,
        uint256[] memory orderIds,
        address account
    )
        external
        view
        returns (uint256 totalWinning, uint256 unfilled, uint256 claimed)
    {
        return _getClaimEvent(eventId, orderIds, account);
    }

    function getCurOutcomePosition(
        uint256 outcomeId,
        address account
    ) external view returns (uint256 long, uint256 short) {
        OrderbookStorage storage $ = _getOwnStorage();
        return $.events.getOutcomeBalance(outcomeId, account);
    }

    function getFee()
        external
        view
        returns (uint256 buyFee, uint256 sellFee, uint256 winningFee)
    {
        OrderbookStorage storage $ = _getOwnStorage();
        return ($.config.buyFee, $.config.sellFee, $.config.winningFee);
    }

    //////////////////
    ///// PRIVATE ////
    //////////////////

    function _getClaimEvent(
        uint32 eventId,
        uint256[] memory orderIds,
        address account
    )
        internal
        view
        returns (uint256 totalWinning, uint256 unfilled, uint256 claimed)
    {
        OrderbookStorage storage $ = _getOwnStorage();
        bool flagLong;
        bool flagShort;
        for (uint i = 0; i < orderIds.length; i++) {
            Libs.Order memory _order = $.limitOrders[orderIds[i]];
            uint256 _winningFee;
            Events.OutcomeStatus _outcomeStatus = $.events.getOutcomeStatus(
                _order.outcomeId
            );
            //check the order type
            if (
                _order.orderType == Libs.OrderType.BuyYes ||
                _order.orderType == Libs.OrderType.BuyNo
            ) {
                //if _outcomeStatus is Won => claim the matched position of outcome
                // then refund the unmatch value of order
                if (_outcomeStatus == Events.OutcomeStatus.Won) {
                    (uint256 _long, ) = $.events.getOutcomeBalance(
                        _order.outcomeId,
                        account
                    );
                    //get the winningFee
                    _winningFee = (_long * $.config.winningFee) / 1000;
                    if (!flagLong) {
                        totalWinning += _long - _winningFee;
                    }
                    //refund the unmatch value
                    uint256 _refund = _order.value -
                        $.orderFilleds[orderIds[i]].value;
                    unfilled += _refund;
                    flagLong = true;
                } else if (_outcomeStatus == Events.OutcomeStatus.Cancelled) {
                    //refund all the value
                    uint256 _refund = _order.value;
                    unfilled += _refund;
                } else {
                    (, uint256 _short) = $.events.getOutcomeBalance(
                        _order.outcomeId,
                        account
                    );
                    //get the winningFee
                    _winningFee = (_short * $.config.winningFee) / 1000;
                    if (!flagShort) {
                        totalWinning += _short - _winningFee;
                    }
                    //refund the unmatch value
                    uint256 _refund = _order.value -
                        $.orderFilleds[orderIds[i]].value;
                    unfilled += _refund;
                    flagShort = true;
                }
            } else if (
                _order.orderType == Libs.OrderType.SellYes ||
                _order.orderType == Libs.OrderType.SellNo
            ) {
                //if _outcomeStatus is Won => claim the unmatched position
                uint256 positionWonUnmatch = _order.amount -
                    $.orderFilleds[orderIds[i]].amount;
                //get the winningFee
                _winningFee = (positionWonUnmatch * $.config.winningFee) / 1000;
                if (
                    _outcomeStatus == Events.OutcomeStatus.Won &&
                    _order.orderType == Libs.OrderType.SellYes
                ) {
                    totalWinning += positionWonUnmatch - _winningFee;
                } else if (
                    _outcomeStatus == Events.OutcomeStatus.Lost &&
                    _order.orderType == Libs.OrderType.SellNo
                ) {
                    totalWinning += positionWonUnmatch - _winningFee;
                } else if (
                    _outcomeStatus == Events.OutcomeStatus.Cancelled &&
                    (_order.orderType == Libs.OrderType.SellYes ||
                        _order.orderType == Libs.OrderType.SellNo)
                ) {
                    unfilled += (positionWonUnmatch * _order.price) / Libs.WEI6;
                }
            }
        }
        claimed = $.totalClaimed[eventId][account];
    }

    function _closeOrder(uint256 orderId, address account) internal {
        OrderbookStorage storage $ = _getOwnStorage();
        Libs.Order storage order = $.limitOrders[orderId];
        Libs.OrderFilled memory orderFilled = $.orderFilleds[orderId];
        Events.OutcomeStatus _outcomeStatus = $.events.getOutcomeStatus(
            order.outcomeId
        );
        require(
            order.user == account &&
                _outcomeStatus != Events.OutcomeStatus.Cancelled &&
                order.status != Libs.OrderStatus.Filled &&
                order.status != Libs.OrderStatus.Closed,
            ""
        );
        //if orderType is sell => refund the position
        if (
            order.orderType == Libs.OrderType.SellYes ||
            order.orderType == Libs.OrderType.SellNo
        ) {
            uint256 _refund = order.amount > orderFilled.amount
                ? order.amount - orderFilled.amount
                : 0;
            //change the order status
            order.status = Libs.OrderStatus.Closed;
            //refund the position
            order.orderType == Libs.OrderType.SellYes
                ? $.events.transferLong(
                    address(this),
                    msg.sender,
                    order.outcomeId,
                    _refund
                )
                : $.events.transferShort(
                    address(this),
                    msg.sender,
                    order.outcomeId,
                    _refund
                );
            emit CloseOrder(orderId, order.status, order.user);
        } else {
            uint256 _refund = order.value > orderFilled.value
                ? order.value - orderFilled.value
                : 0;
            //change the order status
            order.status = Libs.OrderStatus.Closed;
            //transfer the refund
            $.credit.transfer(
                account,
                Libs.toCredit(_refund, $.credit.decimals())
            );
            emit CloseOrder(orderId, order.status, order.user);
        }
    }

    function _limitSell(
        Libs.OrderType orderType,
        uint256 olId,
        uint256 outcomeId,
        uint256 price,
        uint256 amount,
        bytes memory signature
    ) internal {
        //check the signature
        OrderbookStorage storage $ = _getOwnStorage();
        $.signatureValidator.signatureLimitSell(
            address(this),
            msg.sender,
            orderType,
            outcomeId,
            price,
            amount,
            signature
        );
        _sell(orderType, olId, outcomeId, price, amount, $);
    }

    function _limitBuy(
        Libs.OrderType orderType,
        uint256 olId,
        uint256 outcomeId,
        uint256 price,
        uint256 value,
        bytes memory signature
    ) internal {
        //check the signature
        OrderbookStorage storage $ = _getOwnStorage();
        $.signatureValidator.signatureLimitBuy(
            address(this),
            msg.sender,
            orderType,
            outcomeId,
            price,
            value,
            signature
        );
        _buy(orderType, olId, outcomeId, price, value, $);
    }

    function _validateMatching(
        uint256 originOrderId,
        uint256[] memory matchingOrderIds,
        OrderbookStorage storage $
    ) private view {
        Libs.Order memory _orgOrder = $.limitOrders[originOrderId];
        Libs.Order[] memory _matchingOrders = new Libs.Order[](
            matchingOrderIds.length
        );
        for (uint i = 0; i < matchingOrderIds.length; i++) {
            _matchingOrders[i] = $.limitOrders[matchingOrderIds[i]];
        }
        $.signatureValidator.validateMatching(_orgOrder, _matchingOrders);
    }

    function _buy(
        Libs.OrderType orderType,
        uint256 olId,
        uint256 outcomeId,
        uint256 price,
        uint256 value,
        OrderbookStorage storage $
    ) private returns (uint256 _newId) {
        $.signatureValidator.validateLimitBuyInput(orderType, price, value);
        // calculate deposit
        //calculate the amount
        uint256 _amount;
        if (price != 0) {
            // in case limit buy
            _amount =
                (value * Libs.WEI6) /
                (price + (price * $.config.buyFee) / 1000);
        }

        // transfer credit
        $.credit.transferFrom(
            msg.sender,
            address(this),
            Libs.toCredit(value, $.credit.decimals())
        );

        // create Order
        Libs.Order memory order = Libs.Order(
            orderType,
            msg.sender,
            outcomeId,
            value,
            price,
            _amount,
            Libs.OrderStatus.Open
        );

        _newId = $.lastOrderId + 1;
        $.limitOrders[_newId] = order;
        $.lastOrderId = _newId;
        (uint256 _long, uint256 _short) = $.events.getOutcomeBalance(
            outcomeId,
            msg.sender
        );
        emit NewOrder(
            orderType,
            $.lastOrderId,
            olId,
            msg.sender,
            outcomeId,
            value,
            price,
            _amount,
            orderType == Libs.OrderType.BuyYes ? _long : _short
        );
    }

    function _sell(
        Libs.OrderType orderType,
        uint256 olId,
        uint256 outcomeId,
        uint256 price,
        uint256 amount,
        OrderbookStorage storage $
    ) private returns (uint256 _newId) {
        (uint256 long, uint256 short) = $.events.getOutcomeBalance(
            outcomeId,
            msg.sender
        );
        $.signatureValidator.validateLimitSellInput(
            orderType,
            price,
            amount,
            long,
            short
        );

        // calculate deposit
        address _user = msg.sender;

        // transfer share to this contract
        if (orderType == Libs.OrderType.SellYes) {
            $.events.transferLong(_user, address(this), outcomeId, amount);
        } else {
            $.events.transferShort(_user, address(this), outcomeId, amount);
        }

        // create Order
        Libs.Order memory order = Libs.Order(
            orderType,
            _user,
            outcomeId,
            0,
            price,
            amount,
            Libs.OrderStatus.Open
        );

        _newId = $.lastOrderId + 1;
        $.limitOrders[_newId] = order;
        $.lastOrderId = _newId;
        (uint256 _long, uint256 _short) = $.events.getOutcomeBalance(
            outcomeId,
            msg.sender
        );
        emit NewOrder(
            orderType,
            $.lastOrderId,
            olId,
            _user,
            outcomeId,
            0,
            price,
            amount,
            orderType == Libs.OrderType.SellYes ? _long : _short
        );
    }

    function _matchingBuyLimit(
        uint256 orderId,
        uint256[] memory matchingOrderIds
    ) internal returns (bool _isFilled) {
        OrderbookStorage storage $ = _getOwnStorage();
        Libs.Order memory _buyOrder = $.limitOrders[orderId];
        Libs.OrderFilled storage _buyOrderFilled = $.orderFilleds[orderId];
        require(
            (_buyOrder.orderType == Libs.OrderType.BuyYes ||
                _buyOrder.orderType == Libs.OrderType.BuyNo) &&
                (_buyOrder.status == Libs.OrderStatus.Open ||
                    _buyOrder.status == Libs.OrderStatus.Matched),
            ""
        );

        uint256 _outcomeId = _buyOrder.outcomeId;
        uint256 i = 0;
        uint256 _canFilledValue = _buyOrder.value - _buyOrderFilled.value;
        // uint256 _canFilledAmount = _buyOrder.amount - _buyOrderFilled.amount;

        // validate the order input and status
        _validateMatching(orderId, matchingOrderIds, $);
        // start matching
        uint256 _totalFilledAmount;
        uint256 _totalFilledValue;
        uint256 _totalFee;
        while (i < matchingOrderIds.length) {
            uint256 _sellOrderId = matchingOrderIds[i];
            Libs.Order memory _sellOrder = $.limitOrders[_sellOrderId];
            Libs.OrderFilled storage _sellOrderFilled = $.orderFilleds[
                _sellOrderId
            ];
            //availAmount <=> sell order amount of position remains
            uint256 _availAmount = _sellOrder.amount - _sellOrderFilled.amount;

            uint256 _canFilledAmount;
            if (_buyOrder.price == 0) {
                // market price - calculate base on sell order price
                _canFilledAmount =
                    (_canFilledValue * Libs.WEI6) /
                    (_sellOrder.price +
                        (_sellOrder.price * $.config.buyFee) /
                        1000);
            } else {
                // limit price - calculate base on buy order price
                _canFilledAmount =
                    (_canFilledValue * Libs.WEI6) /
                    (_buyOrder.price +
                        (_buyOrder.price * $.config.buyFee) /
                        1000);
            }

            // limit order
            uint256 _fillingAmount = _availAmount < _canFilledAmount
                ? _availAmount
                : _canFilledAmount;

            // if the buy order has price => limit order else market order
            (uint256 _fillingValue, uint256 _buyFee) = Libs.getBuyFillingValue(
                _buyOrder.price,
                _fillingAmount,
                _sellOrder.price,
                _sellOrder.orderType,
                $.config.buyFee
            );
            _totalFee += _buyFee;
            if (
                _sellOrder.orderType == Libs.OrderType.SellYes ||
                _sellOrder.orderType == Libs.OrderType.SellNo
            ) {
                // Matching with sell order
                uint256 _filledSellValue = (_fillingAmount * _sellOrder.price) /
                    Libs.WEI6;
                // update OrderFilled
                _sellOrderFilled.amount += _fillingAmount;
                _sellOrderFilled.value += _filledSellValue;

                // transfer shares from seller to buyer
                _sellOrder.orderType == Libs.OrderType.SellYes
                    ? $.events.transferLong(
                        address(this),
                        _buyOrder.user,
                        _outcomeId,
                        _fillingAmount
                    )
                    : $.events.transferShort(
                        address(this),
                        _buyOrder.user,
                        _outcomeId,
                        _fillingAmount
                    );
                // transfer credit to seller
                // check to update sellOrder status
                $.limitOrders[_sellOrderId].status = (_sellOrder.amount -
                    _sellOrderFilled.amount <=
                    TINY_VALUE)
                    ? Libs.OrderStatus.Filled
                    : Libs.OrderStatus.Matched;
                // get sell fee
                uint256 _sellFee = (_filledSellValue * $.config.sellFee) / 1000;
                _totalFee += _sellFee;
                // transfer credit to seller
                $.credit.transfer(
                    _sellOrder.user,
                    Libs.toCredit(
                        (_filledSellValue - _sellFee),
                        $.credit.decimals()
                    )
                );
                //get the position of the sell order
                (
                    uint256 _longSellYes,
                    uint256 _shortSellNo,
                    uint256 _longTk,
                    uint256 _shortTk
                ) = $.events.getOutcomeAndInitialBalance(
                        _outcomeId,
                        _sellOrder.user
                    );
                //get the filled amount of sell yes order

                emit FillOrder(
                    _sellOrderId,
                    orderId,
                    _sellOrder.price,
                    _sellOrder.orderType == Libs.OrderType.SellYes
                        ? _longSellYes
                        : _shortSellNo,
                    _filledSellValue,
                    $.limitOrders[_sellOrderId].status,
                    _sellOrderFilled.amount,
                    _sellOrder.orderType == Libs.OrderType.SellYes
                        ? _longTk
                        : _shortTk,
                    _sellFee
                );
            } else {
                // matching with opposite buy order
                uint256 _filledBuyValue = (_fillingAmount * _sellOrder.price) /
                    Libs.WEI6;
                // get the buy opposite site fee
                uint256 _buyOppositeFee = (_filledBuyValue * $.config.buyFee) /
                    1000;
                _filledBuyValue += _buyOppositeFee;
                _totalFee += _buyOppositeFee;
                _sellOrderFilled.amount += _fillingAmount;
                _sellOrderFilled.value += _filledBuyValue;
                // check to update sellOrder status
                $.limitOrders[_sellOrderId].status = (_sellOrder.value -
                    _sellOrderFilled.value <=
                    TINY_VALUE)
                    ? Libs.OrderStatus.Filled
                    : Libs.OrderStatus.Matched;
                // mint new share
                _sellOrder.orderType == Libs.OrderType.BuyYes
                    ? $.events.mint(
                        _sellOrder.user, // YES
                        _buyOrder.user, // NO
                        _outcomeId,
                        _fillingAmount
                    )
                    : $.events.mint(
                        _buyOrder.user, // YES
                        _sellOrder.user, // NO
                        _outcomeId,
                        _fillingAmount
                    );
                // get the position of the buyNo order
                (
                    uint256 _longBuyYes,
                    uint256 _shortBuyNo,
                    uint256 _longTk,
                    uint256 _shortTk
                ) = $.events.getOutcomeAndInitialBalance(
                        _outcomeId,
                        _sellOrder.user
                    );
                emit FillOrder(
                    _sellOrderId,
                    orderId,
                    _sellOrder.price,
                    _sellOrder.orderType == Libs.OrderType.BuyYes
                        ? _longBuyYes
                        : _shortBuyNo,
                    _filledBuyValue,
                    $.limitOrders[_sellOrderId].status,
                    _sellOrderFilled.amount,
                    _sellOrder.orderType == Libs.OrderType.BuyYes
                        ? _longTk
                        : _shortTk,
                    _buyOppositeFee
                );
            }

            _totalFilledAmount += _fillingAmount;
            _totalFilledValue += _fillingValue;
            _canFilledValue -= _fillingValue;

            i++;
        }

        _buyOrderFilled.amount += _totalFilledAmount;
        _buyOrderFilled.value += _totalFilledValue;
        //transfer the fee to the feeWallet
        $.credit.transfer(
            $.config.feeWallet,
            Libs.toCredit(_totalFee, $.credit.decimals())
        );
        //calculate the ordermatched fee
        uint256 _orderMatchedFee = (_totalFilledValue * $.config.buyFee) / 1000;
        // check to update buyOrder status
        if (_buyOrder.value - _buyOrderFilled.value <= TINY_VALUE) {
            // filled
            $.limitOrders[orderId].status = Libs.OrderStatus.Filled;
            // return value
            _isFilled = true;
        } else {
            $.limitOrders[orderId].status = Libs.OrderStatus.Matched;
            // return value
            _isFilled = false;
        }

        //get the position of buyYes order
        (uint256 long, uint256 short, uint256 longTk, uint256 shortTk) = $
            .events
            .getOutcomeAndInitialBalance(_outcomeId, _buyOrder.user);
        emit FillOrder(
            orderId,
            0,
            _buyOrder.price,
            _buyOrder.orderType == Libs.OrderType.BuyYes ? long : short,
            _totalFilledValue,
            $.limitOrders[orderId].status,
            _buyOrderFilled.amount,
            _buyOrder.orderType == Libs.OrderType.BuyYes ? longTk : shortTk,
            _orderMatchedFee
        );
    }

    function _matchingSellLimit(
        uint256 orderId,
        uint256[] memory matchingOrderIds
    ) internal returns (bool _isFilled) {
        OrderbookStorage storage $ = _getOwnStorage();

        Libs.Order memory _sellOrder = $.limitOrders[orderId];
        Libs.OrderFilled storage _sellOrderFilled = $.orderFilleds[orderId];
        require(
            (_sellOrder.orderType == Libs.OrderType.SellYes ||
                _sellOrder.orderType == Libs.OrderType.SellNo) &&
                (_sellOrder.status == Libs.OrderStatus.Open ||
                    _sellOrder.status == Libs.OrderStatus.Matched),
            ""
        );

        uint256 _outcomeId = _sellOrder.outcomeId;
        uint256 i = 0;
        uint256 _availableAmount = _sellOrder.amount - _sellOrderFilled.amount;
        _validateMatching(orderId, matchingOrderIds, $);

        // start matching
        uint256 _totalFilledAmount;
        uint256 _totalFilledValue;
        uint256 _totalFee;
        while (_availableAmount > 0 && i < matchingOrderIds.length) {
            uint256 _buyOrderId = matchingOrderIds[i];
            Libs.Order memory _buyOrder = $.limitOrders[_buyOrderId];
            Libs.OrderFilled storage _buyOrderFilled = $.orderFilleds[
                _buyOrderId
            ];
            //availAmount <=> buyYes order amount of position which not be filled
            uint256 _availAmount = _buyOrder.amount - _buyOrderFilled.amount;
            uint256 _fillingAmount = _availableAmount > _availAmount
                ? _availAmount
                : _availableAmount;
            uint256 _fillingValue = _sellOrder.price != 0
                ? (_fillingAmount * _sellOrder.price) / Libs.WEI6
                : (_fillingAmount *
                    (
                        _buyOrder.orderType == Libs.OrderType.BuyYes ||
                            _buyOrder.orderType == Libs.OrderType.BuyNo
                            ? _buyOrder.price
                            : (Libs.WEI6 - _buyOrder.price)
                    )) / Libs.WEI6;
            if (
                _buyOrder.orderType == Libs.OrderType.BuyYes ||
                _buyOrder.orderType == Libs.OrderType.BuyNo
            ) {
                // Match with BUY order
                uint256 _filledBuyValue = (_fillingAmount * _buyOrder.price) /
                    Libs.WEI6;
                //get the buy fee
                uint256 _buyFee = (_filledBuyValue * $.config.buyFee) / 1000;
                _filledBuyValue += _buyFee;
                // if (_buyOrderFilled.value + _buyFee > _buyOrder.value) {
                //     _buyFee = _buyOrderFilled.value + _buyFee - _buyOrder.value;
                // }
                _totalFee += _buyFee;
                _buyOrderFilled.amount += _fillingAmount;
                _buyOrderFilled.value += _filledBuyValue;

                // check to update sellOrder status
                $.limitOrders[_buyOrderId].status = (_buyOrder.amount -
                    _buyOrderFilled.amount <=
                    TINY_VALUE)
                    ? Libs.OrderStatus.Filled
                    : Libs.OrderStatus.Matched;
                // mint new share for buyer
                _buyOrder.orderType == Libs.OrderType.BuyYes
                    ? $.events.transferLong(
                        address(this),
                        _buyOrder.user,
                        _outcomeId,
                        _fillingAmount
                    )
                    : $.events.transferShort(
                        address(this),
                        _buyOrder.user,
                        _outcomeId,
                        _fillingAmount
                    );
                // get the position of the buyYes order
                (
                    uint256 _longBuyYes,
                    uint256 _shortBuyNo,
                    uint256 _longTk,
                    uint256 _shortTk
                ) = $.events.getOutcomeAndInitialBalance(
                        _outcomeId,
                        _buyOrder.user
                    );
                emit FillOrder(
                    _buyOrderId,
                    orderId,
                    _buyOrder.price,
                    _buyOrder.orderType == Libs.OrderType.BuyYes
                        ? _longBuyYes
                        : _shortBuyNo,
                    _filledBuyValue,
                    $.limitOrders[_buyOrderId].status,
                    _buyOrderFilled.amount,
                    _buyOrder.orderType == Libs.OrderType.BuyYes
                        ? _longTk
                        : _shortTk,
                    _buyFee
                );
            } else {
                // Match with Opposite SELL order
                uint256 _filledSellValue = (_fillingAmount * _buyOrder.price) /
                    Libs.WEI6;
                // update OrderFilled
                _buyOrderFilled.amount += _fillingAmount;
                _buyOrderFilled.value += _filledSellValue;

                // check to update sellOrder status
                if (_buyOrder.amount - _buyOrderFilled.amount <= TINY_VALUE) {
                    // close the order
                    $.limitOrders[_buyOrderId].status = Libs.OrderStatus.Filled;
                } else {
                    // first match
                    $.limitOrders[_buyOrderId].status = Libs
                        .OrderStatus
                        .Matched;
                }
                // get the sell fee
                uint256 _sellFee = (_filledSellValue * $.config.sellFee) / 1000;
                _totalFee += _sellFee;
                // transfer credit to sellNo seller
                $.credit.transfer(
                    _buyOrder.user,
                    Libs.toCredit(
                        (_filledSellValue - _sellFee),
                        $.credit.decimals()
                    )
                );
                //get the position of sellNo order
                (
                    uint256 _longSellYes,
                    uint256 _shortSellNo,
                    uint256 _longTk,
                    uint256 _shortTk
                ) = $.events.getOutcomeAndInitialBalance(
                        _outcomeId,
                        _buyOrder.user
                    );
                emit FillOrder(
                    _buyOrderId,
                    orderId,
                    _buyOrder.price,
                    _buyOrder.orderType == Libs.OrderType.SellYes
                        ? _longSellYes
                        : _shortSellNo,
                    _filledSellValue,
                    $.limitOrders[_buyOrderId].status,
                    _buyOrderFilled.amount,
                    _buyOrder.orderType == Libs.OrderType.SellYes
                        ? _longTk
                        : _shortTk,
                    _sellFee
                );
            }

            _totalFilledAmount += _fillingAmount;
            _totalFilledValue += _fillingValue;
            _availableAmount -= _fillingAmount;

            i++;
        }

        _sellOrderFilled.amount += _totalFilledAmount;
        _sellOrderFilled.value += _totalFilledValue;
        // check to update sellOrder status
        if (_sellOrder.amount - _sellOrderFilled.amount <= TINY_VALUE) {
            // filled
            $.limitOrders[orderId].status = Libs.OrderStatus.Filled;
            // return value
            _isFilled = true;
        } else {
            $.limitOrders[orderId].status = Libs.OrderStatus.Matched;
            // return value
            _isFilled = false;
        }

        //transfer credit to seller
        // get the sell fee
        uint256 _totalSellFee = (_totalFilledValue * $.config.sellFee) / 1000;
        _totalFee += _totalSellFee;
        $.credit.transfer(
            _sellOrder.user,
            Libs.toCredit(
                (_totalFilledValue - _totalSellFee),
                $.credit.decimals()
            )
        );
        $.credit.transfer(
            $.config.feeWallet,
            Libs.toCredit(_totalFee, $.credit.decimals())
        );
        //get the position of sellYes order
        (uint256 long, uint256 short, uint256 longTk, uint256 shortTk) = $
            .events
            .getOutcomeAndInitialBalance(_outcomeId, _sellOrder.user);
        emit FillOrder(
            orderId,
            0,
            _sellOrder.price,
            _sellOrder.orderType == Libs.OrderType.SellYes ? long : short,
            _totalFilledValue,
            $.limitOrders[orderId].status,
            _sellOrderFilled.amount,
            _sellOrder.orderType == Libs.OrderType.SellYes ? longTk : shortTk,
            _totalSellFee
        );
    }
}
