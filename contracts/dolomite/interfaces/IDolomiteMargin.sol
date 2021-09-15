/*

    Copyright 2021 Dolomite.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

*/

pragma solidity >=0.5.0;
pragma experimental ABIEncoderV2;

import "../lib/DolomiteMarginAccount.sol";
import "../lib/DolomiteMarginActions.sol";
import "../lib/DolomiteMarginInterest.sol";
import "../lib/DolomiteMarginTypes.sol";

interface IDolomiteMargin {

    function getMarketIdByTokenAddress(
        address token
    ) external view returns (uint256);

    function getMarketTokenAddress(
        uint256 marketId
    ) external view returns (address);

    function getMarketCurrentIndex(
        uint256 marketId
    ) external view returns (DolomiteMarginInterest.Index memory);

    function getAccountPar(
        DolomiteMarginAccount.Info calldata account,
        uint256 marketId
    ) external view returns (DolomiteMarginTypes.Par memory);

    function getAccountWei(
        DolomiteMarginAccount.Info calldata account,
        uint256 marketId
    ) external view returns (DolomiteMarginTypes.Wei memory);

    function operate(
        DolomiteMarginAccount.Info[] calldata accounts,
        DolomiteMarginActions.ActionArgs[] calldata actions
    ) external;

    function getIsGlobalOperator(
        address operator
    )
    external
    view
    returns (bool);

    function getIsLocalOperator(
        address owner,
        address operator
    )
    external
    view
    returns (bool);

}
