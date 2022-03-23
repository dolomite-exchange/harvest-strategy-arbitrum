pragma solidity ^0.5.16;

import "../../base/interfaces/IMainnetStrategy.sol";
import "./TwoPoolStrategy.sol";


contract TwoPoolStrategyMainnet is TwoPoolStrategy, IMainnetStrategy {

    function initializeMainnetStrategy(
        address _storage,
        address _vault,
        address _strategist
    ) external initializer {
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = CRV;
        CurveStrategy.initializeCurveStrategy(
            _storage,
            CRV_TWO_POOL,
            _vault,
            CRV_TWO_POOL_GAUGE,
            rewardTokens,
            _strategist,
            CRV_TWO_POOL,
            USDC,
            /* depositArrayPosition = */ 0
        );
    }

}
