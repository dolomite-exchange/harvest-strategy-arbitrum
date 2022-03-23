pragma solidity ^0.5.16;

import "./interfaces/IRenWbtcPool.sol";
import "./CurveStrategy.sol";


/**
 * @dev A strategy for farming CRV from [RenWBTC](https://arbitrum.curve.fi/ren)
 */
contract RenWbtcPoolStrategy is CurveStrategy {

    // ========================= Internal Functions =========================

    function _mintLiquidityTokens() internal {
        address _depositToken = depositToken();
        uint256 tokenBalance = IERC20(_depositToken).balanceOf(address(this));
        IERC20(_depositToken).safeApprove(curveDepositPool(), 0);
        IERC20(_depositToken).safeApprove(curveDepositPool(), tokenBalance);

        uint256[2] memory depositArray;
        depositArray[depositArrayPosition()] = tokenBalance;

        // we can accept 0 as minimum, this will be called only by trusted roles
        uint256 minimum = 0;
        IRenWbtcPool(curveDepositPool()).add_liquidity(depositArray, minimum);
    }
}
