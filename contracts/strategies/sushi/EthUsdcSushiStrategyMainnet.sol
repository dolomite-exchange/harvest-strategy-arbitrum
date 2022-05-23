pragma solidity ^0.5.16;

import "../../base/interfaces/IMainnetStrategy.sol";
import "./SushiStrategy.sol";


contract EthUsdcSushiStrategyMainnet is SushiStrategy, IMainnetStrategy {

    address public constant ETH_USDC_SLP = 0x905dfCD5649217c42684f23958568e533C711Aa3;
    uint256 public constant ETH_USDC_PID = 0;

    function initializeMainnetStrategy(
        address _storage,
        address _vault,
        address _strategist
    ) external {
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = SUSHI;
        SushiStrategy.initializeSushiStrategy(
            _storage,
            ETH_USDC_SLP,
            _vault,
            SUSHI_MINI_CHEF_V2,
            rewardTokens,
            _strategist,
            ETH_USDC_PID
        );
    }
}
