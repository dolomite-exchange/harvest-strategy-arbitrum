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

import "../interfaces/IDolomiteMargin.sol";
import "../interfaces/IPriceOracle.sol";

import "../lib/DolomiteMarginMonetary.sol";

/**
 * @notice  Calculates the USD value of a given fToken by breaking it down into it's underlying tokens.
 */
contract FTokenPriceOracle is IPriceOracle {

    IDolomiteMargin public dolomiteMargin;

    constructor(address _dolomiteMargin) public {
        dolomiteMargin = IDolomiteMargin(_dolomiteMargin);
    }

    /**
     * @param _fToken   The fToken whose components make it up should be received
     * @return The tokens that the fToken is comprised
     */
    function getFTokenParts(address _fToken) public view returns (address[] memory);

}
