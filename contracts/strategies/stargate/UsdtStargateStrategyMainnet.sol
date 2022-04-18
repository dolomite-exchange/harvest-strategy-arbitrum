pragma solidity ^0.5.16;

import "../../base/interfaces/IMainnetStrategy.sol";
import "./StargateStrategy.sol";


contract UsdtStargateStrategyMainnet is StargateStrategy, IMainnetStrategy {

    function initializeMainnetStrategy(
        address _storage,
        address _vault,
        address _strategist
    ) external {
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = STG;

        StargateStrategy.initializeStargateStrategy(
            _storage,
            STARGATE_S_USDT,
            _vault,
            STARGATE_REWARD_POOL,
            rewardTokens,
            _strategist,
            USDT,
            STARGATE_ROUTER,
            2,
            1
        );
    }
}
