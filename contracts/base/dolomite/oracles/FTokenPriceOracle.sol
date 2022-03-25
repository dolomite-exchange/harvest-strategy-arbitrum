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

import "@openzeppelin/contracts/ownership/Ownable.sol";

import "../interfaces/IDolomiteMargin.sol";
import "../interfaces/IPriceOracle.sol";

import "../lib/DolomiteMarginMonetary.sol";

/**
 * @notice  Calculates the USD value of a given fToken by breaking it down into it's underlying tokens.
 */
contract FTokenPriceOracle is IPriceOracle, Ownable {

    // ========================= Events =========================

    event MaxDeviationThresholdSet(uint maxDeviationThreshold);

    // ========================= Fields =========================


    IDolomiteMargin public dolomiteMargin;
    uint public maxDeviationThreshold;

    /**
     * @param _dolomiteMargin           The instance of DolomiteMargin
     * @param _maxDeviationThreshold    The max % diff between the pool's value and the contract's reported value where
     *                                  the geometric mean (more gas cost) is calculated instead of the arithmetic mean
     *                                  (costs less gas). 1e16 equals 1%. Has 18 decimals.
     */
    constructor(address _dolomiteMargin, uint _maxDeviationThreshold) public {
        dolomiteMargin = IDolomiteMargin(_dolomiteMargin);
        _setMaxDeviationThreshold(_maxDeviationThreshold);
    }

    /**
     * @param _fToken   The fToken whose components make it up should be received
     * @return The tokens that the fToken is comprised
     */
    function getFTokenParts(address _fToken) public view returns (address[] memory);


    function setMaxDeviationThreshold(
        uint _maxDeviationThreshold
    ) external onlyOwner {
        _setMaxDeviationThreshold(_maxDeviationThreshold);
    }

    // ========================= Internal Functions =========================

    function _setMaxDeviationThreshold(uint _maxDeviationThreshold) internal {
        require(
            _maxDeviationThreshold >= 1e16,
            "max deviation threshold too low"
        );
        maxDeviationThreshold = _maxDeviationThreshold;
        emit MaxDeviationThresholdSet(_maxDeviationThreshold);
    }
}
