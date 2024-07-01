// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../libs/Base.sol";
import "./Libs.sol";

contract Events is OwnableUpgradeable, Base {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant BATCHING = keccak256("BATCHING");
    bytes32 public constant ORDERBOOK = keccak256("ORDERBOOK");
    uint64 public constant WEI6 = 10 ** 6; // base for calculation
    uint64 public constant PRICE_WEI = 10 ** 8; // base for calculation

    enum EventStatus {
        Active,
        Inactive,
        Ended,
        Cancelled
    }

    enum OutcomeStatus {
        Active,
        Inactive,
        Won,
        Lost,
        Cancelled
    }

    struct Config {
        uint256 txFee;
        uint256 claimFee;
    }

    struct Balance {
        uint256 long;
        uint256 short;
    }

    struct InitialBalance {
        uint256 long;
        uint256 short;
    }

    struct Outcome {
        uint256 supply;
        OutcomeStatus status;
        mapping(address => Balance) balances;
        mapping(address => InitialBalance) initialBalances;
    }

    struct Event {
        uint256[] outcomes;
        uint256[] winOutcomeIds;
        uint256 startTime;
        uint256 expiredTime;
        EventStatus status;
    }

    struct EventStorage {
        Config config;
        // eventId => Event
        mapping(uint32 => Event) events;
        mapping(uint256 => Outcome) outcomes;
    }

    event NewEvent(uint256 id);
    event NewEventOutcomes(uint256 id);
    event SettleEvent(uint256 id, uint256 winOutcome);

    event Mint(
        address buyer,
        address seller,
        uint256 outcomeId,
        uint256 amount
    );
    event TransferLong(
        address from,
        address to,
        uint256 outcomeId,
        uint256 amount
    );
    event TransferShort(
        address from,
        address to,
        uint256 outcomeId,
        uint256 amount
    );

    // keccak256(abi.encode(uint256(keccak256("prediction.storage.Event")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant EventStorageLocation =
        0xa15c1ff360d2a55b950565f97522593e07de6fe5c0bc684b320c1fbfab145d00;

    function _getOwnStorage() private pure returns (EventStorage storage $) {
        assembly {
            $.slot := EventStorageLocation
        }
    }

    function initialize(address bookieAddress) public initializer {
        __Ownable_init(msg.sender);
        __Base_init(bookieAddress);

        EventStorage storage $ = _getOwnStorage();
        // init fee
        $.config.txFee = WEI6 / 100; // 1% transaction fee
        $.config.claimFee = WEI6 / 40; // 2.5% prize fee
    }

    //////////////////
    ///// SYSTEM /////
    //////////////////
    function createEvent(
        uint32 eventId,
        uint256[] memory outcomeIds,
        uint256 startTime,
        uint256 expiredTime
    ) external onlyRole(OPERATOR_ROLE) {
        EventStorage storage $ = _getOwnStorage();
        require($.events[eventId].startTime == 0, "Invalid Event Id");
        Event storage _event = $.events[eventId];

        _event.status = EventStatus.Active;
        _event.startTime = startTime;
        _event.expiredTime = expiredTime;
        // create new outcomes
        for (uint256 i = 0; i < outcomeIds.length; i++) {
            _event.outcomes.push(outcomeIds[i]);
        }

        emit NewEvent(eventId);
    }

    function addEventOutcome(
        uint32 eventId,
        uint256[] memory outcomeIds
    ) external onlyRole(OPERATOR_ROLE) {
        EventStorage storage $ = _getOwnStorage();
        // require exist event
        require($.events[eventId].startTime > 0, "Event Not Found");

        Event storage _event = $.events[eventId];
        require(_event.status == EventStatus.Active, "Invalid Event Status");

        // create new outcomes
        for (uint256 i = 0; i < outcomeIds.length; i++) {
            _event.outcomes.push(outcomeIds[i]);
        }

        emit NewEventOutcomes(eventId);
    }

    // make some outcomes to failed status
    function settleOutcomes(
        uint32 eventId,
        uint256[] memory outcomeIds,
        OutcomeStatus[] memory status,
        EventStatus eventStatus
    ) external onlyRole(OPERATOR_ROLE) {
        EventStorage storage $ = _getOwnStorage();
        // require exist event
        require($.events[eventId].startTime > 0, "Event Not Found");
        require(outcomeIds.length == status.length, "Invalid Input Value");

        Event storage _event = $.events[eventId];
        require(
            _event.status == EventStatus.Active ||
                _event.status == EventStatus.Inactive,
            "Invalid Event Status"
        );

        for (uint256 i = 0; i < outcomeIds.length; i++) {
            uint256 _outcomeId = outcomeIds[i];
            require(uint32(_outcomeId >> 64) == eventId, "Invalid Outcome Id");
            Outcome storage _outcome = $.outcomes[_outcomeId];
            require(
                _outcome.status == OutcomeStatus.Active,
                "Invalid Outcome Status"
            );
            if (eventStatus == EventStatus.Cancelled) {
                _outcome.status = OutcomeStatus.Cancelled;
            } else {
                _outcome.status = status[i];
            }
        }
        _event.status = eventStatus;
    }

    // Mint long for buyer and short for seller
    // Increase outcome supply
    // Check and burn long/short if available
    function mint(
        address buyer,
        address seller,
        uint256 outcomeId,
        uint256 amount
    ) external onlyFrom(ORDERBOOK) {
        require(amount > 0, "Invalid Input Value");
        uint32 eventId = uint32(outcomeId >> 64);
        EventStorage storage $ = _getOwnStorage();
        Outcome storage _outcome = $.outcomes[outcomeId];
        require(
            $.events[eventId].startTime > 0 &&
                _outcome.status == OutcomeStatus.Active,
            "Invalid Outcome"
        );
        // mint
        Balance storage _buyerBalance = _outcome.balances[buyer];
        Balance storage _sellerBalance = _outcome.balances[seller];
        InitialBalance storage _buyerInitialBalance = _outcome.initialBalances[
            buyer
        ];
        InitialBalance storage _sellerInitialBalance = _outcome.initialBalances[
            seller
        ];
        _buyerBalance.long += amount;
        _sellerBalance.short += amount;
        _buyerInitialBalance.long += amount;
        _sellerInitialBalance.short += amount;
        _outcome.supply += amount;
        /*
        // check burn
        if (_buyerBalance.long > 0 && _buyerBalance.short > 0) {
            if (_buyerBalance.long > _buyerBalance.short) {
                buyerBurnt = _buyerBalance.short;
            } else {
                buyerBurnt = _buyerBalance.long;
            }
            _buyerBalance.long -= buyerBurnt;
            _buyerBalance.short -= buyerBurnt;
            _outcome.supply -= buyerBurnt;
        }
        if (_sellerBalance.long > 0 && _sellerBalance.short > 0) {
            if (_sellerBalance.long > _sellerBalance.short) {
                sellerBurnt = _sellerBalance.short;
            } else {
                sellerBurnt = _sellerBalance.long;
            }
            _sellerBalance.long -= sellerBurnt;
            _sellerBalance.short -= sellerBurnt;
            _outcome.supply -= sellerBurnt;
        }
        */
        emit Mint(buyer, seller, outcomeId, amount);
    }

    function burn(
        address sellerYes,
        address sellerNo,
        uint256 outcomeId,
        uint256 amount
    ) external onlyFrom(ORDERBOOK) {
        require(amount > 0, "Invalid Input Value");
        uint32 eventId = uint32(outcomeId >> 64);
        EventStorage storage $ = _getOwnStorage();
        Outcome storage _outcome = $.outcomes[outcomeId];
        require(
            $.events[eventId].startTime > 0 &&
                _outcome.status == OutcomeStatus.Active,
            "Invalid Outcome"
        );
        // mint
        Balance storage _sellerYesBalance = _outcome.balances[sellerYes];
        Balance storage _sellerNoBalance = _outcome.balances[sellerNo];
        _sellerYesBalance.long -= amount;
        _sellerNoBalance.short -= amount;
        _outcome.supply -= amount;
    }

    function transferLong(
        address from,
        address to,
        uint256 outcomeId,
        uint256 amount
    ) external onlyFrom(ORDERBOOK) returns (bool) {
        require(amount > 0, "Invalid Input Value");
        EventStorage storage $ = _getOwnStorage();
        Balance storage _fromBalance = $.outcomes[outcomeId].balances[from];
        Balance storage _toBalance = $.outcomes[outcomeId].balances[to];
        InitialBalance storage _toInitialBalance = $
            .outcomes[outcomeId]
            .initialBalances[to];
        require(_fromBalance.long >= amount, "Insufficient Amount");
        _fromBalance.long -= amount;
        _toBalance.long += amount;
        _toInitialBalance.long += amount;
        emit TransferLong(from, to, outcomeId, amount);
        return true;
    }

    function transferShort(
        address from,
        address to,
        uint256 outcomeId,
        uint256 amount
    ) external onlyFrom(ORDERBOOK) returns (bool) {
        require(amount > 0, "Invalid Input Value");
        EventStorage storage $ = _getOwnStorage();
        Balance storage _fromBalance = $.outcomes[outcomeId].balances[from];
        Balance storage _toBalance = $.outcomes[outcomeId].balances[to];
        InitialBalance storage _toInitialBalance = $
            .outcomes[outcomeId]
            .initialBalances[to];
        require(_fromBalance.short >= amount, "Insufficient Amount");
        _fromBalance.short -= amount;
        _toBalance.short += amount;
        _toInitialBalance.short += amount;
        emit TransferShort(from, to, outcomeId, amount);
        return true;
    }

    // function claimEvent(
    //     uint32 eventId,
    //     uint256[] memory orderIds,
    //     address sender,
    //     uint256 winningFee
    // )
    //     external
    //     onlyFrom(ORDERBOOK)
    //     returns (uint256, uint256, uint256, uint256)
    // {
    //     uint256 _returnAmount;
    //     uint256 _totalWinning;
    //     uint256 _unfilled;
    //     uint256 _totalWinningFee;
    //     IOrderbook orderbook = IOrderbook(msg.sender);
    //     for (uint i = 0; i < orderIds.length; i++) {
    //         Libs.Order memory _order = orderbook.getOrder(orderIds[i]);
    //         Libs.OrderFilled memory _orderFilled = orderbook.getOrderFilled(
    //             orderIds[i]
    //         );
    //         Events.OutcomeStatus _outcomeStatus = _getOutcomeStatus(
    //             _order.outcomeId
    //         );
    //         require(
    //             (_order.user == sender) &&
    //                 (uint32(_order.outcomeId >> 64) == eventId) &&
    //                 (_outcomeStatus == Events.OutcomeStatus.Won ||
    //                     _outcomeStatus == Events.OutcomeStatus.Lost ||
    //                     _outcomeStatus == Events.OutcomeStatus.Cancelled),
    //             "Invalid"
    //         );
    //         uint256 _winningFee;
    //         //check the order type
    //         if (
    //             _order.orderType == Libs.OrderType.BuyYes ||
    //             _order.orderType == Libs.OrderType.BuyNo
    //         ) {
    //             //if _outcomeStatus is Won => claim the matched position of outcome
    //             // then refund the unmatch value of order
    //             if (_outcomeStatus == Events.OutcomeStatus.Won) {
    //                 (uint256 _long, ) = _getOutcomeBalance(
    //                     _order.outcomeId,
    //                     sender
    //                 );
    //                 //get the winningFee
    //                 _winningFee = (_long * winningFee) / 1000;
    //                 _totalWinningFee += _winningFee;
    //                 _totalWinning += _long;
    //                 _returnAmount += _long - _winningFee;
    //                 //burn the position
    //                 _claimBurn(sender, _order.outcomeId, _long, true);
    //                 //refund the unmatch value
    //                 uint256 _refund = _order.value - _orderFilled.value;
    //                 orderbook.setOrderFilledValue(orderIds[i], _order.value);
    //                 _unfilled += _refund;
    //                 _returnAmount += _refund;
    //             } else if (_outcomeStatus == Events.OutcomeStatus.Cancelled) {
    //                 //refund all the value
    //                 uint256 _refund = _order.value;
    //                 _claimBurn(
    //                     sender,
    //                     _order.outcomeId,
    //                     _order.amount,
    //                     _order.orderType == Libs.OrderType.BuyYes ? true : false
    //                 );
    //                 orderbook.setLimitOrderValue(orderIds[i], 0);
    //                 orderbook.setOrderFilledValue(orderIds[i], 0);
    //                 _unfilled += _refund;
    //                 _returnAmount += _refund;
    //             } else {
    //                 (, uint256 _short) = _getOutcomeBalance(
    //                     _order.outcomeId,
    //                     sender
    //                 );
    //                 //get the winningFee
    //                 _winningFee = (_short * winningFee) / 1000;
    //                 _totalWinningFee += _winningFee;
    //                 // _short -= _winningFee;
    //                 _totalWinning += _short;
    //                 _returnAmount += _short - _winningFee;
    //                 //burn the position
    //                 _claimBurn(sender, _order.outcomeId, _short, false);
    //                 //refund the unmatch value
    //                 uint256 _refund = _order.value - _orderFilled.value;
    //                 orderbook.setOrderFilledValue(orderIds[i], _order.value);
    //                 _unfilled += _refund;
    //                 _returnAmount += _refund;
    //             }
    //         } else if (
    //             _order.orderType == Libs.OrderType.SellYes ||
    //             _order.orderType == Libs.OrderType.SellNo
    //         ) {
    //             //if _outcomeStatus is Won => claim the unmatched position
    //             uint256 positionWonUnmatch = _order.amount -
    //                 _orderFilled.amount;
    //             //get the winningFee
    //             _winningFee = (positionWonUnmatch * winningFee) / 1000;
    //             if (
    //                 _outcomeStatus == Events.OutcomeStatus.Won &&
    //                 _order.orderType == Libs.OrderType.SellYes
    //             ) {
    //                 _totalWinning += positionWonUnmatch;
    //                 _returnAmount += positionWonUnmatch - _winningFee;
    //                 _totalWinningFee += _winningFee;
    //                 orderbook.setOrderFilledAmount(orderIds[i], _order.amount);
    //             } else if (
    //                 _outcomeStatus == Events.OutcomeStatus.Lost &&
    //                 _order.orderType == Libs.OrderType.SellNo
    //             ) {
    //                 _totalWinning += positionWonUnmatch;
    //                 _returnAmount += positionWonUnmatch - _winningFee;
    //                 _totalWinningFee += _winningFee;
    //                 orderbook.setOrderFilledAmount(orderIds[i], _order.amount);
    //             } else if (
    //                 _outcomeStatus == Events.OutcomeStatus.Cancelled &&
    //                 (_order.orderType == Libs.OrderType.SellYes ||
    //                     _order.orderType == Libs.OrderType.SellNo)
    //             ) {
    //                 _returnAmount +=
    //                     (positionWonUnmatch * _order.price) /
    //                     Libs.WEI6;
    //                 orderbook.setOrderFilledAmount(orderIds[i], _order.amount);
    //             }
    //         }
    //     }
    //     orderbook.addTotalClaimed(eventId, msg.sender, _returnAmount);
    //     return (_totalWinning, _unfilled, _returnAmount, _totalWinningFee);
    // }

    function claim(
        uint32 eventId,
        address sender,
        uint256 winningFee
    ) external onlyFrom(ORDERBOOK) returns (uint256, uint256, uint256) {
        EventStorage storage $ = _getOwnStorage();
        uint256 _totalWinning;
        uint256 _returnAmount;
        uint256 _totalWinningFee;
        uint256[] memory outcomeIds = $.events[eventId].outcomes;
        for (uint i = 0; i < outcomeIds.length; i++) {
            OutcomeStatus _outcomeStatus = _getOutcomeStatus(outcomeIds[i]);
            if (_outcomeStatus == OutcomeStatus.Won) {
                (uint256 _long, ) = _getOutcomeBalance(outcomeIds[i], sender);
                uint256 _winningFee = (_long * winningFee) / 1000;
                _totalWinning += _long;
                _returnAmount += _long - _winningFee;
                _totalWinningFee += _winningFee;
                _claimBurn(sender, outcomeIds[i], _long, true);
            } else if (_outcomeStatus == OutcomeStatus.Lost) {
                (, uint256 _short) = _getOutcomeBalance(outcomeIds[i], sender);
                uint256 _winningFee = (_short * winningFee) / 1000;
                _totalWinning += _short;
                _returnAmount += _short - _winningFee;
                _totalWinningFee += _winningFee;
                _claimBurn(sender, outcomeIds[i], _short, false);
            }
        }
        require(_returnAmount > 0, "Invalid return amount");
        return (_totalWinning, _returnAmount, _totalWinningFee);
    }

    function claimBurn(
        address account,
        uint256 outcomeId,
        uint256 amount,
        bool isLong
    ) external onlyFrom(ORDERBOOK) {
        _claimBurn(account, outcomeId, amount, isLong);
    }

    //////////////////
    ////// USER //////
    //////////////////

    //////////////////
    ///// SETTER /////
    //////////////////

    //////////////////
    ///// GETTER /////
    //////////////////

    function balanceOf(
        address account,
        uint256 outcomeId
    ) external view returns (uint256 long, uint256 short) {
        EventStorage storage $ = _getOwnStorage();
        Balance memory _balance = $.outcomes[outcomeId].balances[account];
        return (_balance.long, _balance.short);
    }

    function getOutcomeStatus(
        uint256 outcomeId
    ) external view returns (OutcomeStatus status) {
        EventStorage storage $ = _getOwnStorage();
        status = $.outcomes[outcomeId].status;
    }

    function getOutcomeBalance(
        uint256 outcomeId,
        address account
    ) external view returns (uint256 long, uint256 short) {
        EventStorage storage $ = _getOwnStorage();
        Balance memory _balance = $.outcomes[outcomeId].balances[account];
        return (_balance.long, _balance.short);
    }

    function getOutcomeInitialBalance(
        uint256 outcomeId,
        address account
    ) external view returns (uint256 long, uint256 short) {
        EventStorage storage $ = _getOwnStorage();
        InitialBalance memory _balance = $.outcomes[outcomeId].initialBalances[
            account
        ];
        return (_balance.long, _balance.short);
    }

    function getOutcomeAndInitialBalance(
        uint256 outcomeId,
        address account
    ) external view returns (uint256, uint256, uint256, uint256) {
        EventStorage storage $ = _getOwnStorage();
        Balance memory _balance = $.outcomes[outcomeId].balances[account];
        InitialBalance memory _initialBalance = $
            .outcomes[outcomeId]
            .initialBalances[account];
        return (
            _balance.long,
            _balance.short,
            _initialBalance.long,
            _initialBalance.short
        );
    }

    function getEventStatus(
        uint32 eventId
    ) external view returns (EventStatus status) {
        EventStorage storage $ = _getOwnStorage();
        status = $.events[eventId].status;
    }

    //////////////////
    ///// PRIVATE ////
    //////////////////

    function _getOutcomeStatus(
        uint256 outcomeId
    ) private view returns (OutcomeStatus) {
        EventStorage storage $ = _getOwnStorage();
        return $.outcomes[outcomeId].status;
    }

    function _getOutcomeBalance(
        uint256 outcomeId,
        address account
    ) private view returns (uint256 long, uint256 short) {
        EventStorage storage $ = _getOwnStorage();
        Balance memory _balance = $.outcomes[outcomeId].balances[account];
        return (_balance.long, _balance.short);
    }

    function _claimBurn(
        address account,
        uint256 outcomeId,
        uint256 amount,
        bool isLong
    ) private {
        EventStorage storage $ = _getOwnStorage();
        Outcome storage _outcome = $.outcomes[outcomeId];
        Balance storage _balance = _outcome.balances[account];
        require(
            isLong ? _balance.long >= amount : _balance.short >= amount,
            "Insufficient Amount"
        );
        isLong ? _balance.long -= amount : _balance.short -= amount;
        _outcome.supply -= amount;
    }
}
