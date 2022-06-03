pragma solidity ^0.5.16;

import "../../base/interfaces/IMainnetStrategy.sol";
import "./SushiStrategy.sol";


contract EthUsdtSushiStrategyMainnet is SushiStrategy, IMainnetStrategy {

    address public constant ETH_USDT_SLP = 0xCB0E5bFa72bBb4d16AB5aA0c60601c438F04b4ad;
    uint256 public constant ETH_USDT_PID = 4;

    function initializeMainnetStrategy(
        address _storage,
        address _vault,
        address _strategist
    ) external {
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = SUSHI;
        SushiStrategy.initializeSushiStrategy(
            _storage,
            ETH_USDT_SLP,
            _vault,
            SUSHI_MINI_CHEF_V2,
            rewardTokens,
            _strategist,
            ETH_USDT_PID
        );
    }
}
