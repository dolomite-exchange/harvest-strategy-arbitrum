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

import "@openzeppelin/contracts/math/SafeMath.sol";

import "../../interfaces/IVault.sol";
import "../../interfaces/IVaultV3.sol";

import "./FTokenPriceOracle.sol";


/**
 * @notice  Calculates the USD value of a given fToken by breaking it down into it's underlying tokens.
 */
contract SimpleFTokenPriceOracle is FTokenPriceOracle {
    using SafeMath for uint256;

    IDolomiteMargin public dolomiteMargin;
    uint public maxDeviationThreshold;

    constructor(address _dolomiteMargin, uint _maxDeviationThreshold) public {
        dolomiteMargin = IDolomiteMargin(_dolomiteMargin);
        _setMaxDeviationThreshold(_maxDeviationThreshold);
    }

    function getFTokenParts(address _fToken) public view returns (address[] memory) {
        address[] memory parts = new address[](1);
        parts[0] = IVault(_fToken).underlying();
        return parts;
    }

    function getPrice(
        address fToken
    )
    public
    view
    returns (DolomiteMarginMonetary.Price memory) {
        uint256 underlyingMarketId = dolomiteMargin.getMarketIdByTokenAddress(IVault(fToken).underlying());
        uint256 underlyingPrice = dolomiteMargin.getMarketPrice(underlyingMarketId).value;
        return DolomiteMarginMonetary.Price({
            value: underlyingPrice.mul(IVaultV3(fToken).oraclePrice()).div(IVault(fToken).underlyingUnit())
        });
    }
}
