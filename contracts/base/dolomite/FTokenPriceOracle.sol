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

pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "./interfaces/IDolomiteMargin.sol";
import "./interfaces/IPriceOracle.sol";

import "./lib/DolomiteMarginMonetary.sol";
import "./lib/DolomiteMarginTypes.sol";
import "./lib/Require.sol";

/**
 * @notice  Calculates the USD value of a given fToken by breaking it down into it's underlying tokens.
 */
contract FTokenPriceOracle is IPriceOracle {

    function getPrice(
        address token
    )
    public
    view
    returns (DolomiteMarginMonetary.Price memory) {
        // TODO
        return DolomiteMarginMonetary.Price(0);
    }

}
