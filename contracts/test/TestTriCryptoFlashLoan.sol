/*

    Copyright 2022 Dolomite.

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

import "./TestFlashLoan.sol";
import "../strategies/curve/interfaces/ITriCryptoPool.sol";
import "../base/dolomite/interfaces/IPriceOracle.sol";


contract TestTriCryptoFlashLoan is TestFlashLoan {
    using SafeERC20 for IERC20;

    uint256 public priceBeforeSwap;
    uint256 public priceAfterSwap;
    uint256 public valueBefore0;
    uint256 public valueBefore1;
    uint256 public valueBefore2;
    uint256 public valueAfter0;
    uint256 public valueAfter1;
    uint256 public valueAfter2;

    function _executeFlashLoan(
        IERC20 _token,
        uint256 _amount,
        bytes memory _data
    ) internal {
        (
            uint256 inputIndex,
            uint256 outputIndex,
            uint256 minOutput,
            address fToken,
            address oracle
        ) = abi.decode(_data, (uint256, uint256, uint256, address, address));

        uint i = 0;
        for (; i < 3; i++) {
            if (ITriCryptoPool(CRV_TRI_CRYPTO_POOL).coins(i) == address(_token)) {
                require(i == inputIndex, "invalid index");
                break;
            }
        }

        priceBeforeSwap = IPriceOracle(oracle).getPrice(fToken).value;
        valueBefore0 = ITriCryptoPool(CRV_TRI_CRYPTO_POOL).price_oracle(1);
        valueBefore1 = ITriCryptoPool(CRV_TRI_CRYPTO_POOL).price_scale(1);

        _token.safeApprove(CRV_TRI_CRYPTO_POOL, 0);
        _token.safeApprove(CRV_TRI_CRYPTO_POOL, uint(-1));
        ITriCryptoPool(CRV_TRI_CRYPTO_POOL).exchange(
            inputIndex,
            outputIndex,
            _amount,
            minOutput,
            false
        );

        priceAfterSwap = IPriceOracle(oracle).getPrice(fToken).value;
        valueAfter0 = ITriCryptoPool(CRV_TRI_CRYPTO_POOL).price_oracle(1);
        valueAfter1 = ITriCryptoPool(CRV_TRI_CRYPTO_POOL).price_scale(1);

        IERC20 outputToken = IERC20(ITriCryptoPool(CRV_TRI_CRYPTO_POOL).coins(outputIndex));
        outputToken.safeApprove(CRV_TRI_CRYPTO_POOL, 0);
        outputToken.safeApprove(CRV_TRI_CRYPTO_POOL, uint(-1));
        ITriCryptoPool(CRV_TRI_CRYPTO_POOL).exchange(
            outputIndex,
            inputIndex,
            outputToken.balanceOf(address(this)),
            0,
            false
        );
    }
}
