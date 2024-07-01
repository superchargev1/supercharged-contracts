// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./prediction/Orderbook.sol";
import "./prediction/Libs.sol";

import "hardhat/console.sol";

struct OpenPositionParams {
    address account;
    bytes32 poolId;
    uint256 value;
    uint256 leverage;
    uint256 price;
    bool isLong;
    uint256 plId;
}

contract Batching is OwnableUpgradeable, Base {
    bytes32 public constant X1000_BATCHER_ROLE =
        keccak256("X1000_BATCHER_ROLE");
    bytes32 public constant X1000_BATCHER_BURN_ROLE =
        keccak256("X1000_BATCHER_BURN_ROLE");
    bytes32 public constant X1000_BATCHER_CLOSE_ROLE =
        keccak256("X1000_BATCHER_CLOSE_ROLE");
    bytes32 public constant ORDERBOOK_BATCHER_ROLE =
        keccak256("ORDERBOOK_BATCHER_ROLE");
    struct BatchingStorage {
        Orderbook orderbook;
    }

    //keccak256(abi.encode(uint256(keccak256("goal3.storage.Batching")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant BatchingStorageLocation =
        0xc05c5f10a19e05ef10e0a1de72aa3919058141c9f7c29ca3afb777f4a67d5c00;

    event OpenPositionFailed(uint256 pLId, string reason);
    event BurnPositions(uint256[] posId);
    event ClosePositionFailed(uint256 pid, string reason);

    function _getOwnStorage() private pure returns (BatchingStorage storage $) {
        assembly {
            $.slot := BatchingStorageLocation
        }
    }

    function initialize(
        address bookieAddress,
        address orderbook
    ) public initializer {
        __Ownable_init(msg.sender);
        __Base_init(bookieAddress);

        BatchingStorage storage $ = _getOwnStorage();
        $.orderbook = Orderbook(orderbook);
    }

    function matchingLimit(
        uint256[] memory orderIds,
        Libs.OrderType[] memory orderTypes,
        uint256[][] memory matchingOrderIds
    ) external onlyRole(ORDERBOOK_BATCHER_ROLE) {
        require(orderIds.length == orderTypes.length, "Invalid input");
        require(orderIds.length == matchingOrderIds.length, "Invalid input");
        BatchingStorage storage $ = _getOwnStorage();
        for (uint i = 0; i < orderIds.length; i++) {
            if (
                orderTypes[i] == Libs.OrderType.BuyYes ||
                orderTypes[i] == Libs.OrderType.BuyNo
            ) {
                $.orderbook.matchingBuyLimit(orderIds[i], matchingOrderIds[i]);
            } else if (
                orderTypes[i] == Libs.OrderType.SellYes ||
                orderTypes[i] == Libs.OrderType.SellNo
            ) {
                $.orderbook.matchingSellLimit(orderIds[i], matchingOrderIds[i]);
            }
        }
    }

    //////////////////
    ///// SETTER /////
    //////////////////

    function setOrderbookContractAddress(
        address orderbookContractAddress
    ) external onlyOwner {
        BatchingStorage storage $ = _getOwnStorage();
        $.orderbook = Orderbook(orderbookContractAddress);
    }
}
