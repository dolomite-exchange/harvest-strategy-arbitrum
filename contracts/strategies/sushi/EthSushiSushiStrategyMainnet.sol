pragma solidity ^0.5.16;

import "../../base/interfaces/IMainnetStrategy.sol";
import "./SushiStrategy.sol";


contract EthSushiSushiStrategyMainnet is SushiStrategy, IMainnetStrategy {

    address public constant ETH_SUSHI_SLP = 0x3221022e37029923aCe4235D812273C5A42C322d;
    uint256 public constant ETH_SUSHI_PID = 2;

    function initializeMainnetStrategy(
        address _storage,
        address _vault,
        address _strategist
    ) external {
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = SUSHI;
        SushiStrategy.initializeSushiStrategy(
            _storage,
            ETH_SUSHI_SLP,
            _vault,
            SUSHI_MINI_CHEF_V2,
            rewardTokens,
            _strategist,
            ETH_SUSHI_PID
        );
    }
}
