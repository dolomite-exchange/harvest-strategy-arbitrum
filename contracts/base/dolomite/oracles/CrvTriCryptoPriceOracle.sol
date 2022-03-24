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
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";

import "../../../strategies/curve/interfaces/ITriCryptoPool.sol";
import "../../../utils/AdvancedMath.sol";

import "./interfaces/CrvToken.sol";

import "../lib/DolomiteMarginMonetary.sol";

import "../../inheritance/Constants.sol";
import "../../interfaces/IVault.sol";

import "./FTokenPriceOracle.sol";

import "hardhat/console.sol";


/**
 * @notice  Calculates the USD value of a given fToken by breaking it down into it's underlying tokens.
 */
contract CrvTriCryptoPriceOracle is FTokenPriceOracle, Constants {
    using SafeMath for uint256;
    using AdvancedMath for uint256;

    uint deviationThreshold;

    /**
     * @param _dolomiteMargin       The instance of DolomiteMargin
     * @param _deviationThreshold   The max % diff between the pool's value and the contract's reported value where the
     *                              geometric mean (more gas cost) is calculated instead of the arithmetic mean (costs
     *                              less gas). 1e16 equals 1%. Has 18 decimals.
     */
    constructor(
        address _dolomiteMargin,
        uint _deviationThreshold
    ) public FTokenPriceOracle(_dolomiteMargin) {
        deviationThreshold = _deviationThreshold;
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
        require(
            address(crvToken) == CRV_TRI_CRYPTO_TOKEN,
            "invalid _fToken for CRV_TRI_CRYPTO_TOKEN"
        );

        ITriCryptoPool triCryptoPool = ITriCryptoPool(crvToken.minter());
        uint fExchangeRate = IVault(_fToken).getPricePerFullShare();
        uint fBase = IVault(_fToken).underlyingUnit();

        IDolomiteMargin _dolomiteMargin = dolomiteMargin;
        uint usdtPrice = _getUsdtPrice(_dolomiteMargin);

        address[] memory parts = getFTokenParts(_fToken);
        uint256[] memory values = new uint256[](parts.length);
        for (uint i = 0; i < parts.length; i++) {
            uint256 price = _dolomiteMargin.getMarketPrice(_dolomiteMargin.getMarketIdByTokenAddress(parts[i])).value;
            values[i] = triCryptoPool.balances(i).mul(price).div(1e18);
        }

        uint poolValueUSD = triCryptoPool.D().mul(usdtPrice).div(1e18); // D is in terms of USDT, so it must be converted to USD
        uint foundPoolValueUSD = values[0].add(values[1]).add(values[2]);
        if (_hasPriceDeviation(poolValueUSD, foundPoolValueUSD)) {
            poolValueUSD = AdvancedMath.getGeometricMean(values, false) * parts.length;
        }

        // TODO discover if fExchangeRate is flash loan resistant; if it is not, we need to set up 15
        // TODO minute TWAP oracles for them

        // fBase and crvToken.totalSupply() are never 0 so it's safe to use for division.
        uint baseRate = ONE_DOLLAR / fBase;
        return DolomiteMarginMonetary.Price(
            poolValueUSD * baseRate / crvToken.totalSupply() * fExchangeRate / fBase
        );
    }

    // ========================= Internal Functions =========================

    function _getUsdtPrice(IDolomiteMargin _dolomiteMargin) internal view returns (uint) {
        uint rawUsdtPrice = _dolomiteMargin.getMarketPrice(_dolomiteMargin.getMarketIdByTokenAddress(USDT)).value;
        return rawUsdtPrice * 1e6 / 1e18; // standardize to 18 decimals
    }

    function _hasPriceDeviation(uint d1, uint d2) internal view returns (bool) {
        if (d1 > d2) {
            return d1.mul(1e18).div(d2).sub(1e18) > deviationThreshold;
        } else {
            return d2.mul(1e18).div(d1).sub(1e18) > deviationThreshold;
        }
    }

}
