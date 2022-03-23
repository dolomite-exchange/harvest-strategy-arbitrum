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

import "../../../strategies/curve/interfaces/ITriCryptoPool.sol";

import "../interfaces/IDolomiteMargin.sol";
import "./interfaces/CrvToken.sol";

import "../lib/DolomiteMarginMonetary.sol";

import "../../interfaces/IVault.sol";

import "./FTokenPriceOracle.sol";

/**
 * @notice  Calculates the USD value of a given fToken by breaking it down into it's underlying tokens.
 */
contract CrvTriCryptoPriceOracle is FTokenPriceOracle {

    constructor(address _dolomiteMargin) public FTokenPriceOracle(_dolomiteMargin) {
    }

    function getFTokenParts(address _fToken) public view returns (address[] memory) {
        CrvToken crvToken = CrvToken(IVault(_fToken).underlying());
        ITriCryptoPool triCryptoPool = ITriCryptoPool(crvToken.minter());
        address[] memory parts = new address[](3);
        parts[0] = triCryptoPool.coins(0);
        parts[1] = triCryptoPool.coins(1);
        parts[2] = triCryptoPool.coins(2);
        return parts;
    }

    function getPrice(address _fToken) public view returns (DolomiteMarginMonetary.Price memory) {
        // convert fToken value to underlying value using exchange rate
        // convert value of underlying into the value of the claim on token parts
        CrvToken crvToken = CrvToken(IVault(_fToken).underlying());
        ITriCryptoPool triCryptoPool = ITriCryptoPool(crvToken.minter());
        uint fExchangeRate = IVault(_fToken).getPricePerFullShare();
        uint fBase = IVault(_fToken).underlyingUnit();
        // TODO discover if triCryptoPool.D() and fExchangeRate is flash loan resistant; if they are not, we need to set up 15
        // TODO minute TWAP oracles for them
        return DolomiteMarginMonetary.Price(triCryptoPool.D() * 1e18 / crvToken.totalSupply() * fExchangeRate / fBase);
    }

}
