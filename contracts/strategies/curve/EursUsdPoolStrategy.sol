pragma solidity ^0.5.16;

import "./interfaces/ITwoPool.sol";
import "./interfaces/IEursUsdPool.sol";
import "./WrapperPoolStrategy.sol";


/**
 * @dev A strategy for farming CRV from [RenWBTC](https://arbitrum.curve.fi/ren)
 */
contract EursUsdPoolStrategy is WrapperPoolStrategy {

    // ========================= Internal Functions =========================

    function _mintLiquidityTokens() internal {
        // we can accept 0 as minimum, this will be called only by trusted roles
        uint256 minimum = 0;

        address _depositToken = depositToken();
        address _curveDepositPool = curveDepositPool();
        uint256 tokenBalance = IERC20(_depositToken).balanceOf(address(this));
        IERC20(_depositToken).safeApprove(curveDepositPool(), 0);
        IERC20(_depositToken).safeApprove(curveDepositPool(), tokenBalance);
        uint256[2] memory depositArray;
        depositArray[depositArrayPosition()] = tokenBalance;
        ITwoPool(_curveDepositPool).add_liquidity(depositArray, minimum);

        address _wrapperDepositToken = wrapperDepositToken();
        address _wrapperCurveDepositPool = wrapperCurveDepositPool();
        uint256 wrapperTokenBalance = IERC20(_wrapperDepositToken).balanceOf(address(this));
        IERC20(_wrapperDepositToken).safeApprove(_wrapperCurveDepositPool, 0);
        IERC20(_wrapperDepositToken).safeApprove(_wrapperCurveDepositPool, wrapperTokenBalance);
        uint256[2] memory wrapperDepositArray;
        wrapperDepositArray[wrapperDepositArrayPosition()] = wrapperTokenBalance;
        ITwoPool(_wrapperCurveDepositPool).add_liquidity(wrapperDepositArray, minimum);
    }
}
