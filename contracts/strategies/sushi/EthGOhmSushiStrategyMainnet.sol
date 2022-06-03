pragma solidity ^0.5.16;

import "../../base/interfaces/IMainnetStrategy.sol";
import "./SushiStrategy.sol";


contract EthGOhmSushiStrategyMainnet is SushiStrategy, IMainnetStrategy {

    address public constant ETH_G_OHM_SLP = 0xaa5bD49f2162ffdC15634c87A77AC67bD51C6a6D;
    uint256 public constant ETH_G_OHM_PID = 12;

    function initializeMainnetStrategy(
        address _storage,
        address _vault,
        address _strategist
    ) external {
        address[] memory rewardTokens = new address[](2);
        rewardTokens[0] = SUSHI;
        rewardTokens[1] = G_OHM;
        SushiStrategy.initializeSushiStrategy(
            _storage,
            ETH_G_OHM_SLP,
            _vault,
            SUSHI_MINI_CHEF_V2,
            rewardTokens,
            _strategist,
            ETH_G_OHM_PID
        );
    }
}
