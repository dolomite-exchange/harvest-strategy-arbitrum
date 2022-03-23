pragma solidity ^0.5.16;

import "../../base/interfaces/IMainnetStrategy.sol";
import "./EursUsdPoolStrategy.sol";


contract EursUsdPoolStrategyMainnet is EursUsdPoolStrategy, IMainnetStrategy {

    function initializeMainnetStrategy(
        address _storage,
        address _vault,
        address _strategist
    ) external initializer {
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = CRV;
        WrapperPoolStrategy.initializeWrappedCurveStrategy(
            _storage,
            CRV_EURS_USD_TOKEN,
            _vault,
            CRV_EURS_USD_GAUGE,
            rewardTokens,
            _strategist,
            CRV_TWO_POOL,
            USDC,
            /* depositArrayPosition = */ 0,
            CRV_EURS_USD_POOL,
            CRV_TWO_POOL,
            /* depositArrayPosition = */ 1
        );
    }

}
