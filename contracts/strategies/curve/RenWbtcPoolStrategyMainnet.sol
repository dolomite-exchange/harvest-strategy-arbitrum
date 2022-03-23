pragma solidity ^0.5.16;

import "../../base/interfaces/IMainnetStrategy.sol";
import "./TwoPoolStrategy.sol";


contract RenWbtcPoolStrategyMainnet is TwoPoolStrategy, IMainnetStrategy {

    function initializeMainnetStrategy(
        address _storage,
        address _vault,
        address _strategist
    ) external initializer {
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = CRV;
        CurveStrategy.initializeCurveStrategy(
            _storage,
            CRV_REN_WBTC_POOL,
            _vault,
            CRV_REN_WBTC_GAUGE,
            rewardTokens,
            _strategist,
            CRV_REN_WBTC_POOL,
            WBTC,
            /* depositArrayPosition = */ 0
        );
    }

}
