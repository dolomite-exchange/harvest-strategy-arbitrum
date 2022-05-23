pragma solidity ^0.5.16;

import "../../base/interfaces/IMainnetStrategy.sol";
import "./SushiStrategy.sol";


contract EthWbtcSushiStrategyMainnet is SushiStrategy, IMainnetStrategy {

    address public constant ETH_WBTC_SLP = 0x515e252b2b5c22b4b2b6Df66c2eBeeA871AA4d69;
    uint256 public constant ETH_WBTC_PID = 3;

    function initializeMainnetStrategy(
        address _storage,
        address _vault,
        address _strategist
    ) external {
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = SUSHI;
        SushiStrategy.initializeSushiStrategy(
            _storage,
            ETH_WBTC_SLP,
            _vault,
            SUSHI_MINI_CHEF_V2,
            rewardTokens,
            _strategist,
            ETH_WBTC_PID
        );
    }
}
