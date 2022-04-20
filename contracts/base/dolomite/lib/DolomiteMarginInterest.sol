/*

    Copyright 2019 dYdX Trading Inc.

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

pragma solidity ^0.5.7;
pragma experimental ABIEncoderV2;

import "./DolomiteMarginDecimal.sol";
import "./DolomiteMarginMath.sol";
import "./DolomiteMarginTime.sol";
import "./DolomiteMarginTypes.sol";


/**
 * @title DolomiteMarginInterest
 * @author dYdX
 *
 * Library for managing the interest rate and interest indexes of Solo
 */
library DolomiteMarginInterest {
    using DolomiteMarginMath for uint256;

    // ============ Constants ============

    bytes32 constant FILE = "DolomiteMarginInterest";
    uint64 constant BASE = 10**18;

    // ============ Structs ============

    struct Rate {
        uint256 value;
    }

    struct Index {
        uint96 borrow;
        uint96 supply;
        uint32 lastUpdate;
    }

    // ============ Library Functions ============

    /**
     * Get a new market Index based on the old index and market interest rate.
     * Calculate interest for borrowers by using the formula rate * time. Approximates
     * continuously-compounded interest when called frequently, but is much more
     * gas-efficient to calculate. For suppliers, the interest rate is adjusted by the earningsRate,
     * then prorated the across all suppliers.
     *
     * @param  index         The old index for a market
     * @param  rate          The current interest rate of the market
     * @param  totalPar      The total supply and borrow par values of the market
     * @param  earningsRate  The portion of the interest that is forwarded to the suppliers
     * @return               The updated index for a market
     */
    function calculateNewIndex(
        Index memory index,
        Rate memory rate,
        DolomiteMarginTypes.TotalPar memory totalPar,
        DolomiteMarginDecimal.D256 memory earningsRate
    )
    internal
    view
    returns (Index memory)
    {
        (
        DolomiteMarginTypes.Wei memory supplyWei,
        DolomiteMarginTypes.Wei memory borrowWei
        ) = totalParToWei(totalPar, index);

        // get interest increase for borrowers
        uint32 currentTime = DolomiteMarginTime.currentTime();
        uint256 borrowInterest = rate.value.mul(uint256(currentTime).sub(index.lastUpdate));

        // get interest increase for suppliers
        uint256 supplyInterest;
        if (DolomiteMarginTypes.isZero(supplyWei)) {
            supplyInterest = 0;
        } else {
            supplyInterest = DolomiteMarginDecimal.mul(borrowInterest, earningsRate);
            if (borrowWei.value < supplyWei.value) {
                supplyInterest = DolomiteMarginMath.getPartial(supplyInterest, borrowWei.value, supplyWei.value);
            }
        }
        assert(supplyInterest <= borrowInterest);

        return Index({
        borrow: DolomiteMarginMath.getPartial(index.borrow, borrowInterest, BASE).add(index.borrow).to96(),
        supply: DolomiteMarginMath.getPartial(index.supply, supplyInterest, BASE).add(index.supply).to96(),
        lastUpdate: currentTime
        });
    }

    function newIndex()
    internal
    view
    returns (Index memory)
    {
        return Index({
        borrow: BASE,
        supply: BASE,
        lastUpdate: DolomiteMarginTime.currentTime()
        });
    }

    /*
     * Convert a principal amount to a token amount given an index.
     */
    function parToWei(
        DolomiteMarginTypes.Par memory input,
        Index memory index
    )
    internal
    pure
    returns (DolomiteMarginTypes.Wei memory)
    {
        uint256 inputValue = uint256(input.value);
        if (input.sign) {
            return DolomiteMarginTypes.Wei({
            sign: true,
            value: inputValue.getPartial(index.supply, BASE)
            });
        } else {
            return DolomiteMarginTypes.Wei({
            sign: false,
            value: inputValue.getPartialRoundUp(index.borrow, BASE)
            });
        }
    }

    /*
     * Convert a token amount to a principal amount given an index.
     */
    function weiToPar(
        DolomiteMarginTypes.Wei memory input,
        Index memory index
    )
    internal
    pure
    returns (DolomiteMarginTypes.Par memory)
    {
        if (input.sign) {
            return DolomiteMarginTypes.Par({
            sign: true,
            value: input.value.getPartial(BASE, index.supply).to128()
            });
        } else {
            return DolomiteMarginTypes.Par({
            sign: false,
            value: input.value.getPartialRoundUp(BASE, index.borrow).to128()
            });
        }
    }

    /*
     * Convert the total supply and borrow principal amounts of a market to total supply and borrow
     * token amounts.
     */
    function totalParToWei(
        DolomiteMarginTypes.TotalPar memory totalPar,
        Index memory index
    )
    internal
    pure
    returns (DolomiteMarginTypes.Wei memory, DolomiteMarginTypes.Wei memory)
    {
        DolomiteMarginTypes.Par memory supplyPar = DolomiteMarginTypes.Par({
        sign: true,
        value: totalPar.supply
        });
        DolomiteMarginTypes.Par memory borrowPar = DolomiteMarginTypes.Par({
        sign: false,
        value: totalPar.borrow
        });
        DolomiteMarginTypes.Wei memory supplyWei = parToWei(supplyPar, index);
        DolomiteMarginTypes.Wei memory borrowWei = parToWei(borrowPar, index);
        return (supplyWei, borrowWei);
    }
}
