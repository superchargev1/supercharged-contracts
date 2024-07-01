//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "../interfaces/IBlastpoint.sol";

contract Blastpoint {
    //testnet
    // IBlastPoints public constant BLAST_POINT =
    //     IBlastPoints(0x2fc95838c71e76ec69ff817983BFf17c710F34E0);

    //mainnet
    IBlastPoints public constant BLAST_POINT =
        IBlastPoints(0x2536FE9ab3F511540F2f9e2eC2A805005C3Dd800);

    function _configurePointsOperator() internal {
        BLAST_POINT.configurePointsOperator(msg.sender);
    }

    function _configurePointsOperatorOnBehalf(
        address contractAddress
    ) internal {
        BLAST_POINT.configurePointsOperatorOnBehalf(
            contractAddress,
            msg.sender
        );
    }
}
